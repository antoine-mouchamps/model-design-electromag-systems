"""
Convergence study: sweep mesh size parameter ms and track global quantities
computed by cable.pro for either Electrodynamics or Magnetodynamics.

Uses the gmsh Python API for meshing, and subprocess for GetDP
(no Python package exists for GetDP).

Usage:
    python convergence_study.py
"""

import json
import os
import subprocess
import gmsh
import matplotlib.pyplot as plt

plt.rcParams.update({"text.usetex": True, "font.family": "cm"})
plt.rcParams.update({"font.size": 20})

WORK_DIR = os.path.dirname(os.path.abspath(__file__))
GEO_FILE = os.path.join(WORK_DIR, "cable.geo")
PRO_FILE = os.path.join(WORK_DIR, "cable.pro")
MSH_FILE = os.path.join(WORK_DIR, "cable.msh")

ONELAB_DIR = r"C:\Users\antoi\Documents\UNIF\master_2\modelling_design_electromagnetic_systems\onelab-Windows64"
GETDP_EXE = os.path.join(ONELAB_DIR, "getdp.exe")

# ms values to sweep — from coarse to fine
MS_VALUES = [
    2.0,
    1.5,
    1.0,
    0.75,
    0.5,
    0.4,
    0.35,
    0.3,
    0.25,
    0.2,
]

# Choose the analysis type: "electrodynamics" or "magnetodynamics" or "thermal".
ANALYSIS = "thermal"

# Per-analysis configuration: GetDP solve/post names and result files to collect.
# Each entry in "results" maps a key to (dat_filename_in_res/, axis_label).
ANALYSIS_CONFIG = {
    "electrodynamics": {
        "flag": 0,  # Flag_AnalysisType in cable.pro
        "solve": "Electrodynamics",
        "post": "Post_Ele",
        "results": {
            "energies": ("energy.dat", r"Electric Energy [J/m]"),
        },
        "title": "Electrodynamics",
    },
    "magnetodynamics": {
        "flag": 1,  # Flag_AnalysisType in cable.pro
        "solve": "Magnetoquasistatics",
        "post": "Post_Mag",
        "results": {
            "losses_total": ("losses_all.dat", r"Total Losses [W/m]"),
            "resistance": ("Rinds.dat", r"Phase Resistance [$\Omega$/m]"),
            "inductance": ("Linds.dat", r"Phase Inductance [H/m]"),
            "mag_energy": ("MagEnergy.dat", r"Magnetic Energy [J/m]"),
        },
        "title": "Magnetodynamics",
    },
    "thermal": {
        "flag": 2,  # Flag_AnalysisType in cable.pro
        "solve": "Magnetothermal",
        "post": "Post_MagTher",
        "results": {
            "losses_total": ("losses_all.dat", r"Total Losses [W/m]"),
            "resistance": ("Rinds.dat", r"Phase Resistance [$\Omega$/m]"),
            "inductance": ("Linds.dat", r"Phase Inductance [H/m]"),
            "mag_energy": ("MagEnergy.dat", r"Magnetic Energy [J/m]"),
        },
        "title": "Magneto-Thermal",
    },
}

# Results folder is analysis-specific so both sets can coexist.
RESULTS_DIR = os.path.join(WORK_DIR, f"convergence_results_{ANALYSIS}")
RESULTS_FILE = os.path.join(RESULTS_DIR, "results.json")
ALWAYS_RUN = False

# Log scale flags — set independently for each axis.
LOG_SCALE_X = True
LOG_SCALE_Y = False


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------


def mesh(ms, flag):
    """
    Generate a 2-D mesh for the given ms value using the gmsh Python API.
    Passing '-setnumber' via initialize's argv overrides DefineNumber/DefineConstant
    defaults in the .geo/.pro files (ms controls element size; Flag_AnalysisType
    controls domain geometry — r_domain, r_domain_inf, scale_mesh_ground).
    Returns the total number of 2-D elements in the mesh.
    """
    gmsh.initialize(
        [
            "",
            "-setnumber",
            "ms",
            str(ms),
            "-setnumber",
            "Flag_AnalysisType",
            str(flag),
        ]
    )
    gmsh.option.setNumber("General.Verbosity", 3)
    gmsh.open(GEO_FILE)
    gmsh.model.mesh.generate(2)
    gmsh.write(MSH_FILE)
    # Count all triangular / quadrilateral elements (dimension 2)
    element_types, _, _ = gmsh.model.mesh.getElements(dim=2)
    n_elements = sum(
        len(gmsh.model.mesh.getElements(dim=2, tag=-1)[1][i])
        for i in range(len(element_types))
    )
    gmsh.finalize()
    return n_elements


def solve(solve_name, post_name, flag):
    """
    Solve and post-process by calling getdp via subprocess.
    flag sets Flag_AnalysisType.
    """
    result = subprocess.run(
        [
            GETDP_EXE,
            PRO_FILE,
            "-msh",
            MSH_FILE,
            "-setnumber",
            "Flag_AnalysisType",
            str(flag),
            "-solve",
            solve_name,
            "-pos",
            post_name,
            "-v",
            "2",
        ],
        cwd=WORK_DIR,
        capture_output=True,
        text=True,
    )
    if result.returncode != 0:
        raise RuntimeError(
            f"GetDP failed (exit {result.returncode}):\n"
            + "\n".join(result.stderr.strip().splitlines()[-20:])
        )


def parse_table_file(filepath):
    """
    Parse a GetDP 'Format Table' file.
    Lines starting with // or # are comments.
    Each data line has the form:   freq_or_time   Re(value)   Im(value)
    Returns the last entry as a Python complex number.
    """
    rows = []
    with open(filepath) as f:
        for line in f:
            line = line.strip()
            if not line or line.startswith("//") or line.startswith("#"):
                continue
            parts = line.split()
            try:
                rows.append([float(p) for p in parts])
            except ValueError:
                continue

    if not rows:
        raise ValueError(f"No numeric data found in {filepath}")

    last = rows[-1]
    # Column layout: [time_or_freq, Re, Im]  (GetDP complex table format)
    if len(last) >= 3:
        return complex(last[1], last[2])
    elif len(last) == 2:
        return complex(last[1], 0.0)
    else:
        return complex(last[0], 0.0)


# ---------------------------------------------------------------------------
# Main sweep
# ---------------------------------------------------------------------------


def run_sweep():
    """Run the full mesh-size sweep and save results to RESULTS_DIR."""
    os.makedirs(RESULTS_DIR, exist_ok=True)

    cfg = ANALYSIS_CONFIG[ANALYSIS]
    result_keys = cfg["results"]  # {key: (dat_filename, label)}

    valid_ms = []
    n_elements_list = []
    collected = {key: [] for key in result_keys}

    for ms in MS_VALUES:
        print(f"\n{'=' * 50}")
        print(f"  ms = {ms}")
        print("=" * 50)

        # 1. Generate mesh via gmsh Python API
        try:
            print("  [Gmsh] meshing...")
            n_elem = mesh(ms, cfg["flag"])
            print(f"  Number of 2-D elements: {n_elem}")
        except Exception as exc:
            print(f"  !! Gmsh FAILED: {exc}")
            continue

        # 2. Solve + post-process via getdp subprocess
        try:
            print("  [GetDP] solving...")
            solve(cfg["solve"], cfg["post"], cfg["flag"])
        except Exception as exc:
            print(f"  !! GetDP FAILED: {exc}")
            continue

        # 3. Read results — |value| is the relevant scalar for time-harmonic problems
        res_dir = os.path.join(WORK_DIR, "res")
        row = {}
        try:
            for key, (dat_file, label) in result_keys.items():
                val = abs(parse_table_file(os.path.join(res_dir, dat_file)))
                row[key] = val
                print(f"  {label:<35} = {val:.6e}")
        except Exception as exc:
            print(f"  !! Could not read result files: {exc}")
            continue

        valid_ms.append(ms)
        n_elements_list.append(n_elem)
        for key, val in row.items():
            collected[key].append(val)

    if not valid_ms:
        print(
            "\nNo results collected — check gmsh/getdp Python packages are installed."
        )
        raise SystemExit(1)

    data = {
        "ms": valid_ms,
        "n_elements": n_elements_list,
        "analysis": ANALYSIS,
        **collected,
    }
    with open(RESULTS_FILE, "w") as f:
        json.dump(data, f, indent=2)
    print(f"\nResults saved -> {RESULTS_FILE}")


# ---------------------------------------------------------------------------
# Plot
# ---------------------------------------------------------------------------


def plot_electrodynamics_energy_comparison():
    """
    Single plot of electric energy relative change vs. number of elements
    for the three electrodynamics runs (e5, e6, e7, e8), one line each.
    """
    variants = {
        "e5": r"$\sigma_{\mathrm{HDPE}} = 10^{-5}$",
        "e6": r"$\sigma_{\mathrm{HDPE}} = 10^{-6}$",
        "e7": r"$\sigma_{\mathrm{HDPE}} = 10^{-7}$",
        # "e8": r"$\sigma_{\mathrm{HDPE}} = 10^{-8}$",
    }
    _, ax = plt.subplots(figsize=(9, 5))

    for variant, label in variants.items():
        results_path = os.path.join(
            WORK_DIR, f"convergence_results_electrodynamics_{variant}", "results.json"
        )
        try:
            with open(results_path) as f:
                data = json.load(f)
        except Exception as e:
            continue

        x_all = data.get("n_elements", data["ms"])
        values = data["energies"]
        x_mid = x_all[1:]
        rel_changes = [
            100 * (values[i] - values[i - 1]) / values[i - 1]
            for i in range(1, len(values))
        ]
        ax.plot(x_mid, rel_changes, "o-", linewidth=1, markersize=7, label=label)

    if not ax.lines:
        plt.close()
        print(
            "plot_electrodynamics_energy_comparison: no variant data found, skipping."
        )
        return

    ax.set_xlabel(r"\# of elements")
    ax.set_ylabel(r"Relative change [\%]")
    ax.legend()
    ax.grid(True, alpha=0.5, linestyle="--", color="gray")
    if LOG_SCALE_X:
        ax.set_xscale("log")
    if LOG_SCALE_Y:
        ax.set_yscale("log")

    plt.tight_layout()

    out_pdf = os.path.join(
        WORK_DIR, "convergence_electrodynamics_energy_comparison.pdf"
    )
    plt.savefig(out_pdf, bbox_inches="tight")
    print(f"Plot saved -> {out_pdf}")


def plot_relative_change(results_path):
    """
    Plot the relative change between consecutive steps for all quantities
    on a single axis, to visualise convergence rate.
    """
    with open(results_path) as f:
        data = json.load(f)

    analysis = data.get("analysis", ANALYSIS)
    cfg = ANALYSIS_CONFIG[analysis]
    x_all = data.get("n_elements", data["ms"])
    xlabel = r"\# of elements" if "n_elements" in data else r"Mesh size parameter $m_s$"
    result_keys = cfg["results"]

    # x-axis: the finer point of each consecutive pair
    x_mid = x_all[1:]

    fig, ax = plt.subplots(figsize=(9, 5))

    for key, (_, label) in result_keys.items():
        values = data[key]
        rel_changes = [
            100 * (values[i] - values[i - 1]) / (values[i - 1])
            for i in range(1, len(values))
        ]
        ax.plot(x_mid, rel_changes, "o-", linewidth=1, markersize=7, label=label)

    ax.set_xlabel(xlabel)
    ax.set_ylabel(r"Relative change [\%]")
    ax.legend()
    ax.grid(True, alpha=0.5, linestyle="--", color="gray")
    if LOG_SCALE_X:
        ax.set_xscale("log")
    if LOG_SCALE_Y:
        ax.set_yscale("log")

    plt.tight_layout()

    out_pdf = os.path.join(
        os.path.dirname(results_path), "convergence_relative_change.pdf"
    )
    plt.savefig(out_pdf, bbox_inches="tight")
    print(f"Plot saved -> {out_pdf}")


# ---------------------------------------------------------------------------
# Entry point
# ---------------------------------------------------------------------------

if __name__ == "__main__":
    if ALWAYS_RUN or not os.path.isfile(RESULTS_FILE):
        run_sweep()
    else:
        print(f"Results already exist ({RESULTS_FILE}). Skipping computation.")
        print("Set ALWAYS_RUN = True to force recomputation.")

    plot_relative_change(RESULTS_FILE)
    plot_electrodynamics_energy_comparison()

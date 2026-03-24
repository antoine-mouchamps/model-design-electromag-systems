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

WORK_DIR = os.path.dirname(os.path.abspath(__file__))
GEO_FILE = os.path.join(WORK_DIR, "cable.geo")
PRO_FILE = os.path.join(WORK_DIR, "cable.pro")
MSH_FILE = os.path.join(WORK_DIR, "cable.msh")

ONELAB_DIR = r"C:\Users\antoi\Documents\UNIF\master_2\modelling_design_electromagnetic_systems\onelab-Windows64"
GETDP_EXE = os.path.join(ONELAB_DIR, "getdp.exe")

# ms values to sweep — from coarse to fine
MS_VALUES = [2.0, 1.5, 1.0, 0.75, 0.5]  # , 0.25, 0.175, 0.125]

# Choose the analysis type: "electrodynamics" or "magnetodynamics"
ANALYSIS = "electrodynamics"

# Per-analysis configuration: GetDP solve/post names and result files to collect.
# Each entry in "results" maps a key to (dat_filename_in_res/, axis_label).
ANALYSIS_CONFIG = {
    "electrodynamics": {
        "flag": 0,  # Flag_AnalysisType in cable.pro (controls If/EndIf blocks)
        "solve": "Electrodynamics",
        "post": "Post_Ele",
        "results": {
            "energies": ("energy.dat", "Electric Energy [J/m]"),
            "capacitances": ("C.dat", "Capacitance [F/m]"),
        },
        "title": "Electrodynamics",
    },
    "magnetodynamics": {
        "flag": 1,  # Flag_AnalysisType in cable.pro (controls If/EndIf blocks)
        "solve": "Magnetoquasistatics",
        "post": "Post_Mag",
        "results": {
            "losses_total": ("losses_total.dat", "Total Losses [W/m]"),
            "losses_inds": ("losses_inds.dat", "Source Losses [W/m]"),
            "resistance": ("Rinds.dat", "Resistance [\u03a9/m]"),
            "inductance": ("Linds.dat", "Inductance [H/m]"),
            "mag_energy": ("MagEnergy.dat", "Magnetic Energy [J/m]"),
        },
        "title": "Magnetodynamics",
    },
}

# Results folder is analysis-specific so both sets can coexist.
RESULTS_DIR = os.path.join(WORK_DIR, f"convergence_results_{ANALYSIS}")
RESULTS_FILE = os.path.join(RESULTS_DIR, "results.json")
ALWAYS_RUN = False

# Set True to apply log scale on the y-axis of all plots.
LOG_SCALE = False


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------


def mesh(ms):
    """
    Generate a 2-D mesh for the given ms value using the gmsh Python API.
    Passing '-setnumber ms <value>' via initialize's argv overrides the
    DefineNumber default in the .geo file.
    """
    gmsh.initialize(["", "-setnumber", "ms", str(ms)])
    gmsh.option.setNumber("General.Verbosity", 3)
    gmsh.open(GEO_FILE)
    gmsh.model.mesh.generate(2)
    gmsh.write(MSH_FILE)
    gmsh.finalize()


def solve(solve_name, post_name, flag):
    """
    Solve and post-process by calling getdp via subprocess (no Python package exists).
    flag sets Flag_AnalysisType so the correct If/EndIf blocks in the .pro are parsed.
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
    collected = {key: [] for key in result_keys}

    for ms in MS_VALUES:
        print(f"\n{'=' * 50}")
        print(f"  ms = {ms}")
        print("=" * 50)

        # 1. Generate mesh via gmsh Python API
        try:
            print("  [Gmsh] meshing...")
            mesh(ms)
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
        for key, val in row.items():
            collected[key].append(val)

    if not valid_ms:
        print(
            "\nNo results collected — check gmsh/getdp Python packages are installed."
        )
        raise SystemExit(1)

    data = {"ms": valid_ms, "analysis": ANALYSIS, **collected}
    with open(RESULTS_FILE, "w") as f:
        json.dump(data, f, indent=2)
    print(f"\nResults saved → {RESULTS_FILE}")


# ---------------------------------------------------------------------------
# Plot
# ---------------------------------------------------------------------------


def plot(results_path):
    """Load saved results from *results_path* and produce one subplot per quantity."""
    with open(results_path) as f:
        data = json.load(f)

    analysis = data.get("analysis", ANALYSIS)
    cfg = ANALYSIS_CONFIG[analysis]
    valid_ms = data["ms"]
    result_keys = cfg["results"]

    n = len(result_keys)
    fig, axes = plt.subplots(n, 1, figsize=(8, 4 * n), sharex=True)
    if n == 1:
        axes = [axes]

    for ax, (key, (_, label)) in zip(axes, result_keys.items()):
        ax.plot(valid_ms, data[key], "o-", linewidth=1, markersize=8)
        ax.set_ylabel(label)
        ax.invert_xaxis()
        ax.grid(True, alpha=0.5, linestyle="--", color="gray")
        if LOG_SCALE:
            ax.set_yscale("log")

    axes[-1].set_xlabel("Mesh size parameter ms   (coarse  ←  →  fine)")
    fig.suptitle(
        f"Mesh Convergence Study — {cfg['title']}", fontsize=13, fontweight="bold"
    )
    plt.tight_layout()

    out_pdf = os.path.join(os.path.dirname(results_path), "convergence_study.pdf")
    plt.savefig(out_pdf, bbox_inches="tight")
    print(f"Plot saved → {out_pdf}")
    plt.show()


def plot_relative_change(results_path):
    """
    Plot the relative change between consecutive ms steps for all quantities
    on a single axis, to visualise convergence rate.
    """
    with open(results_path) as f:
        data = json.load(f)

    analysis = data.get("analysis", ANALYSIS)
    cfg = ANALYSIS_CONFIG[analysis]
    valid_ms = data["ms"]
    result_keys = cfg["results"]

    # x-axis: the finer ms of each consecutive pair
    ms_mid = valid_ms[1:]

    fig, ax = plt.subplots(figsize=(9, 5))

    for key, (_, label) in result_keys.items():
        values = data[key]
        rel_changes = [
            abs(values[i] - values[i - 1]) / abs(values[i - 1])
            for i in range(1, len(values))
        ]
        ax.plot(ms_mid, rel_changes, "o-", linewidth=1, markersize=7, label=label)

    ax.invert_xaxis()
    ax.set_xlabel("Mesh size parameter ms   (coarse  ←  →  fine)")
    ax.set_ylabel(r"Relative change [\%]")
    ax.legend()
    ax.grid(True, alpha=0.5, linestyle="--", color="gray")
    if LOG_SCALE:
        ax.set_yscale("log")

    plt.tight_layout()

    out_pdf = os.path.join(
        os.path.dirname(results_path), "convergence_relative_change.pdf"
    )
    plt.savefig(out_pdf, bbox_inches="tight")
    print(f"Plot saved → {out_pdf}")
    plt.show()


# ---------------------------------------------------------------------------
# Entry point
# ---------------------------------------------------------------------------

if __name__ == "__main__":
    if ALWAYS_RUN or not os.path.isfile(RESULTS_FILE):
        run_sweep()
    else:
        print(f"Results already exist ({RESULTS_FILE}). Skipping computation.")
        print("Set ALWAYS_RUN = True to force recomputation.")

    plot(RESULTS_FILE)
    plot_relative_change(RESULTS_FILE)

"""
Convergence study: sweep mesh size parameter ms and track global quantities
(electric energy, voltage, capacitance) computed by cable.pro (Electrodynamics).

Uses the gmsh Python API for meshing, and subprocess for GetDP
(no Python package exists for GetDP).

Usage:
    python convergence_study.py
"""

import os
import subprocess
from turtle import color
import gmsh
import numpy as np
import matplotlib.pyplot as plt

WORK_DIR = os.path.dirname(os.path.abspath(__file__))
GEO_FILE = os.path.join(WORK_DIR, "cable.geo")
PRO_FILE = os.path.join(WORK_DIR, "cable.pro")
MSH_FILE = os.path.join(WORK_DIR, "cable.msh")

ONELAB_DIR = r"C:\Users\antoi\Documents\UNIF\master_2\modelling_design_electromagnetic_systems\onelab-Windows64"
GETDP_EXE = os.path.join(ONELAB_DIR, "getdp.exe")

# ms values to sweep — from coarse (2) to fine (0.5)
MS_VALUES = [2.0, 1.5, 1.0, 0.75, 0.5, 0.25, 0.2]


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


def solve():
    """
    Solve and post-process by calling getdp via subprocess (no Python package exists).
    """
    result = subprocess.run(
        [
            GETDP_EXE,
            PRO_FILE,
            "-msh",
            MSH_FILE,
            "-solve",
            "Electrodynamics",
            "-pos",
            "Post_Ele",
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

valid_ms = []
energies = []
voltages = []
capacitances = []

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

    # 2. Solve + post-process via getdp Python API
    try:
        print("  [GetDP] solving...")
        solve()
    except Exception as exc:
        print(f"  !! GetDP FAILED: {exc}")
        continue

    # 3. Read results
    res = os.path.join(WORK_DIR, "res")
    try:
        We = parse_table_file(os.path.join(res, "energy.dat"))
        V = parse_table_file(os.path.join(res, "U.dat"))
        C = parse_table_file(os.path.join(res, "C.dat"))
    except Exception as exc:
        print(f"  !! Could not read result files: {exc}")
        continue

    # For a time-harmonic problem the interesting scalar magnitude is |value|
    We_val = abs(We)
    V_val = abs(V)
    C_val = abs(C)

    valid_ms.append(ms)
    energies.append(We_val)
    voltages.append(V_val)
    capacitances.append(C_val)

    print(f"  Electric Energy = {We_val:.6e} J/m")
    print(f"  Voltage         = {V_val:.6e} V")
    print(f"  Capacitance     = {C_val:.6e} F/m")

if not valid_ms:
    print("\nNo results collected — check gmsh/getdp Python packages are installed.")
    raise SystemExit(1)

# ---------------------------------------------------------------------------
# Plot
# ---------------------------------------------------------------------------

fig, axes = plt.subplots(3, 1, figsize=(8, 10), sharex=True)

datasets = [
    (energies, "Electric Energy [J/m]", "Electric Energy"),
    (voltages, "Voltage [V]", "Voltage"),
    (capacitances, "Capacitance [F/m]", "Capacitance"),
]

for ax, (data, ylabel, title) in zip(axes, datasets):
    ax.plot(valid_ms, data, "o-", linewidth=1, markersize=8)
    ax.set_ylabel(ylabel)
    ax.invert_xaxis()  # left = coarse, right = fine
    ax.grid(True, alpha=0.5, linestyle="--", color="gray")
    # ax.ticklabel_format(axis="y", style="sci", scilimits=(0, 0))

axes[-1].set_xlabel("Mesh size parameter ms   (coarse  ←  →  fine)")
fig.suptitle("Mesh Convergence Study — Electrodynamics", fontsize=13, fontweight="bold")
plt.tight_layout()

out_pdf = os.path.join(WORK_DIR, "convergence_study.pdf")
plt.savefig(out_pdf, bbox_inches="tight")
print(f"\nPlot saved → {out_pdf}")
plt.show()

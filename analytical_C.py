import numpy as np


def coaxial_c(epsilon, r_inner, r_outer):
    """
    Analytical capacitance per unit length of a coaxial cable
    C' = 2 * pi * epsilon / ln(r_outer / r_inner)
    """
    return 2 * np.pi * epsilon / (np.log(r_outer / r_inner))


if __name__ == "__main__":
    mm = 1e-3
    r_phase_cable_conductor = 29.8 / 2 * mm  # diameter of conductor
    phase_cable_insulation_thickness = (15 + 0) * mm  # thickness of insulation
    r_phase_cable_with_insulation = (
        (62.6 + 0) / 2 * mm
    )  # diameter of phase conductor with insulation
    semiconductor_thickness = (
        r_phase_cable_with_insulation
        - r_phase_cable_conductor
        - phase_cable_insulation_thickness
    )  # thickness of semiconductor layer

    epsilon_0 = 8.854187818e-12
    epsilon_insu = epsilon_0 * 2.5
    epsilon_semi = epsilon_0 * 20.0

    r_c = r_phase_cable_conductor
    r1 = r_c + semiconductor_thickness
    r_s_in = r1 + phase_cable_insulation_thickness
    C_semi = coaxial_c(epsilon_semi, r_c, r1)
    C_insu = coaxial_c(epsilon_insu, r1, r_s_in)
    print(f"C_semi = {C_semi:.2e} F/m")
    print(f"C_insu = {C_insu:.2e} F/m")
    C_phase = (C_semi * C_insu) / (C_semi + C_insu)

    print(f"C_phase = {C_phase:.2e} F/m")

    C_tot = 3 * C_phase
    print(f"C_tot = {C_tot:.2e} F/m")

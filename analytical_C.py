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
    lead_sheath_thickness = 2.4 * mm  # thickness of lead sheath
    hdpe_sheath_thickness = 2.1 * mm  # thickness of inner sheath
    r_phase_cable_outer = (
        r_phase_cable_with_insulation + lead_sheath_thickness + hdpe_sheath_thickness
    )  # diameter of phase conductor with insulation and sheaths

    steel_wire_armour_thickness = 7 * mm  # thickness of Steel pipe
    outer_sheath_cable = 4 * mm
    r_cable_outer = (185 + 0) / 2 * mm  # cable outer diameter

    epsilon_insu = 8.854187818e-12 * 2.25
    r_c = r_phase_cable_conductor
    r_s_in = (
        r_phase_cable_conductor
        + semiconductor_thickness
        + phase_cable_insulation_thickness
    )
    r_s_out = r_s_in + lead_sheath_thickness
    R_a = r_cable_outer - steel_wire_armour_thickness - outer_sheath_cable

    C_phase = coaxial_c(epsilon_insu, r_c, r_s_in)
    d = 2 * r_phase_cable_outer / (np.sqrt(3))
    r_eq = np.cbrt(3 * r_s_out * d**2)
    C_armor = coaxial_c(epsilon_insu, r_eq, R_a)

    print(f"C_phase = {C_phase:.2e} F/m")
    print(f"C_armor = {C_armor:.2e} F/m")

    C_tot_per_phase = (C_phase * (C_armor / 3)) / (C_phase + (C_armor / 3))
    print(f"C_tot_per_phase = {C_tot_per_phase:.2e} F/m")
    C_tot = 3 * C_tot_per_phase
    print(f"C_tot = {C_tot:.2e} F/m")

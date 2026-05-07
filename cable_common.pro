
mm = 1e-3;

DefineConstant[
  ms = {1, Min 0.01, Max 3, Name "Mesh size", Visible 1}
];

DefineConstant[
  Flag_AnalysisType = {0,
    Choices{
      0="Electrodynamic",
      1="Magnetoquasistatic",
      2="Magneto-thermal",
      3="Magneto-thermal-coupled"
    },
    Name "{00FE param./Type of analysis", Highlight "ForestGreen",
    ServerAction Str["Reset", StrCat[ "GetDP/1ResolutionChoices", ",", "GetDP/2PostOperationChoices"]] }
];

DefineConstant[
  Flag_Defect = {0,
    Choices{0="No defect", 1="With defect"},
    Name "{00FE param./Defect", Highlight "Red"}
];

DefineConstant[
  sheath_thickness = {0,
    Choices{0="Default", 1="Double thickness"},
    Name "{00FE param./Phase Sheath thickness"}
];

r_phase_cable_conductor = 29.8/2*mm; // diameter of conductor
phase_cable_insulation_thickness = (15-sheath_thickness*2.1)*mm; // thickness of insulation
r_phase_cable_with_insulation = (-sheath_thickness*2.1 + (62.6/2))*mm; // diameter of phase conductor with insulation
semiconductor_thickness = r_phase_cable_with_insulation - r_phase_cable_conductor - phase_cable_insulation_thickness; // thickness of semiconductor layer
lead_sheath_thickness = 2.4*mm; // thickness of lead sheath
hdpe_sheath_thickness = (2.1+(sheath_thickness*2.1))*mm; // thickness of inner sheath
r_phase_cable_outer = r_phase_cable_with_insulation + lead_sheath_thickness + hdpe_sheath_thickness; // diameter of phase conductor with insulation and sheaths

steel_wire_armour_thickness  = 7*mm;  // thickness of Steel pipe
outer_sheath_cable = 4*mm;
r_cable_outer = (0*2.1*2+(185/2))*mm; // cable outer diameter

scale_mesh_ground = (Flag_AnalysisType == 0 || Flag_AnalysisType == 1) ? 1 : 0.1;
r_domain = (Flag_AnalysisType == 0 || Flag_AnalysisType == 1) ? 1.2*r_cable_outer : r_cable_outer + 1;
r_domain_inf = (Flag_AnalysisType == 0 || Flag_AnalysisType == 1) ? 1.5*r_domain : 1.05*r_domain;

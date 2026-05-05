
mm = 1e-3;
r_cable_outer = (185+0)/2*mm; // cable outer diameter

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

scale_mesh_ground = (Flag_AnalysisType == 0 || Flag_AnalysisType == 1) ? 1 : 0.1;
r_domain = (Flag_AnalysisType == 0 || Flag_AnalysisType == 1) ? 1.2*r_cable_outer : r_cable_outer + 1;
r_domain_inf = (Flag_AnalysisType == 0 || Flag_AnalysisType == 1) ? 1.5*r_domain : 1.05*r_domain;
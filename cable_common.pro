
mm = 1e-3;
r_cable_outer = (185+0)/2*mm; // cable outer diameter

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
  scale_mesh_ground = {(Flag_AnalysisType == 2 || Flag_AnalysisType == 3) ? 0.1 : 1,
    Choices{1="Default (1) ", 0.1="Magneto-thermal (0.1)", 0.025="Magneto-thermal (0.025)"},
    Name "{00FE param./Ground mesh scale", Label "Ground mesh scale"}
];

DefineConstant[
  Flag_RDomain = {0,
    Choices{0="Default (1.2 * r_cable)", 1="Magneto-thermal (r_cable + 2m)"},
    Name "{00FE param./Domain radius", Label "Domain radius"}
];

r_domain = (Flag_RDomain == 0) ? 1.2*r_cable_outer : r_cable_outer + 2;
r_domain_inf = 1.5*r_domain;
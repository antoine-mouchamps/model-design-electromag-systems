DefineConstant[
  Flag_AnalysisType = {0,
    Choices{
      0="Electrodynamic",
      1="Magnetoquasistatic" //,2="Magneto-thermal"
    },
    Name "{00FE param./Type of analysis", Highlight "ForestGreen",
    ServerAction Str["Reset", StrCat[ "GetDP/1ResolutionChoices", ",", "GetDP/2PostOperationChoices"]] }
];

Function{
  Resolution_name() = Str['Electrodynamics', 'Magnetoquasistatics', 'Magnetothermal'];
  PostOperation_name() = Str['Post_Ele', 'Post_Mag', 'Post_MagTher'];
}

DefineConstant[
  r_ = {Str[Resolution_name(Flag_AnalysisType)], Name "GetDP/1ResolutionChoices"}
  c_ = {"-solve -v2 -pos", Name "GetDP/9ComputeCommand"},
  p_ = {Str[PostOperation_name(Flag_AnalysisType)], Name "GetDP/2PostOperationChoices"}
];

Group {
  WireConductor_1 = Region[{11}];
  WireConductor_2 = Region[{21}];
  WireConductor_3 = Region[{31}];
  WireConductor = Region[{WireConductor_1, WireConductor_2, WireConductor_3}];

  WireSemiconductor_1 = Region[{12}];
  WireSemiconductor_2 = Region[{22}];
  WireSemiconductor_3 = Region[{32}];
  WireSemiconductor = Region[{WireSemiconductor_1, WireSemiconductor_2, WireSemiconductor_3}];

  WireInsulation_1 = Region[{13}];
  WireInsulation_2 = Region[{23}];
  WireInsulation_3 = Region[{33}];
  WireInsulation = Region[{WireInsulation_1, WireInsulation_2, WireInsulation_3}];

  WireSheath_1 = Region[{14}];
  WireSheath_2 = Region[{24}];
  WireSheath_3 = Region[{34}];
  WireSheath = Region[{WireSheath_1, WireSheath_2, WireSheath_3}];

  CableInsulationInside = Region[{1}];
  CableInsulationAround = Region[{2}];
  CableSemiconductor = Region[{3}];
  CableArmor = Region[{4}];
  CableOuterSheath = Region[{5}];
  Ground = Region[{6}];

  // electrodynamics
  surrounding_dirichlet_ele = Region[{5}];
  domain_ele = Region[ {
    Ground,
    WireConductor,
    WireSemiconductor,
    WireInsulation,
    WireSheath,
    CableInsulationInside,
    CableInsulationAround,
    CableSemiconductor,
    CableArmor,
    CableOuterSheath
  } ];

  // Magnetoquasistatics
  Sur_Dirichlet_Mag = Region[{50}];
  DomainS_Mag       = Region[{WireConductor}];

  DomainNC_Mag  = Region[ {Ground, WireConductor, WireSemiconductor, WireInsulation, CableInsulationInside, CableInsulationAround, CableSemiconductor, CableOuterSheath} ]; // non-conducting regions
  DomainC_Mag   = Region[ {WireSheath, CableArmor} ]; //conducting regions
  Domain_Mag = Region[ {DomainNC_Mag, DomainC_Mag} ];

  DomainDummy = Region[123474982982]; //postpro
}

Function {
  mu0 = 4.e-7 * Pi;
  eps0 = 8.854187818e-12;
  mur_steel =4;

  sigma[WireConductor] = 5.96e7; // conductivity of copper
  sigma[WireSemiconductor] = 2; // typical for semiconducting layer, XLPE+carbon blacn (gpt)
  sigma[WireInsulation] = 10e-14; // https://www.researchgate.net/figure/Conductivity-of-XLPE-versus-temperature-and-electric-field_fig6_329127752
  sigma[WireSheath] = 4.55e6; // conductivity of lead https://en.wikipedia.org/wiki/Electrical_resistivity_and_conductivity#Resistivity_and_conductivity_of_various_materials

  sigma[CableInsulationInside] = 10e-14;
  sigma[CableInsulationAround] = 10e-14;
  sigma[CableSemiconductor] = 2;
  sigma[CableArmor] = 4.7e6; // Value from simpleCable.pro for galvanized/tensile steel
  sigma[CableOuterSheath] = 10e-15; // HDPE
  sigma[Ground] = 2; // conductivity of soil

  epsilon[Region[{Ground, WireConductor, WireInsulation, WireSheath, CableInsulationInside, CableInsulationAround, CableSemiconductor, CableArmor, CableOuterSheath}]] = eps0;
  epsilon[Region[{WireSemiconductor}]] = eps0*2.25;

  nu[Region[{Ground, WireConductor, WireSemiconductor, WireInsulation, WireSheath, CableInsulationInside, CableInsulationAround, CableSemiconductor, CableOuterSheath}]]  = 1./mu0;
  nu[Region[{CableArmor}]]  = 1./(mu0*mur_steel);


  freq = 50;
  omega = 2*Pi*freq;

  Pa = 0.; Pb = -120./180.*Pi; Pc = -240./180.*Pi;
  I = 715; // maximum value current in data sheet
  V_rms = 132e3; // RMS value in the line voltage [V]
  V_rms_max = 145e3; // maximum RMS value in the line voltage [V]

  V0 = V_rms/Sqrt[3]; // peak value

  Ns[]= 1;
  Sc[]= SurfaceArea[];
}

Constraint {
  // Electrical constraints
  { Name ElectricScalarPotential;
    Case {
      { Region WireConductor_1; Value V0; TimeFunction F_Cos_wt_p[]{2*Pi*freq, Pa}; }
      { Region WireConductor_2; Value V0; TimeFunction F_Cos_wt_p[]{2*Pi*freq, Pb}; }
      { Region WireConductor_3; Value V0; TimeFunction F_Cos_wt_p[]{2*Pi*freq, Pc}; }

      { Region surrounding_dirichlet_ele; Value 0; }
    }
  }

  // Magnetic constraints
  { Name MagneticVectorPotential;
    Case {
      { Region Sur_Dirichlet_Mag; Value 0.; }
    }
  }

  { Name Voltage;
    Case {
    }
  }

  { Name Current;
    Case {
      { Region WireConductor_1; Value I; TimeFunction F_Cos_wt_p[]{2*Pi*freq, Pa}; }
      { Region WireConductor_2; Value I; TimeFunction F_Cos_wt_p[]{2*Pi*freq, Pb}; }
      { Region WireConductor_3; Value I; TimeFunction F_Cos_wt_p[]{2*Pi*freq, Pc}; }
    }
  }

}

//---------------------------------------------------------------------

Jacobian {
  { Name Vol;
    Case {
      { Region All; Jacobian Vol; }
    }
  }
  { Name Sur;
    Case {
      { Region All; Jacobian Sur; }
    }
  }
}
Integration {
  { Name I1;
    Case {
      { Type Gauss;
        Case {
          { GeoElement Triangle;   NumberOfPoints  4; }
          { GeoElement Quadrangle; NumberOfPoints  4; }
        }
      }
    }
  }
}




//--------------------------------------------------------------------------
If (Flag_AnalysisType == 0)
  // Electrodynamics
  //------------------------------------------------------------------------

  FunctionSpace {

    { Name Hgrad_v_Ele; Type Form0;
      BasisFunction { // v = \sum_n v_n  s_n,  for all nodes
        { Name sn; NameOfCoef vn; Function BF_Node;
          Support domain_ele; Entity NodesOf[ All ]; }
      }

      Constraint {
        { NameOfCoef vn; EntityType NodesOf;
          NameOfConstraint ElectricScalarPotential; }
      }
    }

  }

  Formulation {

    { Name Electrodynamics_v; Type FemEquation;
      Quantity {
        { Name v; Type Local; NameOfSpace Hgrad_v_Ele; }
      }
      Equation {
        Galerkin { [ sigma[] * Dof{d v} , {d v} ] ;
          In domain_ele; Jacobian Vol ; Integration I1 ; }
        Galerkin { DtDof[ epsilon[] * Dof{d v} , {d v} ];
          In domain_ele; Jacobian Vol; Integration I1; }
      }
    }

  }

  Resolution {

    { Name Electrodynamics;
      System {
        { Name Sys_Ele; NameOfFormulation Electrodynamics_v;
          Type Complex; Frequency freq; }
      }
      Operation {
        CreateDir["res"];
        Generate[Sys_Ele]; Solve[Sys_Ele]; SaveSolution[Sys_Ele];
      }
    }

  }

  PostProcessing {

    { Name EleDyn_v; NameOfFormulation Electrodynamics_v;
      Quantity {
        { Name v; Value { Term { [ {v} ]; In domain_ele; Jacobian Vol; } } }
        { Name e; Value { Term { [ -{d v} ]; In domain_ele; Jacobian Vol; } } }
        { Name norm_e; Value { Term { [ Norm[-{d v}] ]; In domain_ele; Jacobian Vol; } } }

        { Name d; Value { Term { [ -epsilon[] * {d v} ]; In domain_ele; Jacobian Vol; } } }
        { Name norm_d; Value { Term { [ Norm[-epsilon[] * {d v}] ]; In domain_ele; Jacobian Vol; } } }

        { Name j ; Value { Term { [ -sigma[] * {d v} ] ; In domain_ele ; Jacobian Vol; } } }
        { Name j_displ; Value { Term { [ -epsilon[] * {d v} * Complex[0, 1] * omega ]; In domain_ele; Jacobian Vol; } } }
        { Name norm_j ; Value { Term { [ Norm[-sigma[] * {d v}] ] ; In domain_ele ; Jacobian Vol; } } }

        { Name ElectricEnergy; Value {
            Integral {
              [ 0.5 * epsilon[] * SquNorm[{d v}] ];
              In domain_ele; Jacobian Vol; Integration I1;
            }
          }
        }

        { Name V0 ; Value {// For recovering the imposed voltage in post-pro
            Term { Type Global ; [ V0 * F_Cos_wt_p[]{2*Pi*freq, Pa}] ; In WireConductor_1 ; }
          } }

        { Name C_from_Energy ; Value { Term { Type Global; [ 2*$We/SquNorm[$voltage] ] ; In DomainDummy ; } } }
      }
    }
  }

  PostOperation{

  { Name Post_Ele; NameOfPostProcessing EleDyn_v;
    Operation {
      Print[ v,  OnElementsOf domain_ele, File "res/v.pos" ];
      Print[ norm_e, OnElementsOf domain_ele, Name "|E| [V/m]",  File "res/em.pos" ]; // Name is not compulsory, it may be adapted
      Print[ norm_d, OnElementsOf domain_ele, Name "|D| [A/mÂ²]", File "res/dm.pos" ];
      Print[ j, OnElementsOf domain_ele, Name "j [A/mÂ²]", File "res/j.pos" ];
      Print[ j_displ, OnElementsOf domain_ele, Name "j_displ [A/mÂ²]", File "res/j_displ.pos" ];
      Print[ e,  OnElementsOf domain_ele, Name "E [V/m]",  File "res/e.pos" ];

      Print[ ElectricEnergy[domain_ele], OnGlobal, Format Table, StoreInVariable $We,
        SendToServer "{01Global ELE results/0Electric energy", File "res/energy.dat" ];
      Print[ V0, OnRegion WireConductor_1, Format Table, StoreInVariable $voltage,
        SendToServer "{01Global ELE results/0Voltage", Units "V", File "res/U.dat" ];
      Print[ C_from_Energy, OnRegion DomainDummy, Format Table, StoreInVariable $C1,
        SendToServer "{01Global ELE results/1Capacitance", Units "F/m", File "res/C.dat" ];
    }
  }
}
EndIf

//--------------------------------------------------------------------------
If (Flag_AnalysisType == 1)
  // Magnetoquasistatics
  //------------------------------------------------------------------------
  FunctionSpace {

    { Name Hcurl_a_Mag_2D; Type Form1P;
      BasisFunction {
        { Name se; NameOfCoef ae; Function BF_PerpendicularEdge;
          Support Domain_Mag; Entity NodesOf[ All ]; }
      }
      Constraint {
        { NameOfCoef ae;
          EntityType NodesOf; NameOfConstraint MagneticVectorPotential ; }
      }
    }

    { Name Hregion_i_2D ; Type Vector ;
      BasisFunction {
        { Name sr ; NameOfCoef ir ; Function BF_RegionZ ;
          Support DomainS_Mag ; Entity DomainS_Mag ; }
      }
      GlobalQuantity {
        { Name Is ; Type AliasOf        ; NameOfCoef ir ; }
        { Name Us ; Type AssociatedWith ; NameOfCoef ir ; }
      }
      Constraint {
        { NameOfCoef Us ; EntityType Region ; NameOfConstraint Voltage ; }
        { NameOfCoef Is ; EntityType Region ; NameOfConstraint Current ; }
      }
    }
  }

  Formulation {

      { Name MQS_a_2D; Type FemEquation; // Magnetoquasistatics
        Quantity {
          { Name a;  Type Local; NameOfSpace Hcurl_a_Mag_2D; }

          // stranded conductors (source)
          { Name ir ; Type Local  ; NameOfSpace Hregion_i_2D ; }
          { Name Us ; Type Global ; NameOfSpace Hregion_i_2D[Us] ; }
          { Name Is ; Type Global ; NameOfSpace Hregion_i_2D[Is] ; }
        }

        Equation {
          Galerkin { [ nu[] * Dof{d a} , {d a} ];
            In Domain_Mag; Jacobian Vol; Integration I1; }
          Galerkin { DtDof [ sigma[] * Dof{a} , {a} ];
            In DomainC_Mag; Jacobian Vol; Integration I1; }

          // or you use the constraints => allows accounting for sigma[]
          Galerkin { [ -Ns[]/Sc[] * Dof{ir}, {a} ] ;
            In DomainS_Mag ; Jacobian Vol ; Integration I1 ; }
          Galerkin { DtDof [ Ns[]/Sc[] * Dof{a}, {ir} ] ;
            In DomainS_Mag ; Jacobian Vol ; Integration I1 ; }

          Galerkin { [ Ns[]/Sc[] / sigma[] * Ns[]/Sc[]* Dof{ir} , {ir} ] ; // resistance term
            In DomainS_Mag ; Jacobian Vol ; Integration I1 ; }
          //GlobalTerm { [ Rdc * Dof{Is} , {Is} ] ; In DomainS ; } // OR this resitance term
          GlobalTerm { [ Dof{Us}, {Is} ] ; In DomainS_Mag ; }
        }
      }

    }


    Resolution {

      { Name Magnetoquasistatics;
        System {
          { Name Sys_Mag; NameOfFormulation MQS_a_2D;
            Type Complex; Frequency freq; }
        }
        Operation {
          CreateDir["res"];

          InitSolution[Sys_Mag];
          Generate[Sys_Mag]; Solve[Sys_Mag]; SaveSolution[Sys_Mag];
        }
      }

    }

    PostProcessing {

      { Name MQS_a_2D; NameOfFormulation MQS_a_2D;
        PostQuantity {
          { Name a; Value { Term { [ {a} ]; In Domain_Mag; Jacobian Vol; } } }
          { Name az; Value { Term { [ CompZ[{a}] ]; In Domain_Mag; Jacobian Vol; } } }
          { Name b; Value { Term { [ {d a} ]; In Domain_Mag; Jacobian Vol; } } }
          { Name norm_b; Value { Term { [ Norm[{d a}] ]; In Domain_Mag; Jacobian Vol; } } }

          { Name j; Value {
              Term { [ -sigma[]*Dt[{a}]]; In DomainC_Mag; Jacobian Vol; }
              Term { [ Ns[]/Sc[]*{ir} ]; In DomainS_Mag; Jacobian Vol; }
            } }

          { Name jz; Value {
              Term { [ CompZ[-sigma[]*Dt[{a}]] ]; In DomainC_Mag; Jacobian Vol; }
              Term { [ CompZ[ Ns[]/Sc[]*{ir} ]]; In DomainS_Mag; Jacobian Vol; }
            } }

          { Name norm_j; Value {
              Term { [ Norm[-sigma[]*Dt[{a}]] ]; In DomainC_Mag; Jacobian Vol; }
              Term { [ Norm[ Ns[]/Sc[]*{ir} ]]; In DomainS_Mag; Jacobian Vol; }
            } }

          { Name local_losses; Value {
              Term { [ 0.5*sigma[]*SquNorm[Dt[{a}]] ]; In DomainC_Mag; Jacobian Vol; }
              Term { [ 0.5/sigma[]*SquNorm[Ns[]/Sc[]*{ir}] ]; In DomainS_Mag; Jacobian Vol; }
            }
          }

          { Name global_losses; Value {
              Integral { [ 0.5*sigma[]*SquNorm[Dt[{a}]] ]   ; In DomainC_Mag  ; Jacobian Vol ; Integration I1 ; }
              Integral { [ 0.5/sigma[]*SquNorm[Ns[]/Sc[]*{ir}] ] ; In DomainS_Mag  ; Jacobian Vol ; Integration I1 ; }
            }
          }

          { Name U ; Value {
              Term { [ {Us} ] ; In DomainS_Mag ; }
            }
          }

          { Name I ; Value {
              Term { [ {Is} ] ; In DomainS_Mag ; }
            }
          }

          { Name R ; Value {
              Term { [ -Re[{Us}/{Is}] ] ; In DomainS_Mag ; }
            }
          }

          { Name L ; Value {
              Term { [ -Im[{Us}/{Is}]/(2*Pi*freq) ] ; In DomainS_Mag ; }
            }
          }
          { Name MagneticEnergy; Value {
              Integral {
                [ 0.5 * nu[] * SquNorm[{d a}] ];
                In Domain_Mag; Jacobian Vol; Integration I1;
              }
            }
          }
          { Name I0 ; Value {// For recovering the imposed current in post-pro
              Term { Type Global ; [ I * F_Cos_wt_p[]{2*Pi*freq, Pa}] ; In WireConductor_1 ; }
            } 
          }

          { Name L_from_Energy ; Value { Term { Type Global; [ 2*$Wm/SquNorm[$current] ] ; In DomainDummy ; } } }
        }
      }

    }


    PostOperation{
      // Magnetic
      //-------------------------------

      { Name Post_Mag; NameOfPostProcessing MQS_a_2D;
        Operation {
          // local results
          Print[ az, OnElementsOf Domain_Mag,
            Name "flux lines: Az [T m]", File "res/az.pos" ];
          Print[ b, OnElementsOf Domain_Mag,
            Name "B [T]", File "res/b.pos" ];
          Print[ norm_b , OnElementsOf Domain_Mag,
            Name "|B| [T]", File "res/bm.pos" ];
          Print[ jz , OnElementsOf Region[{DomainC_Mag}],
            Name "jz [A/m^2]", File "res/jz_inds.pos" ];
          Print[ norm_j , OnElementsOf DomainC_Mag,
            Name "|j| [A/m^2]", File "res/jm.pos" ];

          // global results
          Print[ global_losses[DomainC_Mag], OnGlobal, Format Table,
            SendToServer "{01Global MAG results/0Losses conducting domain",
            Units "W/m", File "res/losses_total.dat" ];

          Print[ global_losses[DomainS_Mag], OnGlobal, Format Table,
            SendToServer "{01Global MAG results/0Losses source",
            Units "W/m", File "res/losses_inds.dat" ];
          Print[ R, OnRegion WireConductor_1, Format Table,
            SendToServer "{01Global MAG results/1Resistance", Units "Î©/m", File "res/Rinds.dat" ];
          Print[ L, OnRegion WireConductor_1, Format Table,
            SendToServer "{01Global MAG results/2Inductance", Units "H/m", File "res/Linds.dat" ];

          Print[ MagneticEnergy[Domain_Mag], OnGlobal, Format Table, StoreInVariable $Wm,
            SendToServer "{01Global MAG results/3Magnetic energy", File "res/MagEnergy.dat" ];
          Print[ I0, OnRegion WireConductor_1, Format Table, StoreInVariable $current,
            SendToServer "{01Global MAG results/4Current", Units "I", File "res/I.dat" ];
          Print[ L_from_Energy, OnRegion DomainDummy, Format Table, StoreInVariable $L1,
            SendToServer "{01Global MAG results/5Inductance from energy", Units "H/m", File "res/L.dat" ];
        }
      }

    }

EndIf

If (Flag_AnalysisType >1)
  Printf("Magneto-thermal case to be implemented!");
EndIf

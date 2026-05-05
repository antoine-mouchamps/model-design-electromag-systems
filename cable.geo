//=================================================
// Geometrical data
//=================================================

mm = 1e-3;

r_phase_cable_conductor = 29.8/2*mm; // diameter of conductor
phase_cable_insulation_thickness = (15+0)*mm; // thickness of insulation
r_phase_cable_with_insulation = (62.6+0)/2*mm; // diameter of phase conductor with insulation
semiconductor_thickness = r_phase_cable_with_insulation - r_phase_cable_conductor - phase_cable_insulation_thickness; // thickness of semiconductor layer
lead_sheath_thickness = 2.4*mm; // thickness of lead sheath
hdpe_sheath_thickness = 2.1*mm; // thickness of inner sheath
r_phase_cable_outer = r_phase_cable_with_insulation + lead_sheath_thickness + hdpe_sheath_thickness; // diameter of phase conductor with insulation and sheaths

steel_wire_armour_thickness  = 7*mm;  // thickness of Steel pipe
outer_sheath_cable = 4*mm;

Include "cable_common.pro";

//=================================================

SetFactory("OpenCASCADE");

h = r_phase_cable_outer * 2 * Sin(Pi/3); // height of equilateral triangle
x0 = 0; y0 = 2*h/3;
x1 = -r_phase_cable_outer; y1 = -h/3;
x2 =  r_phase_cable_outer; y2 = -h/3;

// Define arrays for centers and radii
x_centers[] = {x0, x1, x2};
y_centers[] = {y0, y1, y2};
radii[] = {r_phase_cable_conductor,
           r_phase_cable_conductor + semiconductor_thickness,
           r_phase_cable_conductor + semiconductor_thickness + phase_cable_insulation_thickness,
           r_phase_cable_conductor + semiconductor_thickness + phase_cable_insulation_thickness + lead_sheath_thickness,
           r_phase_cable_outer};


// Create disks automatically
For i In {0:2}  // 3 wires (0, 1, 2)
    For j In {0:4}  // 5 layers (0, 1, 2, 3, 4)
        disk_id = (i+1)*10 + (j+1);  // 11-15, 21-25, 31-35
        Disk(disk_id) = {x_centers[i], y_centers[i], 0., radii[j]};
    EndFor
EndFor


radius = r_phase_cable_outer*(1 + (2/Sqrt(3))); // radius of the circumscribed circle of the triangle formed by the 3 phase conductors
Disk(1) = {0., 0., 0., r_domain_inf};
Disk(2) = {0., 0., 0., r_domain};
Disk(3) = {0., 0., 0., r_cable_outer};
Disk(4) = {0., 0., 0., r_cable_outer-outer_sheath_cable};
Disk(5) = {0., 0., 0., r_cable_outer-outer_sheath_cable-steel_wire_armour_thickness};
Disk(6) = {0., 0., 0., radius};

Rotate {{0, 0, 1}, {0, 0, 0}, Pi/2} { Surface{6}; }  // Rotate 90° counter-clockwise to remove the point on the arc
Rotate {{0, 0, 1}, {x0, y0, 0}, Pi/2} { Surface{15}; }  // Rotate 90° counter-clockwise to remove the point on the arc
Rotate {{0, 0, 1}, {x2, y2, 0}, -Pi/6} { Surface{35}; }  // Rotate 90° counter-clockwise to remove the point on the arc

If(Flag_Defect)
  Rotate {{0, 0, 1}, {x0, y0, 0}, Pi/2} { Surface{14}; }
  Rotate {{0, 0, 1}, {x0, y0, 0}, Pi/2} { Surface{13}; }
  Rotate {{0, 0, 1}, {0, 0, 0}, -Pi/2} { Surface{4}; }
EndIf

// Main cable
cable_insulator() = BooleanDifference{ Surface{6}; }{ Surface{15, 25, 35}; };
cable_semiconductor() = BooleanDifference{ Surface{5}; }{ Surface{6}; };
cable_armor() = BooleanDifference{ Surface{4}; }{ Surface{5}; };
cable_outer() = BooleanDifference{ Surface{3}; }{ Surface{4}; };

If(Flag_Defect)
  // Rectangle covering the upper half-plane (y >= 0) used to split ground regions
  upper_rect = newreg;
  Rectangle(upper_rect) = {-r_domain_inf, 0, 0, 2*r_domain_inf, r_domain_inf};

  // Ground region (between r_cable_outer and r_domain) split at y=0
  ground_full() = BooleanDifference{ Surface{2}; }{ Surface{3}; };
  ground_upper() = BooleanIntersection{ Surface{ground_full()}; }{ Surface{upper_rect}; };
  ground_lower() = BooleanDifference{ Surface{ground_full()}; Delete; }{ Surface{upper_rect}; };

  // Ground_inf region (between r_domain and r_domain_inf) split at y=0
  ground_inf_full() = BooleanDifference{ Surface{1}; }{ Surface{2}; };
  ground_inf_upper() = BooleanIntersection{ Surface{ground_inf_full()}; }{ Surface{upper_rect}; };
  ground_inf_lower() = BooleanDifference{ Surface{ground_inf_full()}; Delete; }{ Surface{upper_rect}; Delete; };
Else
  ground() = BooleanDifference{ Surface{2}; }{ Surface{3}; };
  ground_inf() = BooleanDifference{ Surface{1}; }{ Surface{2}; };
EndIf

// Create layers for all three phases using loop
For i In {1:3}
    conductor~{i}() = {i*10 + 1};
    semiconductor~{i}() = BooleanDifference{ Surface{i*10 + 2}; }{ Surface{i*10 + 1}; };
    insulation~{i}() = BooleanDifference{ Surface{i*10 + 3}; }{ Surface{i*10 + 2}; };
    lead_sheath~{i}() = BooleanDifference{ Surface{i*10 + 4}; }{ Surface{i*10 + 3}; };
    hdpe_sheath~{i}() = BooleanDifference{ Surface{i*10 + 5}; }{ Surface{i*10 + 4}; };
EndFor

If(Flag_Defect)
  // ==========================================================================
  // Defect: elliptical cut breaching cable_outer, cable_armor, and ~half of cable_semiconductor
  // ==========================================================================
  defect_a = 50*mm;  // horizontal semi-axis

  // Bottom of the armor (at x=0): y = r_cable_outer - outer_sheath_cable - steel_wire_armour_thickness
  // Bottom of cable_semiconductor (at x=0): y = radius (circumscribed circle around the 3 phases)
  // Target: midpoint between those two → halfway through cable_semiconductor
  r_armor_inner = r_cable_outer - outer_sheath_cable - steel_wire_armour_thickness;
  r_semi_inner  = r_phase_cable_outer * (1 + (2/Sqrt(3)));  // = radius variable
  defect_bottom = (r_armor_inner + r_semi_inner) / 2;
  defect_depth_total = r_cable_outer - defect_bottom;

  // Full ellipse centered on the outer cable surface at the top.
  defect_ell_full = newreg;
  If (defect_depth_total >= defect_a)
    Disk(defect_ell_full) = {0, r_cable_outer, 0, defect_depth_total, defect_a};
    Rotate {{0, 0, 1}, {0, r_cable_outer, 0}, Pi/2} { Surface{defect_ell_full}; }
  Else
    Disk(defect_ell_full) = {0, r_cable_outer, 0, defect_a, defect_depth_total};
  EndIf

  // Subtract from every layer the defect crosses
  cable_outer()         = BooleanDifference{ Surface{cable_outer()};         Delete; }{ Surface{defect_ell_full}; };
  cable_armor()         = BooleanDifference{ Surface{cable_armor()};         Delete; }{ Surface{defect_ell_full}; };
  cable_semiconductor() = BooleanDifference{ Surface{cable_semiconductor()}; Delete; }{ Surface{defect_ell_full}; };

  // Clip the ellipse to the interior of the cable (Disk 3 = r_cable_outer circle).
  defect() = BooleanIntersection{ Surface{defect_ell_full}; Delete; }{ Surface{3}; };
  all_frags() = BooleanFragments{ Surface{:}; Delete; }{};

  // Re-identify the defect surfaces after BooleanFragments.
  non_defect_tags() = {conductor~{1}(), conductor~{2}(), conductor~{3}(),
                       semiconductor~{1}(), semiconductor~{2}(), semiconductor~{3}(),
                       insulation~{1}(), insulation~{2}(), insulation~{3}(),
                       lead_sheath~{1}(), lead_sheath~{2}(), lead_sheath~{3}(),
                       hdpe_sheath~{1}(), hdpe_sheath~{2}(), hdpe_sheath~{3}(),
                       cable_insulator(), cable_semiconductor(), cable_armor(), cable_outer(),
                       ground_upper(), ground_lower(), ground_inf_upper(), ground_inf_lower()};
  defect_surfaces() = {};
  For i In {0:#all_frags[]-1}
    tag = all_frags(i);
    is_non_defect = 0;
    For j In {0:#non_defect_tags[]-1}
      If (non_defect_tags(j) == tag)
        is_non_defect = 1;
      EndIf
    EndFor
    If (!is_non_defect)
      defect_surfaces() += {tag};
    EndIf
  EndFor
  Compound Surface{defect_surfaces()};
Else
  // Remove intersecting surfaces and create new ones from the fragments
  BooleanFragments{Surface{:}; Delete;}{}
EndIf

// Physical surfaces for all three phases
For i In {1:3}
    Physical Surface(Sprintf("conductor_%g", i), i*10 + 1) = conductor~{i}();
    Physical Surface(Sprintf("semiconductor_%g", i), i*10 + 2) = semiconductor~{i}();
    Physical Surface(Sprintf("insulation_%g", i), i*10 + 3) = insulation~{i}();
    Physical Surface(Sprintf("lead_sheath_%g", i), i*10 + 4) = lead_sheath~{i}();
    Physical Surface(Sprintf("hdpe_sheath_%g", i), i*10 + 5) = hdpe_sheath~{i}();
EndFor

Physical Surface("cable_insulator_inside", 1) = cable_insulator(3);
Physical Surface("cable_insulator_around", 2) = {cable_insulator(0), cable_insulator(1), cable_insulator(2)};
Physical Surface("cable_semiconductor", 3) = cable_semiconductor();
Physical Surface("cable_armor", 4) = cable_armor();
Physical Surface("cable_outer", 5) = cable_outer();

If(Flag_Defect)
  Physical Surface("defect", 999) = defect_surfaces();
  Physical Surface("ground", 6) = {ground_upper(), ground_lower()};
  Physical Surface("ground_inf", 7) = {ground_inf_upper(), ground_inf_lower()};
  Physical Surface("ground_upper", 61) = ground_upper();
  Physical Surface("ground_lower", 60) = ground_lower();
  Physical Surface("ground_inf_upper", 71) = ground_inf_upper();
  Physical Surface("ground_inf_lower", 70) = ground_inf_lower();
Else
  Physical Surface("ground", 6) = ground();
  Physical Surface("ground_inf", 7) = ground_inf();
EndIf

For i In {1:3}
    bnd_insulation_full~{i} = Boundary{Surface{insulation~{i}()};};
    bnd_semiconductor~{i} = bnd_insulation_full~{i}(1);
    bnd_insulation~{i} = bnd_insulation_full~{i}(0);
    bnd_conductor~{i} = Boundary{Surface{conductor~{i}()};};
    bnd_lead_sheath_full~{i} = Boundary{Surface{lead_sheath~{i}()};};
    bnd_lead_sheath~{i} = bnd_lead_sheath_full~{i}(0);  // lead-hdpe interface
    bnd_hdpe_sheath_full~{i} = Boundary{Surface{hdpe_sheath~{i}()};};
    bnd_hdpe_sheath~{i} = bnd_hdpe_sheath_full~{i}(0);  // outer hdpe boundary
    Physical Line(Sprintf("bnd_conductor_%g", i), i*100+1) = {bnd_conductor~{i}};
    Physical Line(Sprintf("bnd_semiconductor_%g", i), i*100+2) = {bnd_semiconductor~{i}};
    Physical Line(Sprintf("bnd_insulation_%g", i), i*100+3) = {bnd_insulation~{i}};
    Physical Line(Sprintf("bnd_lead_sheath_%g", i), i*100+4) = {bnd_lead_sheath~{i}};
    Physical Line(Sprintf("bnd_hdpe_sheath_%g", i), i*100+5) = {bnd_hdpe_sheath~{i}};
EndFor

For i In {1:3}
    bnd_cable_insulator~{i}[] = Boundary{Surface{cable_insulator(i-1)};};
    Physical Line(Sprintf("bnd_cable_insulator_%g", i), i*1000+1) = bnd_cable_insulator~{i}();
EndFor
bnd_cable_insulator_inside[] = Boundary{Surface{cable_insulator(3)};};
Physical Line("bnd_cable_insulator_inside", 1000) = bnd_cable_insulator_inside();

If(Flag_Defect)
  bnd_ground_inf[] = Boundary{Surface{ground_inf_upper(), ground_inf_lower()};};
  bnd_ground[]     = Boundary{Surface{ground_upper(),     ground_lower()    };};
  // The r_domain arcs appear in both arrays (inner of ground_inf = outer of ground). Separate them.
  outer_ground_arcs[]     = {};  // r_domain arcs (outer boundary of ground)
  inner_ground_arcs[]     = {};  // r_cable_outer arcs (inner boundary of ground)
  outer_ground_inf_arcs[] = {};  // r_domain_inf arcs (outer boundary of ground_inf)
  For i In {0:#bnd_ground[]-1}
    found = 0;
    For j In {0:#bnd_ground_inf[]-1}
      If (Fabs(bnd_ground(i)) == Fabs(bnd_ground_inf(j)))
        found = 1;
      EndIf
    EndFor
    If (found)
      outer_ground_arcs[] += {bnd_ground(i)};
    Else
      inner_ground_arcs[] += {bnd_ground(i)};
    EndIf
  EndFor
  For i In {0:#bnd_ground_inf[]-1}
    found = 0;
    For j In {0:#outer_ground_arcs[]-1}
      If (Fabs(bnd_ground_inf(i)) == Fabs(outer_ground_arcs(j)))
        found = 1;
      EndIf
    EndFor
    If (found == 0)
      outer_ground_inf_arcs[] += {bnd_ground_inf(i)};
    EndIf
  EndFor
  Physical Line("bnd_ground_inf", 1011) = outer_ground_inf_arcs();
  Physical Line("bnd_domain",     1012) = outer_ground_arcs();
  Physical Line("bnd_outer_cable",1013) = inner_ground_arcs();
Else
  bnd_ground_inf[] = Boundary{Surface{ground_inf()};};
  Physical Line("bnd_ground_inf", 1011) = {bnd_ground_inf(0)};
  bnd_ground[] = Boundary{Surface{ground()};};
  Physical Line("bnd_domain", 1012) = {bnd_ground(0)};
  Physical Line("bnd_outer_cable", 1013) = {bnd_ground(1)};
EndIf

bnd_cable_armor[] = Boundary{Surface{cable_armor()};};
If(Flag_Defect)
  Physical Line("bnd_cable_armor_outer", 1014) = {bnd_cable_armor(0), bnd_cable_armor(5)};
  Physical Line("bnd_cable_armor_inner", 1016) = {bnd_cable_armor(2), bnd_cable_armor(3)};
Else
  Physical Line("bnd_cable_armor_outer", 1014) = {bnd_cable_armor(0)};
  Physical Line("bnd_cable_armor_inner", 1015) = {bnd_cable_armor(1)};
EndIf

bnd_cable_semiconductor[] = Boundary{Surface{cable_semiconductor()};};

// ==========================================================================
// Mesh size
// ==========================================================================

Printf("Mesh size (ms) = %g", ms);

MeshSize {PointsOf{Line{bnd_cable_semiconductor(1), bnd_cable_semiconductor(2), bnd_cable_semiconductor(3)};}} = ms/50;

If(Flag_Defect)
  bnd_defect[] = Boundary{Surface{defect_surfaces()};};
  MeshSize {PointsOf{Line{bnd_defect(0), bnd_defect(2), bnd_defect(4),bnd_defect(6), bnd_defect(8)};}} = ms/2;
  MeshSize {PointsOf{Line{bnd_cable_armor(2), bnd_cable_armor(3)};}} = ms/500; // inner armor boundary
  MeshSize {PointsOf{Line{bnd_cable_armor(0), bnd_cable_armor(5)};}} = ms/150; // outer armor boundary
  MeshSize {PointsOf{Line{inner_ground_arcs()};}}     = ms/100;
  MeshSize {PointsOf{Line{outer_ground_arcs()};}}     = ms/(80*scale_mesh_ground);
  MeshSize {PointsOf{Line{outer_ground_inf_arcs()};}} = ms/(50*scale_mesh_ground);
Else
  MeshSize {PointsOf{Line{bnd_cable_armor(1)};}} = ms/150; // inner armor boundary
  MeshSize {PointsOf{Line{bnd_cable_armor(0)};}} = ms/225; // outer armor boundary
  MeshSize {PointsOf{Line{bnd_ground(1)};}} = ms/100;
  MeshSize {PointsOf{Line{bnd_ground(0)};}} = ms/(80*scale_mesh_ground);
  MeshSize {PointsOf{Line{bnd_ground_inf(0)};}} = ms/(50*scale_mesh_ground);
EndIf

For i In {1:3}
    MeshSize {PointsOf{Line{bnd_conductor~{i}};}} = ms/400;
    MeshSize {PointsOf{Line{bnd_semiconductor~{i}};}} = ms/400;
    MeshSize {PointsOf{Line{bnd_insulation~{i}};}} = ms/200;
    MeshSize {PointsOf{Line{bnd_lead_sheath~{i}};}} = ms/300;
    MeshSize {PointsOf{Line{bnd_hdpe_sheath~{i}};}} = ms/100;
EndFor

// Apply Transfinite
For i In {1:3}
    For j In {0:#bnd_cable_insulator~{i}()-1}
        If (Flag_Defect && ((i == 3 && j == 0) || (i == 1 && j == 1)))
            MeshSize {PointsOf{Line{bnd_cable_insulator~{i}(j)};}} = ms/700;
        Else
            Transfinite Curve {bnd_cable_insulator~{i}(j)} = 50/ms Using Bump 0.05;
        EndIf
    EndFor
EndFor
Transfinite Curve {bnd_cable_insulator_inside()} = 35/ms Using Bump 0.05;

// ==========================================================================
// Colors for visual verification
// ==========================================================================
Color Red     { Physical Surface{11, 21, 31}; }  // conductors
Color Orange  { Physical Surface{12, 22, 32}; }  // semiconductors (phase)
Color Blue    { Physical Surface{13, 23, 33}; }  // insulations (phase)
Color DarkCyan    { Physical Surface{14, 24, 34}; }  // lead sheaths
Color DarkGreen   { Physical Surface{15, 25, 35}; }  // HDPE sheaths
Color DarkRed   { Physical Surface{1, 2}; }         // cable insulator (inside + around)
Color Purple  { Physical Surface{3}; }            // cable semiconductor
Color {150,75,0} { Physical Surface{4}; }         // cable armor (brown)
Color Magenta { Physical Surface{5}; }            // cable outer sheath
Color Gray    { Physical Surface{6}; }            // ground

If(Flag_Defect)
  Color Cyan    { Physical Surface{999}; }          // defect (seawater)
  Color Gray      { Physical Surface{60, 61}; }     // ground upper/lower
  Color LightGray { Physical Surface{7, 70, 71}; }  // ground_inf
EndIf

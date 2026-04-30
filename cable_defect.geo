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

space = 1*mm; // space between the three phase conductors

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
Rotate {{0, 0, 1}, {x0, y0, 0}, Pi/2} { Surface{14}; }  // Rotate 90° counter-clockwise to remove the point on the arc
Rotate {{0, 0, 1}, {x0, y0, 0}, Pi/2} { Surface{13}; }  // Rotate 90° counter-clockwise to remove the point on the arc
Rotate {{0, 0, 1}, {x2, y2, 0}, -Pi/6} { Surface{35}; }  // Rotate 90° counter-clockwise to remove the point on the arc

Rotate {{0, 0, 1}, {0, 0, 0}, -Pi/2} { Surface{4}; }  // Rotate 90° counter-clockwise to remove the point on the arc

// Main cable
cable_insulator() = BooleanDifference{ Surface{6}; }{ Surface{15, 25, 35}; };
cable_semiconductor() = BooleanDifference{ Surface{5}; }{ Surface{6}; };
cable_armor() = BooleanDifference{ Surface{4}; }{ Surface{5}; };
cable_outer() = BooleanDifference{ Surface{3}; }{ Surface{4}; };

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

// Create layers for all three phases using loop
For i In {1:3}
    conductor~{i}() = {i*10 + 1};
    semiconductor~{i}() = BooleanDifference{ Surface{i*10 + 2}; }{ Surface{i*10 + 1}; };
    insulation~{i}() = BooleanDifference{ Surface{i*10 + 3}; }{ Surface{i*10 + 2}; };
    lead_sheath~{i}() = BooleanDifference{ Surface{i*10 + 4}; }{ Surface{i*10 + 3}; };
    hdpe_sheath~{i}() = BooleanDifference{ Surface{i*10 + 5}; }{ Surface{i*10 + 4}; };
EndFor

// ==========================================================================
// Defect: vertical elliptical cut from the outer cable surface into phase 1 insulation
// Penetrates: cable_outer → cable_armor → cable_semiconductor → cable_insulator
//             → hdpe_sheath_1 → lead_sheath_1 → 1/4 through insulation_1
// ==========================================================================
defect_a = 50*mm;  // horizontal semi-axis (half-width of cut)
// Vertical semi-axis: from outer surface down to 1/4 through phase 1 insulation
// At the top (x=0): phase 1 insulation outer boundary is at y = y0 + r_phase_cable_with_insulation
defect_depth_total = r_cable_outer
                   - (y0 + r_phase_cable_outer-(hdpe_sheath_thickness/2));  // depth from outer cable surface down to phase 1 insulation;

// Full ellipse centered on the outer cable surface at the top.
// OpenCASCADE requires rx >= ry (major axis first).
defect_ell_full = newreg;
If (defect_depth_total >= defect_a)
  // Tall narrow ellipse: major axis is the depth → swap and rotate 90° to make it vertical
  Disk(defect_ell_full) = {0, r_cable_outer, 0, defect_depth_total, defect_a};
  Rotate {{0, 0, 1}, {0, r_cable_outer, 0}, Pi/2} { Surface{defect_ell_full}; }
Else
  // Wide flat ellipse: major axis is already the horizontal width → no rotation needed
  Disk(defect_ell_full) = {0, r_cable_outer, 0, defect_a, defect_depth_total};
EndIf

// Subtract from every layer the defect crosses
cable_outer()         = BooleanDifference{ Surface{cable_outer()};         Delete; }{ Surface{defect_ell_full}; };
cable_armor()         = BooleanDifference{ Surface{cable_armor()};         Delete; }{ Surface{defect_ell_full}; };
cable_semiconductor() = BooleanDifference{ Surface{cable_semiconductor()}; Delete; }{ Surface{defect_ell_full}; };
cable_insulator()     = BooleanDifference{ Surface{cable_insulator()};     Delete; }{ Surface{defect_ell_full}; };
hdpe_sheath~{1}()     = BooleanDifference{ Surface{hdpe_sheath~{1}()};     Delete; }{ Surface{defect_ell_full}; };
lead_sheath~{1}()     = BooleanDifference{ Surface{lead_sheath~{1}()};     Delete; }{ Surface{defect_ell_full}; };
insulation~{1}()      = BooleanDifference{ Surface{insulation~{1}()};      Delete; }{ Surface{defect_ell_full}; };

// Clip the ellipse to the interior of the cable (Disk 3 = r_cable_outer circle).
// This keeps only the part inside the cable and discards the upper half that
// would otherwise overlap with the ground region.
defect() = BooleanIntersection{ Surface{defect_ell_full}; Delete; }{ Surface{3}; };
all_frags() = BooleanFragments{ Surface{:}; Delete; }{};
// After BooleanFragments, the defect() tags are no longer valid.
// Re-identify the defect surfaces: they are all surfaces that do NOT belong
// to any of the named non-defect groups.
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
// Mesh defect fragments as one uniform region, ignoring internal boundaries.
Compound Surface{defect_surfaces()};
Physical Surface("defect", 999) = defect_surfaces();

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
Physical Surface("ground", 6) = {ground_upper(), ground_lower()};        // combined (for .pro compatibility)
Physical Surface("ground_inf", 7) = {ground_inf_upper(), ground_inf_lower()};
Physical Surface("ground_upper", 61) = ground_upper();
Physical Surface("ground_lower", 60) = ground_lower();
Physical Surface("ground_inf_upper", 71) = ground_inf_upper();
Physical Surface("ground_inf_lower", 70) = ground_inf_lower();

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

bnd_ground_inf[] = Boundary{Surface{ground_inf_upper(), ground_inf_lower()};};
bnd_ground[]     = Boundary{Surface{ground_upper(),     ground_lower()    };};
// After the y=0 split each circle becomes 2 arcs, so bnd_ground has 4 curves and
// bnd_ground_inf has 4 curves.  The r_domain arcs appear in BOTH arrays (inner of
// ground_inf = outer of ground).  Separate them by that shared membership.
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

bnd_cable_armor[] = Boundary{Surface{cable_armor()};};
Physical Line("bnd_cable_armor_outer", 1014) = {bnd_cable_armor(0), bnd_cable_armor(5)};
Physical Line("bnd_cable_armor_inner", 1016) = {bnd_cable_armor(2), bnd_cable_armor(3)};
bnd_cable_semiconductor[] = Boundary{Surface{cable_semiconductor()};};

// ==========================================================================
// Mesh size
// ==========================================================================


// DefineConstant[ ms = {r_cable_outer, Name "Mesh size", Visible 1} ];
// ms = DefineNumber[1, Min 1e-3, Max 3, Step 1e-3, Name "Mesh size"];
DefineConstant[
  ms = {1, Min 0.01, Max 3, Name "Mesh size", Visible 1}
];
Printf("Mesh size (ms) = %g", ms);

MeshSize {PointsOf{Line{bnd_cable_semiconductor(1), bnd_cable_semiconductor(2), bnd_cable_semiconductor(3)};}} = ms/50;
MeshSize {PointsOf{Line{bnd_cable_armor(2), bnd_cable_armor(3)};}} = ms/225; // inner armor boundary
MeshSize {PointsOf{Line{bnd_cable_armor(0), bnd_cable_armor(5)};}} = ms/150; // outer armor boundary
MeshSize {PointsOf{Line{inner_ground_arcs()};}}     = ms/100; // r_cable_outer arcs
MeshSize {PointsOf{Line{outer_ground_arcs()};}}     = ms/80;  // r_domain arcs
MeshSize {PointsOf{Line{outer_ground_inf_arcs()};}} = ms/50;  // r_domain_inf arcs

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
        If ((i == 3 && j == 0) || (i == 1 && j == 1))
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
Color Cyan    { Physical Surface{200, 201, 202, 203, 204, 205, 206, 207}; } // defect (seawater)
Color Gray      { Physical Surface{6, 8, 9}; }      // ground
Color LightGray { Physical Surface{7, 10, 11}; }    // ground_inf

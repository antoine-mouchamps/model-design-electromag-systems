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

// Main cable
cable_insulator() = BooleanDifference{ Surface{6}; }{ Surface{15, 25, 35}; };
cable_semiconductor() = BooleanDifference{ Surface{5}; }{ Surface{6}; };
cable_armor() = BooleanDifference{ Surface{4}; }{ Surface{5}; };
cable_outer() = BooleanDifference{ Surface{3}; }{ Surface{4}; };
ground() = BooleanDifference{ Surface{2}; }{ Surface{3}; };
ground_inf() = BooleanDifference{ Surface{1}; }{ Surface{2}; };

// Create layers for all three phases using loop
For i In {1:3}
    conductor~{i}() = {i*10 + 1};
    semiconductor~{i}() = BooleanDifference{ Surface{i*10 + 2}; }{ Surface{i*10 + 1}; };
    insulation~{i}() = BooleanDifference{ Surface{i*10 + 3}; }{ Surface{i*10 + 2}; };
    lead_sheath~{i}() = BooleanDifference{ Surface{i*10 + 4}; }{ Surface{i*10 + 3}; };
    hdpe_sheath~{i}() = BooleanDifference{ Surface{i*10 + 5}; }{ Surface{i*10 + 4}; };
EndFor

// Remove intersecting surfaces and create new ones from the fragments
BooleanFragments{Surface{:}; Delete;}{}

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
Physical Surface("ground", 6) = ground();
Physical Surface("ground_inf", 7) = ground_inf();

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

bnd_ground_inf[] = Boundary{Surface{ground_inf()};};
Physical Line("bnd_ground_inf", 1011) = {bnd_ground_inf(0)};

bnd_ground[] = Boundary{Surface{ground()};};
Physical Line("bnd_domain", 1012) = {bnd_ground(0)};
Physical Line("bnd_outer_cable", 1013) = {bnd_ground(1)};

bnd_cable_armor[] = Boundary{Surface{cable_armor()};};
Physical Line("bnd_cable_armor_outer", 1014) = {bnd_cable_armor(0)};
Physical Line("bnd_cable_armor_inner", 1015) = {bnd_cable_armor(1)};

bnd_cable_semiconductor[] = Boundary{Surface{cable_semiconductor()};};
// Physical Line("bnd_cable_semiconductor_inner", 1015) = {bnd_cable_semiconductor(1), bnd_cable_semiconductor(2), bnd_cable_semiconductor(3)};

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
MeshSize {PointsOf{Line{bnd_cable_armor(1)};}} = ms/225; // inner armor boundary
MeshSize {PointsOf{Line{bnd_cable_armor(0)};}} = ms/150; // outer armor boundary
MeshSize {PointsOf{Line{bnd_ground(1)};}} = ms/100;
MeshSize {PointsOf{Line{bnd_ground(0)};}} = ms/(80*scale_mesh_ground);
MeshSize {PointsOf{Line{bnd_ground_inf(0)};}} = ms/(50*scale_mesh_ground);

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
        Transfinite Curve {bnd_cable_insulator~{i}(j)} = 50/ms Using Bump 0.05;
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

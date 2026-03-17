//=================================================
// Geometrical data
//=================================================

mm = 1e-3;

r_phase_cable_conductor = 29.8/2*mm; // diameter of conductor
phase_cable_insulation_thickness = 15*mm; // thickness of insulation
r_phase_cable_with_insulation = 62.6/2*mm; // diameter of phase conductor with insulation
semiconductor_thickness = r_phase_cable_with_insulation - r_phase_cable_conductor - phase_cable_insulation_thickness; // thickness of semiconductor layer
lead_sheath_thickness = 2.4*mm; // thickness of lead sheath
inner_sheath_thickness = 2.4*mm; // thickness of inner sheath
r_phase_cable_outer = r_phase_cable_with_insulation + lead_sheath_thickness + inner_sheath_thickness; // diameter of phase conductor with insulation and sheath

steel_wire_armour_thickness  = 4*mm;  // thickness of Steel pipe

r_cable_outer = 185/2*mm; // cable outer diameter 
r_domain = 5*r_cable_outer; // electromagnetic analysis

// AND WHY NOT INVESTIGATE THE OPTIC FIBER ALSO ????? WOULD IT BE PERTINENT ?????????????

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
           r_phase_cable_conductor + phase_cable_insulation_thickness,
           r_phase_cable_outer};

// Create disks automatically
For i In {0:2}  // 3 wires (0, 1, 2)
    For j In {0:3}  // 4 layers (0, 1, 2, 3)
        disk_id = (i+1)*10 + (j+1);  // 11-14, 21-24, 31-34
        Disk(disk_id) = {x_centers[i], y_centers[i], 0., radii[j]};
    EndFor
EndFor


radius = r_phase_cable_outer*(1 + (2/Sqrt(3))); // radius of the circumscribed circle of the triangle formed by the 3 phase conductors
Disk(2) = {0., 0., 0., r_cable_outer};
Disk(3) = {0., 0., 0., radius};
Disk(4) = {0., 0., 0., r_cable_outer-7*mm};

Rotate {{0, 0, 1}, {0, 0, 0}, Pi/2} { Surface{3}; }  // Rotate 90° counter-clockwise to remove the point on the arc
Rotate {{0, 0, 1}, {x0, y0, 0}, Pi/2} { Surface{14}; }  // Rotate 90° counter-clockwise to remove the point on the arc
Rotate {{0, 0, 1}, {x2, y2, 0}, -Pi/6} { Surface{34}; }  // Rotate 90° counter-clockwise to remove the point on the arc

// boundary computational domain
Disk(5) = {0., 0., 0., r_domain};

// Main cable
cable_insulator() = BooleanDifference{ Surface{3}; }{ Surface{14, 24, 34}; };
cable_armor() = BooleanDifference{ Surface{4}; }{ Surface{3}; };
cable_outer() = BooleanDifference{ Surface{2}; }{ Surface{4}; };
ground() = BooleanDifference{ Surface{5}; }{ Surface{2}; };

// Create layers for all three phases using loop
For i In {1:3}
    conductor~{i}() = {i*10 + 1};
    semiconductor~{i}() = BooleanDifference{ Surface{i*10 + 2}; }{ Surface{i*10 + 1}; };
    insulation~{i}() = BooleanDifference{ Surface{i*10 + 3}; }{ Surface{i*10 + 2}; };
    sheath~{i}() = BooleanDifference{ Surface{i*10 + 4}; }{ Surface{i*10 + 3}; };
EndFor

// Remove intersecting surfaces and create new ones from the fragments
BooleanFragments{Surface{:}; Delete;}{}

// Physical surfaces for all three phases
For i In {1:3}
    Physical Surface(Sprintf("conductor_%g", i), i*10 + 1) = conductor~{i}();
    Physical Surface(Sprintf("semiconductor_%g", i), i*10 + 2) = semiconductor~{i}();
    Physical Surface(Sprintf("insulation_%g", i), i*10 + 3) = insulation~{i}();
    Physical Surface(Sprintf("sheath_%g", i), i*10 + 4) = sheath~{i}();
EndFor

Physical Surface("cable_insulator_inside", 1) = cable_insulator(3);
Physical Surface("cable_insulator_around", 2) = {cable_insulator(0), cable_insulator(1), cable_insulator(2)};
Physical Surface("cable_armor", 3) = cable_armor();
Physical Surface("cable_outer", 4) = cable_outer();
Physical Surface("ground", 5) = ground();

For i In {1:3}
    bnd_insulation_full~{i} = Boundary{Surface{insulation~{i}()};};
    bnd_semiconductor~{i} = bnd_insulation_full~{i}(1);
    bnd_insulation~{i} = bnd_insulation_full~{i}(0);
    bnd_conductor~{i} = Boundary{Surface{conductor~{i}()};};
    Physical Line(Sprintf("bnd_conductor_%g", i), i*100+1) = {bnd_conductor~{i}};
    Physical Line(Sprintf("bnd_semiconductor_%g", i), i*100+2) = {bnd_semiconductor~{i}};
    Physical Line(Sprintf("bnd_insulation_%g", i), i*100+3) = {bnd_insulation~{i}};
EndFor

For i In {1:3}
    bnd_cable_insulator~{i}[] = Boundary{Surface{cable_insulator(i-1)};};
    Physical Line(Sprintf("bnd_cable_insulator_%g", i), i*1000+1) = bnd_cable_insulator~{i}();
EndFor
bnd_cable_insulator_inside[] = Boundary{Surface{cable_insulator(3)};};
Physical Line("bnd_cable_insulator_inside", 1000) = bnd_cable_insulator_inside();

bnd_ground[] = Boundary{Surface{ground()};};
Physical Line("bnd_domain", 1011) = {bnd_ground(0)};
Physical Line("bnd_outer_cable", 1012) = {bnd_ground(1)};

bnd_cable_armor[] = Boundary{Surface{cable_armor()};};
Physical Line("bnd_cable_armor", 1013) = {bnd_cable_armor(0)};
Physical Line("bnd_cable_outer", 1014) = {bnd_cable_armor(1), bnd_cable_armor(2), bnd_cable_armor(3)};

// ==========================================================================
// Mesh size
// ==========================================================================


// DefineConstant[ ms = {r_cable_outer, Name "Mesh size", Visible 1} ];
ms = DefineNumber[0.5, Min 1e-3, Max 1, Step 1e-3, Name "Mesh size"];
Printf("Mesh size (ms) = %g", ms);

MeshSize {PointsOf{Line{bnd_cable_armor(1), bnd_cable_armor(2), bnd_cable_armor(3)};}} = ms/50;
MeshSize {PointsOf{Line{bnd_cable_armor(0)};}} = ms/100;
MeshSize {PointsOf{Line{bnd_ground(1)};}} = ms/100;
MeshSize {PointsOf{Line{bnd_ground(0)};}} = ms/20;

For i In {1:3}
    MeshSize {PointsOf{Line{bnd_conductor~{i}};}} = ms/400;
    MeshSize {PointsOf{Line{bnd_semiconductor~{i}};}} = ms/400;
    MeshSize {PointsOf{Line{bnd_insulation~{i}};}} = ms/200;
EndFor

// Apply Transfinite 
For i In {1:3}
    For j In {0:#bnd_cable_insulator~{i}()-1}
        Transfinite Curve {bnd_cable_insulator~{i}(j)} = 100/ms Using Bump 0.05;
    EndFor
EndFor
Transfinite Curve {bnd_cable_insulator_inside()} = 75/ms Using Bump 0.05;

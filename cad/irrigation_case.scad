// Irrigation controller case (plan: docs/irrigation-case.md). OpenSCAD, parametric.
//
// One wall-mounted box: the KC868-A8 with its screen lid across the top (EVEPS and CPT converters
// standing upright to its right), and under it the incoming-wires bay (left, slide-down cover) and
// the power bay (right, screwed cover). Wires from the A8 run behind it, in channels on the back
// of its base plate, down into the bays. Valve wires come out of the wall into the back of the
// wiring bay; the transformer's wire comes in through a PG7 gland under the power bay.
//
// Axes: x right, y up the wall, z out of the wall (0 = the wall). Sizes in mm.
// Render a part: openscad -D 'part="box"' -o box.stl irrigation_case.scad
// Parts: assembly (preview), box, base, lid, wiring_cover, power_cover, test_inserts, test_base.

part = "assembly";
$fn = 48;

// ── The box ───────────────────────────────────────────────────────────────
W = 208;            // outside width
H = 225;            // outside height
D = 66;             // outside depth (wall to front)
wall = 2.4;         // side walls (6 lines of a 0.4 nozzle)
back = 3;           // back wall (against the wall)
lower_h = 80;       // inside height of the two bays at the bottom
divider = 2.4;      // the shelf between the A8 section and the bays
wiring_w = 125;     // inside width of the wiring bay (12-position strip: 109.5)
lid_t = 2.4;        // screen lid thickness
cover_t = 2.4;      // bay covers

// Heat-set inserts (the user's kit, its size chart: knurls 5.0, pilot collar 4.2, M3, L 4 and 6).
// The hole is about the pilot (4.2), confirmed with the test strip (4.1 / 4.2 / 4.3 / 4.4).
// 6 mm ones where there's depth, 4 mm ones in the base plate's posts.
ins_d = 4.2;
ins_depth = 6.5;        // M3 L6
ins_depth_short = 4.5;  // M3 L4
boss_d = 9;

// ── The KC868-A8 (measured, and the rail-mount model's plate) ────────────
a8_w = 152;         // over what sticks out, left-right
a8_h = 110;         // top-bottom
a8_margin = 1.5;    // from the left wall (tight: the converters need the width on the right)
a8_bottom = 12;     // gap under the board (wires from the green blocks bend into the slot)
// The board's 4 screws, from the plate's left / top (Grundplatte.stl). The plate's straight-corner
// edge (its "top" here, with the two corner holes) is the relay edge; the curved corners are the
// green blocks' edge (the user, 2026-11-02). So relays up: a8_flip = false.
a8_holes = [[13.6, 7.5], [139.1, 7.5], [42.4, 61.8], [68.9, 89.8]];
a8_flip = false;
standoff_d = 8;     // standoffs as in the rail-mount plate: the 2.4 mm clears the solder leads
standoff_h = 2.4;
a8_screw_d = 2.7;   // M3 (pass the A8's holes freely, checked), cutting their thread into the standoffs and plate

// ── The base plate behind the A8 (P6): wire channels on its back ─────────
base_t = 10;
chan_depth = 7;
chan_w = 18;        // the ring channel around the board
slot_w = 8;         // the long slots along the relay edge and the green blocks' edge

// ── Converters, standing upright right of the A8 ─────────────────────────
eveps = [46.25, 70, 22];   // w (measured), h (seller), height (seller doesn't say; room to spare)
cpt = [46.6, 58, 14];      // w (measured), h over the ears (estimate), height
// Converter mounting: a nut rail under each one (slot on top, M3 nuts slide in the channel below,
// held from turning), so the screws land wherever the ears are. M3 x 10 + washer through each ear.
rail_w = 12;
rail_h = 6;
nut_w = 6.2;       // M3 nut: 5.5 across flats, 6.35 across corners (so it can't turn)
nut_ch = 2.8;      // channel height (nut 2.4)
rail_top = 2.6;    // plastic over the channel

// ── Screen (Hosyond ESP32-S3 3.5") in the lid ─────────────────────────────
scr_board = [101.5, 54.5];   // seller: 54.5 x 101.5 x 10 mm; 320 x 480 IPS, capacitive
scr_holes = [92, 45];   // corner holes, centre to centre (measured 2026-11-02)
scr_window = [76, 51];  // picture 73.4 x 49.0 (standard 3.5" 320 x 480), centred on the board
scr_post_h = 4.4;       // the glass stands 4.07 mm above the board (5.67 with it, measured); 0.3 air
scr_post_d = 7;
scr_screw_d = 2.7;      // M3 (passes the board's 3 mm holes, checked), cutting its thread into the post
scr_center = [118, 0];  // x of the screen centre (over the A8's right half); y set below

// ── Bays ──────────────────────────────────────────────────────────────────
strip12 = [109.5, 16.8, 14];   // length, depth (wire in to out), height
strip5 = [46, 16.8, 14];
wago = [18.7, 18.6, 8.3];
wall_hole = [50, 35];          // valve wires out of the wall, into the back of the wiring bay
pg7_d = 12.5;                  // transformer wire, under the power bay

// Keyholes for #8 screws in the back: 2 high (behind the base plate: hang the box, then fit the
// plate, which has clearance holes over them), 2 low (in the bays).
keyholes = [[20, H - 25], [W - 20, H - 25], [20, 30], [W - 20, 30]];

// The base plate's 4 screws (base plate coordinates, from its bottom-left): clear of the channels,
// slots and the A8's standoffs. Bosses on the box's back fit into recesses in the plate's back;
// the heads sink into the plate's front (under the A8 there's only the 2.4 mm standoff gap).
base_screws = [[28, 28], [130, 26], [28, 105], [125, 105]];
base_boss_h = 4;   // an L4 insert goes 0.5 mm on into the back wall; M3 x 8 from the plate's front

// ── Derived ───────────────────────────────────────────────────────────────
up_y0 = wall + lower_h + divider;          // floor of the A8 section
up_h = H - wall - up_y0;                   // inside height of the A8 section
in_w = W - 2 * wall;
a8_x0 = wall + a8_margin;
a8_y0 = up_y0 + a8_bottom;
conv_x0 = a8_x0 + a8_w + 1.5;              // the converter strip
conv_w = W - wall - conv_x0;
power_x0 = wall + wiring_w + divider;
power_w = W - wall - power_x0;
scr_y = a8_y0 + a8_h / 2 + 8;

echo(str("box ", W, " x ", H, " x ", D, "; A8 section inside ", in_w, " x ", up_h,
         "; converter strip ", conv_w, " wide; wiring bay ", wiring_w, " x ", lower_h,
         "; power bay ", power_w, " x ", lower_h));
assert(conv_w >= max(eveps[0], cpt[0]) + 1, "the converter strip is narrower than the converters");
assert(up_h >= a8_bottom + a8_h + 10, "the A8 section is too short");

module rcube(s, r = 2) {  // a box with rounded vertical edges
    hull() for (x = [r, s[0] - r], y = [r, s[1] - r]) translate([x, y, 0]) cylinder(r = r, h = s[2]);
}
module insert_boss(h) {   // a post for a heat-set insert, open at the top
    difference() { cylinder(d = boss_d, h = h); translate([0, 0, h - ins_depth]) cylinder(d = ins_d, h = ins_depth + 1); }
}

// ── P1: the box ───────────────────────────────────────────────────────────
module box() {
    difference() {
        union() {
            difference() {
                rcube([W, H, D], 4);
                translate([wall, wall, back]) cube([in_w, H - 2 * wall, D]);   // open front
            }
            // the shelf between the A8 section and the bays (the base plate sits on it)
            translate([wall, wall + lower_h, back]) difference() {
                cube([in_w, divider, D - back - lid_t]);
                // where the channels pass down into the bays (behind the base plate)
                translate([4, -1, -1]) cube([chan_w, divider + 2, base_t - back + 1]);
                translate([power_x0 - wall + 4, -1, -1]) cube([chan_w, divider + 2, base_t - back + 1]);
            }
            // the wall between the two bays
            translate([wall + wiring_w, wall, back]) cube([divider, lower_h, D - back]);
            // the lid rests on a ledge all round the A8 section
            ledge();
            // inserts: the lid's 2 screws (from the wiring bay, up into the lid's bottom flange) and
            // the power cover's 2 screws (from underneath)
            for (x = [power_x0 + 15, W - wall - 15])
                translate([x, wall, D - cover_t - 3]) rotate([-90, 0, 0]) cylinder(d = boss_d, h = 6);
            // the wiring cover slides down in grooves: rails on the left wall and the bay divider
            for (x = [wall, wall + wiring_w - 1.2])
                translate([x, wall, D - cover_t - 2.4]) cube([1.2, lower_h, 1.2]);
            // the base plate's 4 bosses (inserts at the top)
            for (p = base_screws) translate([wall + 0.3 + p[0], up_y0 + 0.3 + p[1], back]) cylinder(d = boss_d, h = base_boss_h);
            // pockets: the terminal strips (the converters are on rails on the base plate)
            bay_pockets();
        }
        // the base plate bosses' insert holes, on into the back wall (5.5 deep from the boss top)
        for (p = base_screws) translate([wall + 0.3 + p[0], up_y0 + 0.3 + p[1], back + base_boss_h - ins_depth_short]) cylinder(d = ins_d, h = ins_depth_short + 0.1);
        // the wall hole: valve wires into the back of the wiring bay
        translate([wall + wiring_w / 2 - wall_hole[0] / 2, wall + 8, -1]) rcube([wall_hole[0], wall_hole[1], back + 2], 6);
        // the power cover's 2 inserts, pressed in from under the box (M3 x 8 through the cover's lip)
        for (x = [power_x0 + 15, W - wall - 15])
            translate([x, -0.1, D - cover_t - 3]) rotate([-90, 0, 0]) cylinder(d = ins_d, h = ins_depth + 0.1);
        // the transformer's gland under the power bay
        translate([power_x0 + power_w - 18, -1, back + 22]) rotate([-90, 0, 0]) cylinder(d = pg7_d, h = wall + 2);
        // spare knockouts under the wiring bay (a 0.4 mm skin to punch out)
        for (x = [wall + 25, wall + wiring_w - 25])
            translate([x, 0.4, back + 22]) rotate([-90, 0, 0]) cylinder(d = 18.6, h = wall);
        // vents: slots under the bays, at the bottom of the A8 section's sides, and on top
        for (i = [0 : 7]) translate([wall + 40 + i * 8, -1, back + 34]) cube([3, wall + 2, 16]);
        for (s = [0, 1]) for (i = [0 : 3])
            translate([s ? W - wall - 1 : -1, up_y0 + 6 + i * 8, back + 14]) cube([wall + 2, 3, 30]);
        for (i = [0 : 13]) translate([30 + i * 10, H - wall - 1, back + 14]) cube([3, wall + 2, 30]);
        // keyholes for #8 screws in the back
        for (p = keyholes) translate([p[0], p[1], -1]) keyhole();
        // the lid's 2 hooks go into these slots under the top wall
        for (x = [W / 2 - 50, W / 2 + 50]) translate([x - 8, H - wall - 0.5, D - lid_t - 4]) cube([16, 1.6, 4.2]);
        // screw holes for the lid (through the shelf front, from below)
        for (x = [wall + 30.3, wall + wiring_w - 29.7])
            translate([x, wall + lower_h - 1, D - lid_t - 6]) rotate([-90, 0, 0]) cylinder(d = 3.4, h = divider + 2);
    }
}
module ledge() {   // inside the A8 section, 2.4 mm behind the front: the lid sits on it
    t = 2;
    translate([0, 0, D - lid_t - t]) difference() {
        translate([wall, up_y0, 0]) cube([in_w, up_h, t]);
        translate([wall + 3, up_y0 + 3, -1]) cube([in_w - 6, up_h - 6, t + 2]);
    }
}
module keyhole() {
    cylinder(d = 9.5, h = back + 2);
    translate([-2.25, 0, 0]) cube([4.5, 10, back + 2]);
    translate([0, 10, 0]) cylinder(d = 4.5, h = back + 2);
}
module nut_rail(l) {   // along y; nuts go in at either end
    difference() {
        translate([-rail_w / 2, 0, 0]) cube([rail_w, l, rail_h]);
        translate([-1.7, -1, rail_h - rail_top - 0.1]) cube([3.4, l + 2, rail_top + 1]);          // the slot
        translate([-nut_w / 2, -1, rail_h - rail_top - nut_ch]) cube([nut_w, l + 2, nut_ch]);      // the nut channel
    }
}
// the two rails, in base plate coordinates: EVEPS above, CPT below, along the strip's middle
module converter_rails() {
    cx = conv_x0 - wall - 0.3 + conv_w / 2;
    translate([cx, (H - wall - 4 - eveps[1]) - up_y0 - 0.3 - 1, base_t]) nut_rail(eveps[1] + 2);
    translate([cx, 4 - 0.3 - 1, base_t]) nut_rail(cpt[1] + 2);
}
module bay_pockets() {
    // wiring bay: the 12-strip lies across, its screws to the front, above the wall hole
    sx = wall + (wiring_w - strip12[0]) / 2;
    translate([sx - 1.6, wall + lower_h - strip12[1] - 14, back]) strip_pocket(strip12);
    // power bay: the 5-strip (the 4 Wagos sit loose, held by their wires)
    translate([power_x0 + 4, wall + 8, back]) strip_pocket(strip5);
}
module strip_pocket(s) {   // a shallow tray; the printed clip (P7) holds the strip down with 2 screws
    difference() {
        union() {
            cube([s[0] + 3.2, s[1] + 3.2, 3]);
            for (x = [-6, s[0] + 3.2 + 6]) translate([x, (s[1] + 3.2) / 2, 0]) insert_boss(s[2] + 1);
        }
        translate([1.6, 1.6, 1]) cube([s[0], s[1], 3]);
    }
}

// ── P6: the A8's base plate, wire channels on its back ───────────────────
module base() {
    bw = in_w - 0.6; bh = up_h - 0.6;
    difference() {
        union() {
            cube([bw, bh, base_t]);
            // the 4 standoffs
            for (p = a8_holes) translate(a8_hole_xy(p)) translate([0, 0, base_t]) cylinder(d = standoff_d, h = standoff_h);
            // the converters' nut rails
            converter_rails();
        }
        for (p = a8_holes) translate(a8_hole_xy(p)) translate([0, 0, 2]) cylinder(d = a8_screw_d, h = base_t + standoff_h);
        // the ring channel on the back, round the board
        translate([0, 0, -1]) difference() {
            translate([2, 2, 0]) cube([bw - 4, bh - 4, chan_depth + 1]);
            translate([2 + chan_w, 2 + chan_w, -1]) cube([bw - 4 - 2 * chan_w, bh - 4 - 2 * chan_w, chan_depth + 3]);
        }
        // a cross channel behind the converters, and up to the screen
        translate([conv_x0 - wall - 4, 2, -1]) cube([chan_w, bh - 4, chan_depth + 1]);
        // the channel opens at the bottom edge over the shelf's pass-throughs into the bays
        translate([4 - 0.3, -1, -1]) cube([chan_w, 4, chan_depth + 1]);
        translate([power_x0 - wall + 4 - 0.3, -1, -1]) cube([chan_w, 4, chan_depth + 1]);
        // the long slots through: relay edge (top) and the green blocks' edge (bottom)
        sx = a8_x0 - wall + 6;
        translate([sx, a8_y0 - up_y0 + a8_h + 3, -1]) rcube([a8_w - 12, slot_w, base_t + 2], 3);
        translate([sx, a8_y0 - up_y0 - slot_w - 2, -1]) rcube([a8_w - 12, slot_w, base_t + 2], 3);
        // the box's bosses fit into recesses on the back; M3 screws from the front, heads sunk
        for (p = base_screws) translate([p[0], p[1], 0]) {
            translate([0, 0, -1]) cylinder(d = boss_d + 0.6, h = base_boss_h + 1.3);
            cylinder(d = 3.4, h = base_t + 1);
            translate([0, 0, base_t - 2.6]) cylinder(d = 6.5, h = 4);   // the head sinks in; 3.1 mm clamped
        }
        // clearance for the 2 high keyholes' screw heads (the box is hung before the plate goes in)
        for (p = keyholes) if (p[1] > up_y0) translate([p[0] - wall - 0.3, p[1] - up_y0 - 0.3 + 5, -1]) cylinder(d = 14, h = base_t + 2);
        // the converters' wires through, and the screen cable
        translate([conv_x0 - wall + 2, bh / 2 - 6, -1]) rcube([conv_w - 6, 12, base_t + 2], 3);
        translate([scr_center[0] - wall - 6, scr_y - up_y0 - 40, -1]) rcube([12, 12, base_t + 2], 3);
    }
}
function a8_hole_xy(p) = [a8_x0 - wall + p[0], (a8_y0 - up_y0) + (a8_flip ? p[1] : a8_h - p[1])];

// ── Labels (2nd colour) ────────────────────────────────────────────────────
// Each label is cut 0.6 mm (3 layers) into its part and printed as an inlay in the second
// colour: load the part and its *_labels STL together in OrcaSlicer as one object (parts), and
// give the labels the 2nd filament. The parts print face down, so the colour is only in their
// first (or, for the inside of the wiring cover, last) 3 layers.
label_d = 0.6;
bold = "Liberation Sans:style=Bold";
wire_colours = ["Z1 red", "Z2 blue", "Z3 yellow", "Z4 green", "Z5 black", "COM white"];
strip12_labels = ["Z1", "Z2", "Z3", "Z4", "Z5", "Z6", "Z7", "Z8", "COM", "COM2", "RAIN", "RAIN"];
strip5_labels = ["24V", "0V", "FLOW+", "SIG", "GND"];

module lid_label() {
    translate([18, up_h - 0.6 - 20, lid_t - label_d]) linear_extrude(label_d + 0.01) text("IRRIGATION", size = 9, font = bold);
}
module wiring_cover_label() {
    translate([12, lower_h / 2 + 8, cover_t - label_d]) linear_extrude(label_d + 0.01) text("Z1-Z8  COM  RAIN", size = 7, font = bold);
    // inside: which valve wire is which (read from inside, so mirrored)
    for (i = [0 : len(wire_colours) - 1])
        translate([wiring_w - 0.6 - 14 - (i % 3) * 36, 22 - floor(i / 3) * 9, 0]) mirror([1, 0, 0])
            linear_extrude(label_d + 0.01) text(wire_colours[i], size = 4.5, font = bold);
}
module power_cover_label() {
    translate([8, lower_h / 2 - 4, cover_t - label_d]) linear_extrude(label_d + 0.01) text("POWER", size = 7, font = bold);
}
module clip_labels(s, names) {   // one name beside each position, on the clip's top (upright text)
    pitch = s[0] / len(names);
    tray = s[1] + 3.2;
    for (i = [0 : len(names) - 1])
        translate([1.6 + pitch * (i + 0.5), tray / 2 + 1.2, 2.4 - label_d]) rotate([0, 0, 90])
            // names of 4+ letters are scaled to 13 mm long, so they fit the clip's ~15 mm (FLOW+, COM2, RAIN)
            linear_extrude(label_d + 0.01)
                if (len(names[i]) >= 4) resize([13, 0], auto = true) text(names[i], size = 3, font = bold, valign = "center");
                else text(names[i], size = 3.2, font = bold, valign = "center");
}
module clips_labels() {
    clip_labels(strip12, strip12_labels);
    translate([0, 40, 0]) clip_labels(strip5, strip5_labels);
}

// ── P2: the screen lid ────────────────────────────────────────────────────
module lid() {
    lw = in_w - 0.6; lh = up_h - 0.6;
    sx = scr_center[0] - wall; sy = scr_y - up_y0;
    difference() {
        union() {
            rcube([lw, lh, lid_t], 2);
            // the screen's 4 posts (behind the lid, toward the A8)
            for (dx = [-1, 1], dy = [-1, 1])
                translate([sx + dx * scr_holes[0] / 2, sy + dy * scr_holes[1] / 2, -scr_post_h])
                    cylinder(d = scr_post_d, h = scr_post_h);
            // 2 hooks at the top (into the slots under the box's top wall)
            for (x = [W / 2 - 50, W / 2 + 50]) translate([x - wall - 7.5, lh - 0.1, 0]) cube([15, 1.4, lid_t]);
            // the bottom flange with 2 insert holes (screwed from the wiring bay)
            translate([0, 0, -12]) cube([lw, 2.4, 12]);
            // 2 posts up from the flange, the inserts pressed in from below (M3 x 8 up through the shelf)
            for (x = [30, wiring_w - 30]) translate([x, 0, -6]) rotate([-90, 0, 0]) difference() {
                cylinder(d = boss_d, h = 8);
                translate([0, 0, -1]) cylinder(d = ins_d, h = ins_depth + 1);
            }
        }
        // the screen screws' holes: through the posts and 1 mm into the lid (1.4 mm left in front),
        // so M3 x 5 or x 6 fits (board 1.6 + post 4.4 + 1)
        for (dx = [-1, 1], dy = [-1, 1])
            translate([sx + dx * scr_holes[0] / 2, sy + dy * scr_holes[1] / 2, -scr_post_h - 1]) cylinder(d = scr_screw_d, h = scr_post_h + 2);
        // the window
        translate([sx - scr_window[0] / 2, sy - scr_window[1] / 2, -1]) rcube([scr_window[0], scr_window[1], lid_t + 2], 2);
        // microphone, at the screen's left end
        // (from the front photo: 6.4 mm from the board's left edge, 9.7 mm from its top)
        translate([sx - scr_board[0] / 2 + 6.4, sy + scr_board[1] / 2 - 9.7, -1]) cylinder(d = 2.5, h = lid_t + 2);
        lid_label();   // inlay, 2nd colour
    }
}

// ── P3: wiring cover (slides down), P4: power cover (2 screws underneath) ─
module wiring_cover() {
    difference() {
        union() {
            cube([wiring_w - 0.6, lower_h - 0.3, cover_t]);
            // the grooves ride on the box's rails
            for (x = [0, wiring_w - 0.6 - 2.6]) translate([x, 0, -1.6]) cube([2.6, lower_h - 0.3, 1.6]);
        }
        for (x = [1.3, wiring_w - 0.6 - 2.6 + 0.6]) translate([x - 0.1, -1, -1.7]) cube([1.4, lower_h + 2, 1.4]);
        wiring_cover_label();   // inlays, 2nd colour (outside, and the wire colours inside)
        // a finger notch to slide it
        translate([(wiring_w - 0.6) / 2, 3, cover_t + 2.6]) scale([3, 1, 1]) sphere(d = 8);   // 1.4 mm deep
    }
}
module power_cover() {
    difference() {
        union() {
            cube([power_w - 0.6, lower_h - 0.3, cover_t]);
            translate([0, -wall, -6]) cube([power_w - 0.6, wall, 6 + cover_t]);   // bends under the box
        }
        for (x = [15 - 0.3, power_w - 0.6 - 15 + 0.3]) translate([x, -wall - 1, -3]) rotate([-90, 0, 0]) cylinder(d = 3.4, h = wall + 2);
        power_cover_label();   // inlay, 2nd colour
    }
}

// ── P7: strip clips: cover the strip's upper row (the A8's pre-wired side), 2 screws ─
module strip_clip(s, names) {
    tray = s[1] + 3.2;
    l = s[0] + 3.2 + 12 + 8;          // from boss to boss, plus ears
    difference() {
        union() {
            translate([-10, tray / 2 - 5, 0]) cube([l, 10, 2.4]);            // the screw bar
            translate([-1, tray / 2, 0]) cube([s[0] + 5.2, tray / 2 + 6, 2.4]);  // over the upper row, and 5 mm on (room for the names)
            // a lip down over the upper row's wire side, so the pre-wired leads can't be touched
            translate([-1, tray, -8]) cube([s[0] + 5.2, 1.6, 10.4]);
        }
        for (x = [-6, s[0] + 3.2 + 6]) translate([x, tray / 2, -1]) cylinder(d = 3.4, h = 5);
        clip_labels(s, names);   // inlays, 2nd colour: each terminal's name
    }
}
module clips() {
    strip_clip(strip12, strip12_labels);
    translate([0, 40, 0]) strip_clip(strip5, strip5_labels);
}

// ── Test prints ───────────────────────────────────────────────────────────
module test_inserts() {   // pick the insert hole: melt one into each, keep the snug one
    ds = [4.1, 4.2, 4.3, 4.4];
    difference() {
        cube([len(ds) * 14 + 4, 18, 8]);
        for (i = [0 : len(ds) - 1]) {
            translate([9 + i * 14, 11, 8 - ins_depth]) cylinder(d = ds[i], h = ins_depth + 1);
            translate([4 + i * 14, 2, 8 - 0.6]) linear_extrude(1) text(str(ds[i]), size = 3.5);
        }
    }
}
module test_base() {   // a thin plate with the 4 standoffs: put the real A8 on it before printing the box
    p0 = [a8_x0 - wall, a8_y0 - up_y0];
    difference() {
        union() {
            translate(p0 - [4, 4]) cube([a8_w + 8, a8_h + 8, 1.6]);
            for (p = a8_holes) translate(a8_hole_xy(p)) cylinder(d = standoff_d, h = 1.6 + standoff_h);
        }
        for (p = a8_holes) translate(a8_hole_xy(p)) translate([0, 0, -1]) cylinder(d = a8_screw_d, h = 10);
        // the board's outline, as a groove to line it up with
        translate(concat(p0, [1.0])) difference() { cube([a8_w, a8_h, 1]); translate([1, 1, -1]) cube([a8_w - 2, a8_h - 2, 3]); }
        translate([p0[0] + a8_w / 2 - 30, p0[1] + a8_h / 2, 0.8]) linear_extrude(1) text("RELAYS UP", size = 7);
    }
}

module test_fits() {   // the tight spots, on thin plates: converters, Wagos, strip tray, gland, rail, keyhole
    f = 1.2;   // floor
    // converters: a 50 mm piece of nut rail on a plate (slide 2 nuts in, screw an ear down)
    cube([30, 54, f]);
    translate([15, 2, f]) nut_rail(50);
    // the terminal strip tray: its first 30 mm and the insert post
    translate([0, eveps[1] + 14, 0]) {
        translate([-8, 0, 0]) cube([46, strip12[1] + 7, f]);
        translate([6, 2, f]) intersection() { strip_pocket(strip12); translate([-14, -1, -1]) cube([44, 30, 30]); }
    }
    // PG7 gland hole and the keyhole, in walls as thick as the box's
    translate([54, eveps[1] + 14, 0]) difference() {
        cube([30, 26, wall]);
        translate([15, 13, -1]) cylinder(d = pg7_d, h = wall + 2);
    }
    translate([90, eveps[1] + 14, 0]) difference() {
        cube([24, 30, back]);
        translate([12, 7, 0]) keyhole();
    }
    // the wiring cover's slide: a rail on a wall stub, and a cover piece that rides on it
    translate([120, eveps[1] + 14, 0]) {
        cube([30, 4, 14]);                                        // wall stub, standing
        translate([0, 4, 14 - cover_t - 2.4]) cube([30, 1.2, 1.2]);   // the rail, as in the box
    }
    translate([120, eveps[1] + 24, 0]) difference() {           // a cover piece, printed flat
        union() { cube([30, 20, cover_t]); translate([0, 0, cover_t]) cube([30, 2.6, 1.6]); }
        translate([-1, 1.3 - 0.1, cover_t - 0.1]) cube([32, 1.4, 1.4]);
    }
}

// ── Assembly preview ──────────────────────────────────────────────────────
module assembly(explode = 0) {
    color("WhiteSmoke") box();
    color("LightSteelBlue") translate([wall + 0.3, up_y0 + 0.3, back]) base();
    color("ForestGreen", 0.8) translate([a8_x0, a8_y0, back + base_t + standoff_h]) cube([a8_w, a8_h, 1.6]);
    color("DarkOrange") translate([a8_x0 + 6, a8_y0 + a8_h - 10, back + base_t + standoff_h + 1.6]) cube([a8_w - 12, 10, 14]);
    color("Black") translate([conv_x0 + (conv_w - eveps[0]) / 2, H - wall - 4 - eveps[1], back + base_t + rail_h]) cube(eveps);
    color("Black") translate([conv_x0 + (conv_w - cpt[0]) / 2, up_y0 + 4, back + base_t + rail_h]) cube(cpt);
    color("Gainsboro", 0.9) translate([wall + 0.3, up_y0 + 0.3, D - lid_t + explode]) lid();
    color("Gainsboro") translate([wall + 0.3, wall, D - cover_t + explode]) wiring_cover();
    color("Gainsboro") translate([power_x0 + 0.3, wall, D - cover_t + explode]) power_cover();
}

module open_view() {   // covers off: what's inside
    color("WhiteSmoke") box();
    color("LightSteelBlue") translate([wall + 0.3, up_y0 + 0.3, back]) base();
    color("ForestGreen", 0.8) translate([a8_x0, a8_y0, back + base_t + standoff_h]) cube([a8_w, a8_h, 1.6]);
    color("DarkOrange") translate([a8_x0 + 6, a8_y0 + a8_h - 10, back + base_t + standoff_h + 1.6]) cube([a8_w - 12, 10, 14]);
    color("Black") translate([conv_x0 + (conv_w - eveps[0]) / 2, H - wall - 4 - eveps[1], back + base_t + rail_h]) cube(eveps);
    color("Black") translate([conv_x0 + (conv_w - cpt[0]) / 2, up_y0 + 4, back + base_t + rail_h]) cube(cpt);
    color("White") translate([wall + (wiring_w - strip12[0]) / 2, wall + lower_h - strip12[1] - 14 + 1.6, back + 1]) cube(strip12);
    color("White") translate([power_x0 + 4 + 1.6, wall + 8 + 1.6, back + 1]) cube(strip5);
}
if (part == "assembly") assembly(0);
else if (part == "open") open_view();
else if (part == "exploded") assembly(45);
else if (part == "box") box();
else if (part == "base") base();
else if (part == "lid") lid();
else if (part == "wiring_cover") wiring_cover();
else if (part == "power_cover") power_cover();
else if (part == "test_inserts") test_inserts();
else if (part == "test_base") test_base();
else if (part == "test_fits") test_fits();
else if (part == "clips") clips();
else if (part == "lid_labels") lid_label();
else if (part == "wiring_cover_labels") wiring_cover_label();
else if (part == "power_cover_labels") power_cover_label();
else if (part == "clips_labels") clips_labels();

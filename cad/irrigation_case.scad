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

// Heat-set inserts: the hole from the test strip (3.9 / 4.0 / 4.1 / 4.2), depth for M3 x 5.
ins_d = 4.0;
ins_depth = 5.5;
boss_d = 8;

// ── The KC868-A8 (measured, and the rail-mount model's plate) ────────────
a8_w = 152;         // over what sticks out, left-right
a8_h = 110;         // top-bottom
a8_margin = 3;      // from the left wall
a8_bottom = 12;     // gap under the board (wires from the green blocks bend into the slot)
// The board's 4 screws, from the plate's left / top (Grundplatte.stl). The plate's straight-corner
// edge (its "top" here, with the two corner holes) is the relay edge; the curved corners are the
// green blocks' edge (the user, 2026-11-02). So relays up: a8_flip = false.
a8_holes = [[13.6, 7.5], [139.1, 7.5], [42.4, 61.8], [68.9, 89.8]];
a8_flip = false;
standoff_d = 8;     // standoffs as in the rail-mount plate: the 2.4 mm clears the solder leads
standoff_h = 2.4;
a8_screw_d = 1.7;   // M2 screws (the user's), cutting their thread into the standoffs

// ── The base plate behind the A8 (P6): wire channels on its back ─────────
base_t = 10;
chan_depth = 7;
chan_w = 18;        // the ring channel around the board
slot_w = 8;         // the long slots along the relay edge and the green blocks' edge

// ── Converters, standing upright right of the A8 ─────────────────────────
eveps = [40, 70, 22];   // w, h, height (height: to measure)
cpt = [27, 58, 14];     // body 46 long + tabs (about 58 over them)
pocket_wall = 1.6;
pocket_h = 6;

// ── Screen (Hosyond ESP32-S3 3.5") in the lid ─────────────────────────────
scr_board = [101.5, 54.5];   // seller: 54.5 x 101.5 x 10 mm; 320 x 480 IPS, capacitive
scr_holes = [92, 45];   // corner holes, centre to centre (measured 2026-11-02)
scr_window = [76, 51];  // picture 73.4 x 49.0 (standard 3.5" 320 x 480), centred on the board
scr_post_h = 4.4;       // the glass stands 4.07 mm above the board (5.67 with it, measured); 0.3 air
scr_post_d = 6;
scr_screw_d = 1.7;      // M2 screws (the user's), through the board's 3 mm holes, cutting their thread
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
base_boss_h = 7;

// ── Derived ───────────────────────────────────────────────────────────────
up_y0 = wall + lower_h + divider;          // floor of the A8 section
up_h = H - wall - up_y0;                   // inside height of the A8 section
in_w = W - 2 * wall;
a8_x0 = wall + a8_margin;
a8_y0 = up_y0 + a8_bottom;
conv_x0 = a8_x0 + a8_w + 3;                // the converter strip
conv_w = W - wall - conv_x0;
power_x0 = wall + wiring_w + divider;
power_w = W - wall - power_x0;
scr_y = a8_y0 + a8_h / 2 + 8;

echo(str("box ", W, " x ", H, " x ", D, "; A8 section inside ", in_w, " x ", up_h,
         "; converter strip ", conv_w, " wide; wiring bay ", wiring_w, " x ", lower_h,
         "; power bay ", power_w, " x ", lower_h));
assert(conv_w >= eveps[0] + 2 * pocket_wall, "the converter strip is narrower than the EVEPS");
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
            for (x = [wall + 30, wall + wiring_w - 30])
                translate([x, wall + lower_h - 9, D - lid_t - 10]) rotate([-90, 0, 0]) cylinder(d = 3.4, h = 12);
            for (x = [power_x0 + 15, W - wall - 15])
                translate([x, wall, D - cover_t - 6]) rotate([-90, 0, 0]) insert_boss(10);
            // the wiring cover slides down in grooves: rails on the left wall and the bay divider
            for (x = [wall, wall + wiring_w - 1.2])
                translate([x, wall, D - cover_t - 2.4]) cube([1.2, lower_h, 1.2]);
            // the base plate's 4 bosses (inserts at the top)
            for (p = base_screws) translate([wall + 0.3 + p[0], up_y0 + 0.3 + p[1], back]) insert_boss(base_boss_h);
            // pockets: the converters, the Wagos, the terminal strips
            converter_pockets();
            bay_pockets();
        }
        // the wall hole: valve wires into the back of the wiring bay
        translate([wall + wiring_w / 2 - wall_hole[0] / 2, wall + 8, -1]) rcube([wall_hole[0], wall_hole[1], back + 2], 6);
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
        for (x = [wall + 30, wall + wiring_w - 30])
            translate([x, wall + lower_h - 10, D - lid_t - 10]) rotate([-90, 0, 0]) cylinder(d = 3.4, h = 20);
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
module converter_pockets() {   // low walls the converters drop into (a strap or tie holds them)
    z = back + base_t;
    ex = conv_x0 + (conv_w - eveps[0]) / 2;
    translate([ex - pocket_wall, H - wall - 4 - eveps[1] - pocket_wall, z]) pocket(eveps);
    translate([conv_x0 + (conv_w - cpt[0]) / 2 - pocket_wall, up_y0 + 4 - pocket_wall, z]) pocket(cpt);
}
module pocket(s) {
    difference() {
        cube([s[0] + 2 * pocket_wall, s[1] + 2 * pocket_wall, pocket_h]);
        translate([pocket_wall, pocket_wall, -1]) cube([s[0] + 0.5, s[1] + 0.5, pocket_h + 2]);
        // a slot each side for a strap or cable tie
        translate([-1, s[1] / 2 - 2, 2]) cube([s[0] + 2 * pocket_wall + 2, 5, 2.5]);
    }
}
module bay_pockets() {
    // wiring bay: the 12-strip lies across, its screws to the front, above the wall hole
    sx = wall + (wiring_w - strip12[0]) / 2;
    translate([sx - 1.6, wall + lower_h - strip12[1] - 14, back]) strip_pocket(strip12);
    // power bay: 4 Wagos (2 x 2) and the 5-strip
    translate([power_x0 + 4, wall + lower_h - 2 * (wago[1] + 1) - 6, back]) for (i = [0, 1], j = [0, 1])
        translate([i * (wago[0] + 2.4), j * (wago[1] + 2.4), 0]) difference() {
            cube([wago[0] + 3.2, wago[1] + 3.2, 4]);
            translate([1.6, 1.6, 1]) cube([wago[0] + 0.4, wago[1] + 0.4, 4]);
        }
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
            translate([0, 0, base_t - 3]) cylinder(d = 6.5, h = 4);
        }
        // clearance for the 2 high keyholes' screw heads (the box is hung before the plate goes in)
        for (p = keyholes) if (p[1] > up_y0) translate([p[0] - wall - 0.3, p[1] - up_y0 - 0.3 + 5, -1]) cylinder(d = 14, h = base_t + 2);
        // the converters' wires through, and the screen cable
        translate([conv_x0 - wall + 2, bh / 2 - 6, -1]) rcube([conv_w - 6, 12, base_t + 2], 3);
        translate([scr_center[0] - wall - 6, scr_y - up_y0 - 40, -1]) rcube([12, 12, base_t + 2], 3);
    }
}
function a8_hole_xy(p) = [a8_x0 - wall + p[0], (a8_y0 - up_y0) + (a8_flip ? p[1] : a8_h - p[1])];

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
                    difference() { cylinder(d = scr_post_d, h = scr_post_h); translate([0, 0, -1]) cylinder(d = scr_screw_d, h = scr_post_h); }
            // 2 hooks at the top (into the slots under the box's top wall)
            for (x = [W / 2 - 50, W / 2 + 50]) translate([x - wall - 7.5, lh - 0.1, 0]) cube([15, 1.4, lid_t]);
            // the bottom flange with 2 insert holes (screwed from the wiring bay)
            translate([0, 0, -12]) cube([lw, 2.4, 12]);
            for (x = [30, wiring_w - 30]) translate([x, 1.2, -10]) rotate([-90, 0, 0]) insert_boss(1.2);
        }
        // the window
        translate([sx - scr_window[0] / 2, sy - scr_window[1] / 2, -1]) rcube([scr_window[0], scr_window[1], lid_t + 2], 2);
        // microphone, at the screen's left end
        // (from the front photo: 6.4 mm from the board's left edge, 9.7 mm from its top)
        translate([sx - scr_board[0] / 2 + 6.4, sy + scr_board[1] / 2 - 9.7, -1]) cylinder(d = 2.5, h = lid_t + 2);
        // "IRRIGATION" (cut 0.6 mm: a colour change, or paint)
        translate([18, lh - 20, lid_t - 0.6]) linear_extrude(1) text("IRRIGATION", size = 9, font = "Liberation Sans:style=Bold");
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
        translate([12, lower_h / 2 - 5, cover_t - 0.6]) linear_extrude(1) text("Z1-Z8  COM  RAIN", size = 7, font = "Liberation Sans:style=Bold");
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
        for (x = [15, power_w - 0.6 - 15]) translate([x - (power_x0 - power_x0), -wall - 1, -3]) rotate([-90, 0, 0]) cylinder(d = 3.4, h = wall + 2);
        translate([8, lower_h / 2 - 4, cover_t - 0.6]) linear_extrude(1) text("POWER", size = 7, font = "Liberation Sans:style=Bold");
    }
}

// ── P7: strip clips: cover the strip's upper row (the A8's pre-wired side), 2 screws ─
module strip_clip(s) {
    tray = s[1] + 3.2;
    l = s[0] + 3.2 + 12 + 8;          // from boss to boss, plus ears
    difference() {
        union() {
            translate([-10, tray / 2 - 5, 0]) cube([l, 10, 2.4]);            // the screw bar
            translate([-1, tray / 2, 0]) cube([s[0] + 5.2, tray / 2 + 1, 2.4]);  // over the upper row
            // a lip down over the upper row's wire side, so the pre-wired leads can't be touched
            translate([-1, tray, -8]) cube([s[0] + 5.2, 1.6, 10.4]);
        }
        for (x = [-6, s[0] + 3.2 + 6]) translate([x, tray / 2, -1]) cylinder(d = 3.4, h = 5);
        translate([s[0] / 2 - 20, tray / 2 + 2.5, 2.4 - 0.6]) linear_extrude(1) text("A8 SIDE", size = 4);
    }
}
module clips() {
    strip_clip(strip12);
    translate([0, 40, 0]) strip_clip(strip5);
}

// ── Test prints ───────────────────────────────────────────────────────────
module test_inserts() {   // pick the insert hole: melt one into each, keep the snug one
    ds = [3.9, 4.0, 4.1, 4.2];
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
    // converters: their pockets as in the box
    cube([eveps[0] + 2 * pocket_wall + 4, eveps[1] + 2 * pocket_wall + 4, f]);
    translate([2, 2, f]) pocket(eveps);
    translate([eveps[0] + 12, 0, 0]) { cube([cpt[0] + 2 * pocket_wall + 4, cpt[1] + 2 * pocket_wall + 4, f]); translate([2, 2, f]) pocket(cpt); }
    // Wagos 2 x 2
    translate([eveps[0] + cpt[0] + 22, 0, 0]) {
        cube([2 * (wago[0] + 2.4) + 4, 2 * (wago[1] + 2.4) + 4, f]);
        translate([1, 1, f]) for (i = [0, 1], j = [0, 1]) translate([i * (wago[0] + 2.4), j * (wago[1] + 2.4), 0]) difference() {
            cube([wago[0] + 3.2, wago[1] + 3.2, 4]);
            translate([1.6, 1.6, 1]) cube([wago[0] + 0.4, wago[1] + 0.4, 4]);
        }
    }
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
    color("Black") translate([conv_x0 + (conv_w - eveps[0]) / 2, H - wall - 4 - eveps[1], back + base_t]) cube(eveps);
    color("Black") translate([conv_x0 + (conv_w - cpt[0]) / 2, up_y0 + 4, back + base_t]) cube(cpt);
    color("Gainsboro", 0.9) translate([wall + 0.3, up_y0 + 0.3, D - lid_t + explode]) lid();
    color("Gainsboro") translate([wall + 0.3, wall, D - cover_t + explode]) wiring_cover();
    color("Gainsboro") translate([power_x0 + 0.3, wall, D - cover_t + explode]) power_cover();
}

module open_view() {   // covers off: what's inside
    color("WhiteSmoke") box();
    color("LightSteelBlue") translate([wall + 0.3, up_y0 + 0.3, back]) base();
    color("ForestGreen", 0.8) translate([a8_x0, a8_y0, back + base_t + standoff_h]) cube([a8_w, a8_h, 1.6]);
    color("DarkOrange") translate([a8_x0 + 6, a8_y0 + a8_h - 10, back + base_t + standoff_h + 1.6]) cube([a8_w - 12, 10, 14]);
    color("Black") translate([conv_x0 + (conv_w - eveps[0]) / 2, H - wall - 4 - eveps[1], back + base_t]) cube(eveps);
    color("Black") translate([conv_x0 + (conv_w - cpt[0]) / 2, up_y0 + 4, back + base_t]) cube(cpt);
    color("White") translate([wall + (wiring_w - strip12[0]) / 2, wall + lower_h - strip12[1] - 14 + 1.6, back + 1]) cube(strip12);
    color("White") translate([power_x0 + 4 + 1.6, wall + 8 + 1.6, back + 1]) cube(strip5);
    color("Orange") translate([power_x0 + 4, wall + lower_h - 2 * (wago[1] + 1) - 6, back + 1]) for (i = [0, 1], j = [0, 1])
        translate([1.6 + i * (wago[0] + 2.4), 1.6 + j * (wago[1] + 2.4), 0]) cube(wago);
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

// Irrigation controller case (plan: docs/irrigation-case.md). OpenSCAD, parametric.
//
// One wall-mounted box: the KC868-A8 with its screen lid across the top (EVEPS and CPT converters
// standing upright to its right), and under it one wiring bay, full width, with one cover (hooks
// at the top, a thumb screw at the bottom). Wires from the A8 run behind it, in channels on the
// back of its base plate, down into the bay. Valve wires come out of the wall into the back of the
// bay; the transformer's wire comes in through a PG7 gland under the 24V / 0V terminals.
//
// Axes: x right, y up the wall, z out of the wall (0 = the wall). Sizes in mm.
// Render a part: openscad -D 'part="box"' -o box.stl irrigation_case.scad
// Parts: assembly (preview), box, base, lid, wiring_cover, wire_guard, thumb_knob, test_* pieces.

part = "assembly";
$fn = 48;

// ── The box ───────────────────────────────────────────────────────────────
W = 208;            // outside width
H = 225;            // outside height
D = 66;             // outside depth (wall to front)
wall = 2.4;         // side walls (6 lines of a 0.4 nozzle)
back = 3;           // back wall (against the wall)
lower_h = 80;       // inside height of the wiring bay at the bottom
divider = 2.4;      // the shelf between the A8 section and the bays
in_w = W - 2 * wall;          // inside width
chan_r_x = wall + 125 + 2.4;   // where the right wire channel comes down from behind the A8 (over the 24V / 0V terminals)
lid_t = 2.4;        // screen lid thickness
cover_t = 2.4;      // bay covers

// Heat-set inserts (the user's kit, its size chart: knurls 5.0, pilot collar 4.2, M3, L 4 and 6).
// The hole is about the pilot (4.2), confirmed with the test strip (4.1 / 4.2 / 4.3 / 4.4).
// 6 mm ones where there's depth, 4 mm ones in the base plate's posts.
ins_d = 4.2;            // confirmed: the best fit in the test strip (2026-11-02)
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
// held from turning), so the screws land wherever the ears are. M3 x 6 + washer through each ear
// (an M3 x 10 runs 3 mm into the plate under the nut and jams: review 2026-11-03).
rail_w = 12;
rail_h = 6;
nut_w = 6.2;       // M3 nut: 5.5 across flats, 6.35 across corners (so it can't turn)
nut_ch = 2.8;      // channel height (nut 2.4)
rail_top = 2.6;    // plastic over the channel

// ── Screen (Hosyond ESP32-S3 3.5") in the lid ─────────────────────────────
scr_board = [101.54, 54.26];   // measured 2026-11-03 (seller: 54.5 x 101.5 x 10 mm); 320 x 480 IPS, capacitive
scr_holes = [94.46, 47.96];   // centre to centre, measured on the board 2026-11-03 (outer + inner edge / 2; holes 3.0 mm). The published cases (89.7 x 51.2) are for another board: v2 test was 4.8 mm off
scr_window = [76, 51];  // picture 73.4 x 49.0 (standard 3.5" 320 x 480), centred on the board
scr_post_h = 3.5;       // the glass rests against the lid (4.4 left a gap over 0.8 mm in the test print)
scr_post_d = 7;
scr_screw_d = 2.7;      // M3 (passes the board's 3 mm holes, checked), cutting its thread into the post
scr_center = [118, 0];  // x of the screen centre (over the A8's right half); y set below

// ── Bays ──────────────────────────────────────────────────────────────────
strip12 = [109.5, 16.8, 12.27];   // length, depth (wire in to out), height (measured 2026-11-03: top 16.27 over the test piece's 3 mm back + 1 mm tray floor; the seller said 14)
strip5 = [43.79, 16.8, 12.27];   // 5 positions cut from a 12-strip (measured 2026-11-03)
strip_play = 0.15;             // tray clearance (2026-11-03 PETG tests): 0 was very tight, 0.3 a little wiggly
clip_clamp = 0.6;              // the clip bosses are this much lower than the strips' top: the wire guard clamps them
strip_tray_h = 3;              // tray: 1 mm floor + 2 mm wall (higher would cover the strip's wire holes)
// One wiring bay, full width (2026-11-03; it was a wiring bay and a power bay): both strips side by
// side in a band under the shelf, the 12-strip (zones, COM, RAIN) then the 5-strip (24V, 0V, flow).
// No Wagos: the 24 V AC splits on the strip's inner screws (two wires each), the 12 V at the A8's
// power terminal (daisy-chained to the CPT). Each strip's clip has a screw just past each end of
// the strip, into a 7 mm boss (2026-11-03: 9 mm bosses landed in the bay walls).
clip_boss_d = 7;
clip_ear_off = 2.5;                                  // tray end to a clip screw's centre
tw12 = strip12[0] + 3.2 + strip_play;                // tray widths
tw5 = strip5[0] + 3.2 + strip_play;
strip_gap = 2 * (clip_ear_off + clip_boss_d / 2) + 2;   // between the trays: a boss each, 2 mm apart
strips_y = wall + lower_h - strip12[1] - 14;         // the trays' near edge (14 mm under the shelf)
x12 = wall + (in_w - (tw12 + strip_gap + tw5)) / 2;  // the 12-strip's tray
x5 = x12 + tw12 + strip_gap;                         // the 5-strip's tray
pitch12 = strip12[0] / 12; pitch5 = strip5[0] / 5;
pass_w = 24;                                         // the wire pass-throughs from behind the A8 (were 18)
wiring_hooks = [25, in_w - 25];   // x of the wiring cover's 2 hooks, from the bay's left side
wago = [18.7, 18.6, 8.3];
wall_hole = [50, 35];          // valve wires out of the wall, into the back of the wiring bay
pg7_d = 12.5;                  // transformer wire: bottom wall, under the 24V / 0V terminals
gland_z = 28;                  // its centre, from the back wall's inside (higher than before: room for the nut and to bend the wires)
lid_lift = 2;      // the lid's flange and screw posts start this far up from its bottom edge (2.3 mm
                   // over the shelf: hooking on, the lid drops ~1.1 mm to get its lips under the top wall)
lid_screws = [42, in_w - 42];   // 17 mm from the cover's hooks (at 30, the screw heads were 0.25 mm under them)  // x of the lid's 2 screws (lid coordinates), up through the shelf

// Keyholes for #8 screws in the back: 2 high (behind the base plate: hang the box, then fit the
// plate, which has clearance holes over them), 2 low (in the bays).
// The 2 high ones are behind the base plate: its back has a 5 mm pocket over each for the screw
// head (not a hole through: at (20, 200) a through hole cut the A8's top-left standoff away).
// The box comes off the wall by lifting it (the heads slide down the slots), base plate and all.
keyholes = [[20, H - 25], [W - 20, H - 25], [20, 30], [W - 20, 30]];
kh_pocket = 5;   // depth of the head pockets in the base plate's back (of base_t)

// The base plate's 4 screws (base plate coordinates, from its bottom-left): clear of the channels,
// slots and the A8's standoffs. Bosses on the box's back fit into recesses in the plate's back;
// the heads sink into the plate's front (under the A8 there's only the 2.4 mm standoff gap).
base_screws = [[28, 28], [130, 26], [28, 105], [125, 105]];
base_boss_h = 4;   // an L4 insert goes 0.5 mm on into the back wall; M3 x 8 from the plate's front

// ── Derived ───────────────────────────────────────────────────────────────
up_y0 = wall + lower_h + divider;          // floor of the A8 section
up_h = H - wall - up_y0;                   // inside height of the A8 section
a8_x0 = wall + a8_margin;
a8_y0 = up_y0 + a8_bottom;
conv_x0 = a8_x0 + a8_w + 1.5;              // the converter strip
conv_w = W - wall - conv_x0;
scr_y = a8_y0 + a8_h / 2 + 8;

echo(str("box ", W, " x ", H, " x ", D, "; A8 section inside ", in_w, " x ", up_h,
         "; converter strip ", conv_w, " wide; wiring bay ", in_w, " x ", lower_h,
         "; strips at x ", x12, " and ", x5));
assert(conv_w >= max(eveps[0], cpt[0]) + 1, "the converter strip is narrower than the converters");
assert(up_h >= a8_bottom + a8_h + 10, "the A8 section is too short");
// every clip insert hole at least 1 mm of plastic from a wall, and the clip's screw clear of the tray wall
// the clip bosses clear of the bay walls (a boss may touch a wall, its insert hole 1 mm off it)
assert(x12 - clip_ear_off - ins_d / 2 - wall >= 1, "the 12-strip clip's left insert hole is in the wall");
assert(W - wall - (x5 + tw5 + clip_ear_off + ins_d / 2) >= 1, "the 5-strip clip's right insert hole is in the wall");
assert(clip_ear_off >= 3.4 / 2 + 0.4, "a strip clip's screw is over the tray wall");
assert(x12 - clip_ear_off - 4.5 - wall >= 1 && W - wall - (x5 + tw5 + clip_ear_off + 4.5) >= 1, "the wire guard's tabs reach a bay wall");
// the head pockets leave the base plate solid in front (the A8's standoffs stay whole)
assert(kh_pocket <= base_t - 4, "the keyhole head pockets go too deep into the base plate");
// at least 1 mm of plastic between the box posts' recesses and the ring channel, left and right
for (p = base_screws) if (p[0] < (in_w - 0.6) / 2) assert(p[0] - (boss_d + 0.6) / 2 - (2 + chan_w) >= 1, str("a base screw recess is within 1 mm of the left ring channel: ", p));
// the base plate drops straight in past the lid's ledge (3 mm in from the sides and the top)
assert(wall + 0.3 + base_dx >= wall + 3 + 0.2 && wall + 0.3 + in_w - 0.6 - base_dx <= W - wall - 3 - 0.2, "the base plate is wider than the opening inside the lid's ledge");
assert(up_y0 + 0.3 + up_h - 0.6 - base_dy <= H - wall - 3 - 0.2, "the base plate is taller than the opening inside the lid's ledge");

module chamfer_plate(s, r = 2, c = 1) {   // a plate whose front (top) edges are chamfered c
    hull() {
        rcube([s[0], s[1], s[2] - c], r);
        translate([c, c, 0]) rcube([s[0] - 2 * c, s[1] - 2 * c, s[2]], max(r - c, 0.5));
    }
}
module rcube(s, r = 2) {  // a box with rounded vertical edges
    hull() for (x = [r, s[0] - r], y = [r, s[1] - r]) translate([x, y, 0]) cylinder(r = r, h = s[2]);
}
module insert_boss(h, d = boss_d) {   // a post for a heat-set insert, open at the top
    difference() { cylinder(d = d, h = h); translate([0, 0, h - ins_depth]) cylinder(d = ins_d, h = ins_depth + 1); }
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
                translate([4, -1, -1]) cube([pass_w, divider + 2, base_t - back + 1]);
                translate([chan_r_x - wall + 4, -1, -1]) cube([pass_w, divider + 2, base_t - back + 1]);
            }
            // the lid rests on a ledge all round the A8 section
            ledge();
            // the wiring cover rests on strips down both sides of the bay; it hooks into the shelf at the
            // top and a thumb screw holds it at the bottom (into this post, insert from the front)
            for (x = [wall, W - wall - 2.4]) hull() {   // (a 45-degree slope under: prints without droop)
                translate([x, wall, D - cover_t - 1.6]) cube([2.4, lower_h, 1.6]);
                translate([x == wall ? wall : W - wall - 0.01, wall, D - cover_t - 1.6 - 2.4]) cube([0.01, lower_h, 0.01]);
            }
            // (a 45-degree slope under it, down the bottom wall: prints without support)
            hull() {
                translate([W / 2 - 6, wall, D - cover_t - 10]) cube([12, 11, 10]);
                translate([W / 2 - 6, wall, D - cover_t - 21]) cube([12, 0.01, 11]);
            }
            // the base plate's 4 bosses (inserts at the top)
            for (p = base_screws) translate([wall + 0.3 + p[0], up_y0 + 0.3 + p[1], back]) cylinder(d = boss_d, h = base_boss_h);
            // pockets: the terminal strips (the converters are on rails on the base plate)
            bay_pockets();
        }
        // the base plate bosses' insert holes, on into the back wall (5.5 deep from the boss top)
        for (p = base_screws) translate([wall + 0.3 + p[0], up_y0 + 0.3 + p[1], back + base_boss_h - ins_depth_short - 1]) cylinder(d = ins_d, h = ins_depth_short + 1.1);   // 1 mm extra: an M3 x 8 bottomed out (review)
        // the wall hole: valve wires into the back of the wiring bay
        translate([x12 + tw12 / 2 - wall_hole[0] / 2, wall + 8, -1]) rcube([wall_hole[0], wall_hole[1], back + 2], 6);   // under the 12-strip
        // the wiring cover: its 2 hooks go up into these slots in the shelf (1.2 mm lip in front), and
        // the thumb screw's insert (L6, pressed in from the front)
        for (x = wiring_hooks) translate([wall + x - 6.5, wall + lower_h - 1, D - cover_t - 3.2]) cube([13, divider + 2, 2.0]);
        translate([W / 2, wall + 5.5, D - cover_t - ins_depth]) cylinder(d = ins_d, h = ins_depth + 0.1);
        // the transformer's gland, under the 24V / 0V terminals
        translate([x5 + 1.6 + pitch5, -1, back + gland_z]) rotate([-90, 0, 0]) cylinder(d = pg7_d, h = wall + 2);
        // knockouts (a 0.4 mm skin to punch out): under RAIN, and under FLOW+ / SIG / GND
        for (x = [x12 + 1.6 + pitch12 * 11, x5 + 1.6 + pitch5 * 3.5])
            translate([x, 0.4, back + 22]) rotate([-90, 0, 0]) cylinder(d = 18.6, h = wall);
        // vents: slots under the bays, at the bottom of the A8 section's sides, and on top
        for (i = [0 : 6]) translate([wall + 40 + i * 8, -1, back + 34]) cube([3, wall + 2, 16]);   // (an 8th notched the thumb screw post)
        for (s = [0, 1]) for (i = [0 : 3])
            translate([s ? W - wall - 1 : -1, up_y0 + 6 + i * 8, back + 14]) cube([wall + 2, 3, 30]);
        for (i = [0 : 13]) translate([30 + i * 10, H - wall - 1, back + 14]) cube([3, wall + 2, 30]);
        // keyholes for #8 screws in the back
        for (p = keyholes) translate([p[0], p[1], -1]) keyhole();
        // the lid's 2 hooks go into these slots under the top wall
        for (x = [W / 2 - 50, W / 2 + 50]) translate([x - 8, H - wall - 3.6, D - lid_t - 4.7]) cube([16, 4.7, 4.71]);   // through the top ledge and 1.1 into the wall; 0.5 mm play for the hook
        // screw holes for the lid (through the shelf front, from below)
        for (x = [wall + 0.3 + lid_screws[0], wall + 0.3 + lid_screws[1]])
            translate([x, wall + lower_h - 1, D - lid_t - 6]) rotate([-90, 0, 0]) cylinder(d = 3.4, h = divider + 2);
    }
}
module ledge() {   // inside the A8 section, 2.4 mm behind the front: the lid sits on it
    t = 2;      // the ledge itself
    c = 3;      // a 45-degree slope under it (the box prints on its back: no support needed)
    // top and both sides only: at the bottom the lid's flange and its 2 screws hold it (review
    // 2026-11-03: a bottom ledge stood under the flange and posts, the lid couldn't seat)
    translate([0, 0, D - lid_t - t - c]) difference() {
        translate([wall, up_y0, 0]) cube([in_w, up_h, t + c]);
        hull() {
            translate([wall, up_y0 - 1, -0.01]) cube([in_w, up_h + 1, 0.01]);
            translate([wall + 3, up_y0 - 1, c]) cube([in_w - 6, up_h - 2, t + 0.02]);
        }
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
    // both strips in a row under the shelf, screws to the front: the 12-strip over the wall hole,
    // the 5-strip (24V, 0V first) under the right channel and over the gland
    translate([x12, strips_y, back]) strip_pocket(strip12);
    translate([x5, strips_y, back]) strip_pocket(strip5);
}
module strip_pocket(s) {   // a shallow tray; the printed clip (P7) holds the strip down with 2 screws
    c = strip_play;
    difference() {
        union() {
            cube([s[0] + 3.2 + c, s[1] + 3.2 + c, strip_tray_h]);
            // posts 0.6 mm below the strip's top: tightening the clip's screws clamps the strip
            // (at the strip's height, the user found the post a touch higher than the strip)
            for (x = [-clip_ear_off, s[0] + 3.2 + c + clip_ear_off]) translate([x, (s[1] + 3.2 + c) / 2, 0]) insert_boss(s[2] + 1 - clip_clamp, clip_boss_d);
        }
        translate([1.6, 1.6, 1]) cube([s[0] + c, s[1] + c, strip_tray_h]);
    }
}

// ── P6: the A8's base plate, wire channels on its back ───────────────────
// The plate is 3 mm smaller than the A8 section on the left, right and top, so it drops straight
// in past the lid's ledge (review 2026-11-03: at full size it had to be tilted two ways at once).
// Everything on it keeps its place in the box: the module works in the full-size frame (origin
// at wall + 0.3, up_y0 + 0.3) and only the outline is smaller.
base_dx = 3;                                   // trimmed off the left and right edges
base_dy = 3;                                   // trimmed off the top edge
module base() {
    bw0 = in_w - 0.6; bh0 = up_h - 0.6;          // the full-size frame
    bw = bw0 - 2 * base_dx; bh = bh0 - base_dy;  // the plate: 196.6 x 134.2
    intersection() {
    translate([base_dx, 0, -1]) cube([bw, bh, 100]);
    difference() {
        union() {
            translate([base_dx, 0, 0]) cube([bw, bh, base_t]);
            // the 4 standoffs
            for (p = a8_holes) translate(a8_hole_xy(p)) translate([0, 0, base_t]) cylinder(d = standoff_d, h = standoff_h);
            // the converters' nut rails
            converter_rails();
        }
        for (p = a8_holes) translate(a8_hole_xy(p)) translate([0, 0, 2]) cylinder(d = a8_screw_d, h = base_t + standoff_h);
        // the ring channel on the back, round the board
        // (the left side is base_dx narrower than the rest, so its inner edge stays where it was:
        // 3 mm of plastic to the box posts' recesses, not 0.2; review of the first plate B print)
        translate([base_dx, 0, -1]) difference() {
            translate([2, 2, 0]) cube([bw - 4, bh - 4, chan_depth + 1]);
            translate([2 + chan_w - base_dx, 2 + chan_w, -1]) cube([bw - 4 - 2 * chan_w + base_dx, bh - 4 - 2 * chan_w, chan_depth + 3]);
        }
        // a cross channel behind the converters, and up to the screen
        translate([conv_x0 - wall - 4, 2, -1]) cube([chan_w, bh - 4, chan_depth + 1]);
        // the channel opens at the bottom edge over the shelf's pass-throughs into the bays
        translate([4 - 0.3, -1, -1]) cube([pass_w, 4, chan_depth + 1]);
        translate([chan_r_x - wall + 4 - 0.3, -1, -1]) cube([pass_w, 4, chan_depth + 1]);
        // the long slots through: relay edge (top) and the green blocks' edge (bottom)
        sx = a8_x0 - wall + 6;
        translate([sx, a8_y0 - up_y0 + a8_h + 3, -1]) rcube([a8_w - 12, slot_w, base_t + 2], 3);
        translate([sx, a8_y0 - up_y0 - slot_w - 2, -1]) rcube([a8_w - 12, slot_w, base_t + 2], 3);
        // the box's bosses fit into recesses on the back; M3 screws from the front, heads sunk
        for (p = base_screws) translate([p[0], p[1], 0]) {
            translate([0, 0, -1]) cylinder(d = boss_d + 0.6, h = base_boss_h + 1.3);
            cylinder(d = 3.4, h = base_t + 1);
            translate([0, 0, base_t - 3.1]) cylinder(d = 6.5, h = 4);   // a socket head (3.0) sinks in flush
        }
        // pockets on the back for the 2 high keyholes' screw heads (a #8 pan head is about 8.4 mm
        // across and 3.3 mm high), along the whole slot so the box can be lifted off the wall
        for (p = keyholes) if (p[1] > up_y0) translate([p[0] - wall - 0.3, p[1] - up_y0 - 0.3, -1])
            hull() for (dy = [0, 10]) translate([0, dy, 0]) cylinder(d = 11, h = kh_pocket + 1);
        // the converters' wires through (the 24 V AC to the EVEPS, up the right channel): through
        // the plate only, so the EVEPS rail's nut channel keeps its floor (review 2026-11-03).
        // The screen cable runs in front (CPT 5 V and the A8's S1/S2 up to the screen): no hole.
        translate([conv_x0 - wall + 2, bh0 / 2 - 6, -1]) rcube([conv_w - 6, 12, base_t + 1], 3);
    }
    }
}
function a8_hole_xy(p) = [a8_x0 - wall + p[0], (a8_y0 - up_y0) + (a8_flip ? p[1] : a8_h - p[1])];

// ── Marks ─────────────────────────────────────────────────────────────────
// Outside, no words: a water drop on the lid and a 1.2 mm line framing the screen, pressed 0.6 mm
// into the face (the lid prints face down, so they can't stand out of it; one colour: OrcaSlicer's
// command line crashes on the lid with an inlay). Inside, the terminal names on the strip clips in
// black: cut 0.6 mm (3 layers) into the top of the flat clips (names up), and clips_labels (the
// same shapes) prints in black in the cut, side by side, no overlap.
label_d = 0.6;
bold = "Liberation Sans:style=Bold";
strip12_labels = ["Z1", "Z2", "Z3", "Z4", "Z5", "Z6", "Z7", "Z8", "COM", "COM2", "RAIN", "RAIN"];
strip5_labels = ["24V", "0V", "FLOW+", "SIG", "GND"];

// The front: no words, just a water drop on the lid and a dark bezel round the screen.
module drop_2d(h = 18) {   // a water drop, point up, h tall
    r = h * 0.32;
    hull() { circle(r = r, $fn = 64); translate([0, h - r - 0.6]) circle(r = 0.6, $fn = 16); }
}
module lid_label() {
    sx = scr_center[0] - wall; sy = scr_y - up_y0;
    // the logo, centred in the plain part of the lid left of the screen
    translate([(sx - scr_board[0] / 2) / 2, sy - 7, lid_t - label_d]) linear_extrude(label_d + 0.01) drop_2d(18);
    // a thin etched line framing the window, 5 mm out
    translate([sx, sy, lid_t - label_d]) linear_extrude(label_d + 0.01) difference() {
        offset(r = 4.2) square(scr_window, center = true);   // 1.2 mm wide, ~0.9 mm clear of the mic hole
        offset(r = 3.0) square(scr_window, center = true);
    }
}
module wiring_cover_label() { }   // plain (the wire-colour table was removed: not needed)
module clip_labels(s, names) {   // one name beside each position, on the clip's top (upright text)
    pitch = s[0] / len(names);
    tray = s[1] + 3.2 + strip_play;
    for (i = [0 : len(names) - 1])
        translate([1.6 + pitch * (i + 0.5), tray / 2 + 1.2, 2.4 - label_d]) rotate([0, 0, 90])
            // names of 4+ letters are scaled to 13 mm long, so they fit the clip's ~15 mm (FLOW+, COM2, RAIN)
            linear_extrude(label_d + 0.01)
                if (len(names[i]) >= 4) resize([13, 0], auto = true) text(names[i], size = 3.6, font = bold, valign = "center");
                else text(names[i], size = 4, font = bold, valign = "center");   // 4 mm (3.2 printed too rough, 2026-11-03)
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
            chamfer_plate([lw, lh, lid_t], 2, 1);
            // the screen's 4 posts (behind the lid, toward the A8)
            for (dx = [-1, 1], dy = [-1, 1])
                translate([sx + dx * scr_holes[0] / 2, sy + dy * scr_holes[1] / 2, -scr_post_h])
                    cylinder(d = scr_post_d, h = scr_post_h);
            // 2 hooks at the top (into the slots under the box's top wall)
            // (behind the plate, in line with the slots: review 2026-11-03, in the plate's plane they hit the wall)
            // the lip that sticks out past the plate's top edge is 0.3 behind the plate's back (room to
            // tilt in and out); the part under the plate is joined to it (2026-11-04: the hooks were
            // 0.3 mm off the plate everywhere, so they printed as loose blocks)
            for (x = [W / 2 - 50, W / 2 + 50]) translate([x - wall - 7.5, lh - 3, -4]) {
                cube([15, 3 + 1.3, 3.7]);
                cube([15, 3, 4.01]);
            }
            // the bottom flange with 2 insert holes (screwed from the wiring bay)
            // lid_lift up from the lid's bottom edge: hooking on and swinging shut, the lid's bottom
            // drops below its final place and the flange hit the shelf (2026-11-04)
            translate([3.3, lid_lift, -12]) cube([lw - 6.6, 2.4, 12]);   // stops short of the side ledges
            // 2 posts up from the flange, the inserts pressed in from below (M3 x 8 up through the shelf)
            // (each post is filled down to the lid plate, so it prints without support)
            for (x = lid_screws) hull() {
                translate([x, lid_lift, -6]) rotate([-90, 0, 0]) cylinder(d = boss_d, h = 8);
                translate([x - boss_d / 2, lid_lift, -0.01]) cube([boss_d, 8, 0.01]);
            }
        }
        // the posts' insert holes, cut after the union: cut inside the posts only, the flange
        // closed them off (2026-11-04)
        for (x = lid_screws) translate([x, lid_lift - 1, -6]) rotate([-90, 0, 0]) cylinder(d = ins_d, h = ins_depth + 1);   // M3 x 10 from the bay: 5.3 mm in the insert, 1.2 spare
        // the screen screws' holes: through the posts and 1 mm into the lid (1.4 mm left in front),
        // so an M3 x 6 fits with 0.4 to spare (board 1.6 + post 3.5 + 1.3)
        for (dx = [-1, 1], dy = [-1, 1])
            translate([sx + dx * scr_holes[0] / 2, sy + dy * scr_holes[1] / 2, -scr_post_h - 1]) cylinder(d = scr_screw_d, h = scr_post_h + 2.3);   // 1.3 into the lid: M3 x 6 has 0.4 to spare
        // the window
        translate([sx, sy, 0]) hull() {
            translate([0, 0, -1]) linear_extrude(0.01) offset(r = 1.5) offset(delta = -1.5) square(scr_window, center = true);
            translate([0, 0, lid_t - 1]) linear_extrude(0.01) offset(r = 1.5) offset(delta = -1.5) square(scr_window, center = true);
            translate([0, 0, lid_t + 0.01]) linear_extrude(0.01) offset(r = 2.5) offset(delta = -1.5) square(scr_window + [2, 2], center = true);
        }
        // microphone, at the screen's left end
        // (from the front photo: 6.4 mm from the board's left edge, 9.7 mm from its top)
        translate([sx - scr_board[0] / 2 + 6.4, sy + scr_board[1] / 2 - 9.7, -1]) cylinder(d = 2.5, h = lid_t + 2);
        lid_label();   // the drop and the window line, pressed into the face
    }
}

// ── P3: the wiring cover (one, full width) ─────────────────────────────────
module wiring_cover() {   // hooks at the top, a thumb screw at the bottom: opens by hand
    ch = lower_h - 0.3;
    difference() {
        union() {
            chamfer_plate([in_w - 0.6, ch, cover_t], 1.5, 1);
            // the 2 hooks: back 1.2 mm behind the shelf's lip, then up 2.6 mm into its slots
            for (x = wiring_hooks) translate([x - 6, 0, 0]) {
                translate([0, ch - 6, -3.0]) cube([12, 6, 3.0]);
                translate([0, ch - 0.1, -3.0]) cube([12, 2.7, 1.6]);   // 2.6 mm: through the 2.4 mm shelf; short enough to print unsupported
            }
        }
        wiring_cover_label();   // (empty: a plain cover)
        // 0.3 mm off the bottom edge: it sat on the box's bottom wall with no gap and scraped it
        // swinging shut (2026-11-04)
        translate([-1, -1, -5]) cube([in_w + 2, 1.3, cover_t + 10]);
        // the thumb screw (M3 x 10 in the printed knob)
        translate([W / 2 - wall - 0.3, 5.5, -1]) cylinder(d = 3.4, h = cover_t + 2);
    }
}
module thumb_knob() {   // an M3 x 10 socket screw pressed in head first: turn by hand
    difference() {
        cylinder(d = 18, h = 6, $fn = 60);
        for (i = [0 : 11]) rotate([0, 0, i * 30]) translate([9.6, 0, -1]) cylinder(d = 3, h = 8);   // grip
        translate([0, 0, -1]) cylinder(d = 3.4, h = 8);
        translate([0, 0, 6 - 3.2]) cylinder(d = 5.7, h = 4);   // the screw head, pressed in
    }
}
// ── P7: strip clips: cover the strip's upper row (the A8's pre-wired side), 2 screws ─
module strip_clip(s, names) {
    tray = s[1] + 3.2 + strip_play;
    ear = clip_ear_off + clip_boss_d / 2 - 0.5;    // each ear stops short of the next strip's ear
    difference() {
        union() {
            // the screw ears, only beyond the strip's ends (the front row's screws stay open)
            for (x = [-ear, s[0] + 3.2 + strip_play]) translate([x, tray / 2 - 5, 0]) cube([ear, 10 + 5, 2.4]);
            translate([-1, tray / 2, 0]) cube([s[0] + 5.2, tray / 2 + 6, 2.4]);  // over the upper row, and 5 mm on (room for the names)
        }
        for (x = [-clip_ear_off, s[0] + 3.2 + strip_play + clip_ear_off]) translate([x, tray / 2, -1]) cylinder(d = 3.4, h = 5);
        clip_labels(s, names);   // each terminal's name: a 0.6 mm pocket, filled by clips_labels in black
    }
}
// ── P7b: the wire guard (replaces the 2 clips, 2026-11-03) ───────────────
// One piece over both strips: from the middle of the strips (the upper, pre-wired rows) up to the
// shelf, so the jumpers fanning out of the pass-throughs are hidden; only the front-row screws
// show, each with its name above it (recessed). Held by the strips' 4 clip bosses (M3), clamping
// both strips down. Flat, names up; in box coordinates (x, y), 2.4 mm thick.
module wire_guard() {
    tray = strip12[1] + 3.2 + strip_play;
    y0 = strips_y + tray / 2;                    // the strips' middle (between the rows)
    y1 = wall + lower_h - 0.5;                   // 0.5 mm short of the shelf
    xs = [x12 - clip_ear_off, x12 + tw12 + clip_ear_off, x5 - clip_ear_off, x5 + tw5 + clip_ear_off];
    difference() {
        union() {
            translate([x12 - 1, y0, 0]) cube([x5 + tw5 + 2 - x12, y1 - y0, 2.4]);
            for (x = xs) hull() {                // a round tab over each boss
                translate([x, y0, 0]) cylinder(d = 9, h = 2.4);
                translate([x - 4.5, y0, 0]) cube([9, 6, 2.4]);
            }
        }
        for (x = xs) translate([x, y0, -1]) cylinder(d = 3.4, h = 5);
        translate([x12, strips_y, 0]) clip_labels(strip12, strip12_labels);
        translate([x5, strips_y, 0]) clip_labels(strip5, strip5_labels);
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

module test_strip_end() {   // the wiring bay's left end: wall, strip tray end, clip boss; and the clip's end
    ty = strips_y;                                    // the trays' y in the box
    intersection() {
        box();
        translate([-1, ty - 6, -1]) cube([x12 + 28, strip12[1] + 3.2 + strip_play + 12, back + 18]);
    }
    // the clip's left end, beside it (flat, as printed)
    translate([x12 + 40, ty, 0]) intersection() {
        strip_clip(strip12, strip12_labels);
        translate([-clip_ear_off - clip_boss_d / 2, -1, -1]) cube([clip_ear_off + clip_boss_d / 2 + 26, 40, 10]);
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
}

module test_screen() {   // the lid's screen corner (window, 4 posts, mic hole), face down, posts up
    sx = scr_center[0] - wall; sy = scr_y - up_y0;
    translate([0, 0, lid_t]) rotate([180, 0, 0]) translate([-sx, -sy, 0])
        intersection() { lid(); translate([sx - 60, sy - 35, -10]) cube([120, 70, 20]); }
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
}

module open_view() {   // covers off: what's inside
    color("WhiteSmoke") box();
    color("LightSteelBlue") translate([wall + 0.3, up_y0 + 0.3, back]) base();
    color("ForestGreen", 0.8) translate([a8_x0, a8_y0, back + base_t + standoff_h]) cube([a8_w, a8_h, 1.6]);
    color("DarkOrange") translate([a8_x0 + 6, a8_y0 + a8_h - 10, back + base_t + standoff_h + 1.6]) cube([a8_w - 12, 10, 14]);
    color("Black") translate([conv_x0 + (conv_w - eveps[0]) / 2, H - wall - 4 - eveps[1], back + base_t + rail_h]) cube(eveps);
    color("Black") translate([conv_x0 + (conv_w - cpt[0]) / 2, up_y0 + 4, back + base_t + rail_h]) cube(cpt);
    color("White") translate([x12 + 1.6, strips_y + 1.6, back + 1]) cube(strip12);
    color("White") translate([x5 + 1.6, strips_y + 1.6, back + 1]) cube(strip5);
}

// Wall template: a thin frame the size of the box's back, held on the wall (a level on its top
// edge) to mark the 4 screws and the valve-wire hole. Seen from the front as printed (text up).
// The screws go where the box hangs from: the top of each keyhole's slot (the box drops 10 mm
// onto them).
module wall_template() {
    t = 0.6;
    rim = 8;
    screws = [for (p = keyholes) [p[0], p[1] + 10]];
    hole_at = [x12 + tw12 / 2 - wall_hole[0] / 2, wall + 8];
    difference() {
        union() {
            difference() {   // outline
                rcube([W, H, t], 6);
                translate([rim, rim, -1]) rcube([W - 2 * rim, H - 2 * rim, t + 2], 3);
            }
            for (q = screws) {   // a pad per screw, tied to the rim
                translate(q) cylinder(d = 16, h = t);
                translate([q[0] < W / 2 ? 0 : q[0], q[1] - 3]) cube([q[0] < W / 2 ? q[0] : W - q[0], 6, t]);
            }
            for (q = screws) if (q[1] < H / 2) translate([q[0] - 3, 0]) cube([6, q[1], t]);
            for (q = screws) if (q[1] > H / 2) translate([q[0] - 3, q[1]]) cube([6, H - q[1], t]);
            // ring round the valve-wire hole, tied to the bottom rim
            translate([hole_at[0] - 3, hole_at[1] - 3, 0]) rcube([wall_hole[0] + 6, wall_hole[1] + 6, t], 8);
            translate([W / 2 - 3, 0]) cube([6, H, t]);   // centre bar (and plumb line)
            translate([0, 120, 0]) cube([W, 14, t]);        // a bar for the words
        }
        for (q = screws) translate([q[0], q[1], -1]) {
            cylinder(d = 3, h = t + 2);                   // marker / pencil hole
            for (a = [0, 90]) rotate(a) translate([-7, -0.4]) cube([4, 0.8, t + 2]);   // cross ticks
            for (a = [0, 90]) rotate(a) translate([3, -0.4]) cube([4, 0.8, t + 2]);
        }
        translate([hole_at[0], hole_at[1], -1]) rcube([wall_hole[0], wall_hole[1], t + 2], 6);
        for (y = [-1, H - 6]) translate([W / 2 - 0.4, y, -1]) cube([0.8, 7, t + 2]);   // centre marks
    }
    translate([W / 2, 127, t - 0.01]) linear_extrude(0.4)   // raised words
        text("UP ^  FRONT  level on top edge", size = 6, halign = "center", valign = "center",
             font = "Liberation Sans:style=Bold");
}

if (part == "assembly") assembly(0);
else if (part == "open") open_view();
else if (part == "exploded") assembly(45);
else if (part == "box") box();
else if (part == "base") base();
else if (part == "lid") rotate([180, 0, 0]) lid();   // face down to print
else if (part == "wiring_cover") rotate([180, 0, 0]) wiring_cover();
else if (part == "test_inserts") test_inserts();
else if (part == "test_base") test_base();
else if (part == "test_fits") test_fits();
else if (part == "test_strip_end") test_strip_end();
else if (part == "clips") clips();
else if (part == "wire_guard") rotate([180, 0, 0]) wire_guard();   // names DOWN on the bed: crisp letters (on top they came out rough)
else if (part == "test_labels") rotate([180, 0, 0]) intersection() { wire_guard(); translate([x12 - 12, 0, -1]) cube([52, 200, 10]); }   // Z1-Z4, ~8 min   // flat, names up (the names are black inlays in the top layers)
else if (part == "thumb_knob") thumb_knob();
else if (part == "test_screen") test_screen();
else if (part == "lid_labels") rotate([180, 0, 0]) lid_label();   // same turn as their part
else if (part == "wiring_cover_labels") rotate([180, 0, 0]) wiring_cover_label();
else if (part == "clips_labels") clips_labels();
else if (part == "wall_template") wall_template();

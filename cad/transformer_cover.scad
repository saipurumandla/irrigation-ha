// Transformer boot (P5): hides the screws, ring terminals and crimps of the PS-AC2440D plug-in
// transformer, like the strain-relief boot on a power adapter. Two plugs press into the screw
// pockets, flush with the front, and hang on the screw heads; below them a boot tapers from the
// pockets down to a collar round the cable's jacket, open at the back (it faces the wall). Two zip
// ties round the collar clamp the jacket, so a pull or a wiggle stops there, never at the screws.
//
//   openscad -D 'part="cover"' -o stl/transformer_cover.stl transformer_cover.scad
//
// Axes: x across the brick (0 = middle of the rib), y front face (0) towards the wall,
// z up (0 = the brick's bottom edge). Printed front face down, no supports.

part = "cover";   // cover | fitted (with a stand-in brick)

// ---- measured (mm, 2026-11-06, wires on) ----
G = 10.51;        // pocket width
D = 18.15;        // rib width between the pockets
F = 15.30;        // pocket height, from the bottom edge
E = 6.02;         // pocket depth, front face to back wall
head_gap = 2.10;  // front face to the top of the screw heads (S = E - 2.10)
A = 59.5;         // brick width at the bottom (sides rounded: approximate)
B = 48;           // brick depth, front to back
L = 50;           // bottom edge to the start of the cable's jacket
cable = 5.75;     // jacket diameter (5.5 - 6)
// from the photo, scaled by G and F: screw centres 7.4 / 8.4 above the bottom edge,
// heads about 8.4 across with the ring; rings about 10 across, flat on the back wall
head_z = [7.4, 8.4];
head_d = 8.4;
ring_t = 1.0;     // ring terminal thickness on the back wall

// ---- fit ----
// Printed in TPU 90A (SUNLU; 2026-11-06): soft, so the plugs go in at zero clearance and squeeze,
// the collar grips the jacket by itself (the zip ties add to it), walls a bit thicker so it isn't floppy.
tpu = true;
press = tpu ? 0 : 0.08;   // plug smaller than the pocket, per side
front_t = 1.4;    // plug face; head_gap - front_t = 0.7 clear of the heads
wall = tpu ? 2.0 : 1.6;   // boot walls
tie_w = 2.5;      // zip tie
// The 50 mm of loose wires bend a little on the way down, so the jacket starts ~38 below the
// bottom edge; the collar holds it from there.
collar_top = -40;
collar_len = 14;
boot_d = 12;      // the sleeve's depth at the top
crimp_d = 8;      // channel for the crimps (yellow one ~7 across): they sit snug, can't swing
crimp_len = 18;   // crimp + its insulation, below the bottom edge
wire_d = 5.5;     // channel for the taped wires on the way to the collar
front_w = tpu ? 1.6 : 1.2;   // sleeve front wall
$fn = 64;

plug_x = D / 2 + G / 2;   // pocket centres
plug_w = G - 2 * press;
plug_h = F - 2 * press;
plug_d = E - ring_t - 0.5;    // clear of the rings on the back wall
recess_d = head_d + 1.0;

assert(front_t <= head_gap - 0.5, "plug face hits the screw heads");
assert(plug_d > front_t + 1, "pocket too shallow for a plug");

module rrect(w, d, rf, rb) {     // plan shape: front corners rf, back corners rb
  hull() {
    for (s = [-1, 1]) {
      translate([s * (w / 2 - rf), rf]) circle(rf);
      translate([s * (w / 2 - rb), d - rb]) circle(rb);
    }
  }
}

module plug(i) {
  difference() {
    translate([-plug_w / 2, 0, -0.01]) cube([plug_w, plug_d, plug_h + press]);
    // the screw head (one slot covers both screws' heights)
    hull() for (z = [min(head_z), max(head_z)])
      translate([0, front_t, z]) rotate([-90, 0, 0]) cylinder(d = recess_d, h = E);
    // the way in from below, narrower than the head: the plug slides up and snaps over it
    if (closed) translate([-entry_w / 2, front_t, -1]) cube([entry_w, E, min(head_z) + 1]);
  }
}

// Closed sleeve, v2 (2026-11-06): a Y slit down the back (wall side) from each plug to the collar's
// bottom; spread it, lay the crimps, wires and jacket in, and the TPU springs shut (v1 had to be
// threaded, which can't work with both ends wired). The plugs slide up into the pockets (open at the
// bottom) and snap over the screw heads through a narrower entry. The collar is a solid tube with that
// one slit, a little under the jacket; two zip ties clamp it. Printed front face down, so the layers
// run along the collar (v1, printed standing on the collar, split into fingers).
closed = true;
entry_w = head_d - 1.2;              // narrower than the head: the snap
col_od = cable + 2 * (wall + 0.6);   // collar outside
col_id = closed ? cable - 0.3 : cable - (tpu ? 0.6 : 0.2);   // slides along the jacket / squeezes it
cable_y = col_od / 2 - 1;            // the front plane cuts a flat on the collar (prints flat)
boot_w = 2 * (plug_x + plug_w / 2 - 1 + wall);   // walls overlap the plugs by 1
collar_bot = collar_top - collar_len;

// The outside follows the channels (a tapered sleeve, as small as the wires allow): its front
// outline hugs the Y of channels, its side outline tapers from boot_d to the collar.
module boot_outer() {
  intersection() {
    translate([0, boot_d + 1, 0]) rotate([90, 0, 0]) linear_extrude(boot_d + 2) hull() {
      offset(r = wall) channels_2d();
      translate([0, collar_top]) circle(d = col_od);
    }
    side_profile(0);
    translate([-50, -1, collar_top - 1]) cube([100, 50, -collar_top + 1]);   // nothing above the bottom edge
  }
  translate([0, cable_y, collar_bot]) cylinder(d = col_od, h = collar_len + 0.01);
}
module side_profile(inset) {   // the sleeve seen from the side (front at y = 0), extruded across
  rotate([90, 0, 90]) translate([0, 0, -50]) linear_extrude(100) offset(delta = -inset)
    polygon([[-5, 5], [boot_d, 5], [boot_d, -crimp_len], [cable_y + col_od / 2, collar_top - 3], [-5, collar_top - 3]]);
}
// the two channels (a Y), as seen from the front
module channels_2d() {
  for (sx = [-1, 1]) {
    hull() {   // the crimp, straight down from its pocket
      translate([sx * plug_x, 1]) circle(d = crimp_d);
      translate([sx * plug_x * 0.8, -crimp_len]) circle(d = crimp_d);
    }
    hull() {   // the wire, on to the collar
      translate([sx * plug_x * 0.8, -crimp_len]) circle(d = wire_d);
      translate([0, collar_top + 1]) circle(d = wire_d);
    }
  }
}
module slit_2d() {
  for (sx = [-1, 1]) {
    hull() { translate([sx * plug_x, 3]) circle(d = 1.5); translate([sx * plug_x * 0.8, -crimp_len]) circle(d = 1.5); }
    hull() { translate([sx * plug_x * 0.8, -crimp_len]) circle(d = 1.5); translate([0, collar_top]) circle(d = 1.5); }
  }
}
module boot() {
  difference() {
    boot_outer();
    if (closed) intersection() {   // channels inside a back wall
      translate([0, boot_d - wall, 0]) rotate([90, 0, 0]) linear_extrude(boot_d - wall - front_w) channels_2d();
      side_profile(wall);
    } else
      translate([0, front_w + 60, 0]) rotate([90, 0, 0]) linear_extrude(60) channels_2d();
    translate([0, cable_y, collar_bot - 1]) cylinder(d = col_id, h = collar_len + 2);
    // the jacket's way up into the channels
    if (closed) hull() {
      translate([0, cable_y, collar_top - 0.5]) cylinder(d = col_id, h = 0.1);
      translate([0, front_w + wire_d / 2, collar_top + 2]) cylinder(d = wire_d, h = 0.1);
    }
    if (closed) {   // one Y slit down the back: spread it, lay the wires in
      translate([0, boot_d + 1, 0]) rotate([90, 0, 0]) linear_extrude(boot_d + 1 - front_w - 1) slit_2d();
      translate([-0.75, cable_y, collar_bot - 1]) cube([1.5, col_od, collar_len + 2]);
    }
    else   // collar open at the back, a little narrower than the cable: it snaps in
      translate([-col_od, cable_y + 1, collar_bot - 1]) cube([2 * col_od, col_od, collar_len + 2]);
    // zip tie grooves round the collar
    for (z = [collar_bot + 3.5, collar_bot + collar_len - 4])
      translate([0, cable_y, z - (tie_w + 0.6) / 2]) difference() {
        cylinder(d = col_od + 2, h = tie_w + 0.6);
        translate([0, 0, -1]) cylinder(d = col_od - 0.8, h = tie_w + 3);
      }
  }
}

module cover() {
  intersection() { boot(); translate([-100, 0, -100]) cube(200); }   // flat front
  for (s = [-1, 1]) translate([s * plug_x, 0, 0]) plug(s);
}

module brick() {   // stand-in, for the "fitted" view
  difference() {
    translate([0, 0, 0]) linear_extrude(70) rrect(A, B, 5, 12);
    for (s = [-1, 1]) translate([s * plug_x - G / 2, -1, -1]) cube([G, E + 1, F + 1]);
  }
}

if (part == "cover") {
  rotate([90, 0, 0]) cover();   // front face down
}
if (part == "fitted") { color("white") brick(); color("lightblue") cover(); }
if (part == "view") color("lightblue") cover();

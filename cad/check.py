#!/usr/bin/env python3
"""Full fit check for the irrigation case: run before slicing anything.

    python3 cad/irrigation-case/check.py

1. The CAD's own asserts (a render of the box, base and lid stops on any failed assert).
2. Every pair of parts in their final places: an overlap fails; parts resting on each other
   (an overlap that is flat, zero thick) pass.
3. Every printed part is one piece: a part split in two (something floating) or a closed-off
   hole (an insert hole sealed by another feature shows up as a separate inner shell) fails.
4. The lid and the wiring cover swinging shut on their top hooks (several angles).
5. Every insertion path: each part (with what's mounted on it) moved straight in from the front,
   along z, must not hit what's already in the box. Parts that go in tilted are listed as such.

Stand-ins for bought parts: the A8 (board + 16 mm of parts), the converters, the screen (board
and parts behind it), the terminal strips. Exit status 1 if anything fails.
"""
import concurrent.futures as cf, os, re, struct, subprocess, sys, tempfile

HERE = os.path.dirname(os.path.abspath(__file__))
SCAD = os.path.join(HERE, "irrigation_case.scad")

PARTS = r'''
include <%s>
module P_box() box();
module P_base() translate([wall + 0.3, up_y0 + 0.3, back]) base();
module P_lid() translate([wall + 0.3, up_y0 + 0.3, D - lid_t]) lid();
module P_cover() translate([wall + 0.3, wall, D - cover_t]) wiring_cover();
module P_guard() translate([0, 0, back + strip12[2] + 1 - clip_clamp]) wire_guard();   // screwed down
module P_strips() { translate([x12 + 1.6 + strip_play / 2, strips_y + 1.6 + strip_play / 2, back + 1]) cube(strip12); translate([x5 + 1.6 + strip_play / 2, strips_y + 1.6 + strip_play / 2, back + 1]) cube(strip5); }
module P_a8() translate([a8_x0, a8_y0, back + base_t + standoff_h]) cube([a8_w, a8_h, 1.6 + 16]);
module P_conv() {
    translate([conv_x0 + (conv_w - eveps[0]) / 2, H - wall - 4 - eveps[1], back + base_t + rail_h]) cube(eveps);
    translate([conv_x0 + (conv_w - cpt[0]) / 2, up_y0 + 4, back + base_t + rail_h]) cube(cpt);
}
module P_screen() {
    zt = D - lid_t - scr_post_h;
    translate([scr_center[0] - scr_board[0] / 2, scr_y - scr_board[1] / 2, zt - 1.6 - 4.33]) cube([scr_board[0], scr_board[1], 1.6 + 4.33]);
}
module P_strip12() translate([x12 + 1.6 + strip_play / 2, strips_y + 1.6 + strip_play / 2, back + 1]) cube(strip12);
module P_strip5() translate([x5 + 1.6 + strip_play / 2, strips_y + 1.6 + strip_play / 2, back + 1]) cube(strip5);
module P_eveps() translate([conv_x0 + (conv_w - eveps[0]) / 2, H - wall - 4 - eveps[1], back + base_t + rail_h]) cube(eveps);
module P_cpt() translate([conv_x0 + (conv_w - cpt[0]) / 2, up_y0 + 4, back + base_t + rail_h]) cube(cpt);
// the lid and the wiring cover go on by their top hooks, then swing shut: turned by t degrees
// about their front top edge (bottom out)
module P_lid_swing(t) translate([0, H - wall - 0.3, D]) rotate([-t, 0, 0]) translate([0, -(H - wall - 0.3), -D]) P_lid();
module P_cover_swing(t) translate([0, wall + lower_h - 0.3, D]) rotate([-t, 0, 0]) translate([0, -(wall + lower_h - 0.3), -D]) P_cover();
// straight in from the front: everything over the part's outline, from its lowest point up
module sweep(z0) translate([0, 0, z0]) linear_extrude(3 * D) projection() children();
// lowered in shifted sideways by dx, then slid across into place at its own height
module dogleg(z0, dx) { translate([dx, 0, 0]) sweep(z0) children(); hull() { children(); translate([dx, 0, 0]) children(); } }
''' % SCAD

# (name, A, B): A and B must not overlap (resting on each other is fine)
PAIRS = [(a, b) for a, b in [
    ("box", "base"), ("box", "lid"), ("box", "cover"), ("box", "guard"), ("box", "strips"),
    ("box", "a8"), ("box", "conv"), ("box", "screen"),
    ("base", "lid"), ("base", "a8"), ("base", "conv"), ("base", "strips"),
    ("lid", "cover"), ("lid", "a8"), ("lid", "conv"), ("lid", "screen"),
    ("cover", "guard"), ("cover", "strips"),
    ("a8", "conv"), ("a8", "screen"), ("conv", "screen"), ("guard", "a8"),
]]

# insertion paths: what moves in (union of parts), what is already there, and a z floor below
# which contact is expected (the box's base-plate bosses go into the plate's back recesses)
# insertion paths: (name, moving part, how, already in place, z below which contact is expected)
# how: ("sweep", z0) straight in; ("dogleg", z0, dx) lowered shifted by dx, then slid into place
SWEEPS = [
    ("base plate, straight in", "base", ("sweep", "back"), ["box"], "back + base_boss_h + 0.01"),
    ("EVEPS onto the fitted plate (lowered 2.5 mm left, slid right under the ledge)", "eveps", ("dogleg", "back + base_t + rail_h", -2.5), ["box", "base"], "0"),
    ("CPT onto the fitted plate (lowered 2.5 mm left, slid right under the ledge)", "cpt", ("dogleg", "back + base_t + rail_h", -2.5), ["box", "base", "eveps"], "0"),
    ("A8 onto the plate after the converters (lowered 1.6 mm right, slid left under the ledge)", "a8", ("dogleg", "back + base_t + standoff_h", 1.6), ["box", "base", "conv"], "0"),
    ("12-strip into its tray", "strip12", ("sweep", "back + 1"), ["box"], "0"),
    ("5-strip into its tray", "strip5", ("sweep", "back + 1"), ["box"], "0"),
    ("wire guard onto the strips", "guard", ("sweep", "back + strip12[2] + 1 - clip_clamp"), ["box", "a8", "conv", "base"], "0"),
    ("screen (on the lid) in", "screen", ("sweep", "D - lid_t - scr_post_h - 1.6 - 4.33"), ["box", "base", "a8", "conv"], "0"),
]
# The lid and the wiring cover go on by their top hooks and swing shut: checked at these angles
# (degrees open), turned about their front top edge. Hooking on: tilted HOOK_TILT degrees, pushed up
# into the slots. (Past ~5 degrees the hooks leave their slots, so wider angles aren't a real path.)
SWING_ANGLES = [0.5, 1, 2, 3, 4]
HOOK_TILT = 3


PRINTED = ["box", "base", "lid", "wiring_cover", "wire_guard", "thumb_knob"]


def shells(path):
    """Separate pieces in an STL: [(triangles, bounding box)] (pieces sharing no vertex)."""
    data = open(path, "rb").read()
    if data[:5] == b"solid":
        tris = [tuple(re.findall(r"vertex\s+(\S+ \S+ \S+)", f)) for f in re.findall(r"outer loop(.*?)endloop", data.decode(), re.S)]
    else:
        n = struct.unpack("<I", data[80:84])[0]
        tris = [tuple("%g %g %g" % struct.unpack("<12f", data[84 + 50 * i: 132 + 50 * i])[3 + 3 * k: 6 + 3 * k] for k in range(3)) for i in range(n)]
    par = {}
    def root(a):
        while par.setdefault(a, a) != a:
            par[a] = par[par[a]]; a = par[a]
        return a
    for tr in tris:
        for v in tr[1:]:
            par[root(v)] = root(tr[0])
    groups = {}
    for tr in tris:
        groups.setdefault(root(tr[0]), []).append(tr)
    out = []
    for g in groups.values():
        P = [tuple(map(float, v.split())) for tr in g for v in tr]
        out.append((len(g), " ".join(f"{'xyz'[i]} {min(p[i] for p in P):.1f}..{max(p[i] for p in P):.1f}" for i in range(3))))
    return sorted(out, reverse=True)


def one_piece(part):
    name = f"one piece: {part}"
    with tempfile.TemporaryDirectory() as d:
        out = os.path.join(d, "p.stl")
        r = subprocess.run(["openscad", "-D", f'part="{part}"', "-o", out, SCAD], capture_output=True, text=True, timeout=900)
        if "ERROR" in r.stdout + r.stderr or not os.path.exists(out):
            return name, "FAIL", "did not render"
        s = shells(out)
    if len(s) == 1:
        return name, "ok", "one solid"
    return name, "FAIL", f"{len(s)} pieces; extra: " + "; ".join(b for _, b in s[1:])


def mod(n):
    return f"P_{n}()"


def run(name, body, render_only=False):
    with tempfile.TemporaryDirectory() as d:
        f = os.path.join(d, "c.scad"); out = os.path.join(d, "c.stl")
        open(f, "w").write(PARTS + body)
        r = subprocess.run(["openscad", "-D", 'part="none"', "-o", out, f], capture_output=True, text=True, timeout=900)
        log = r.stdout + r.stderr
        if "ERROR" in log:
            return name, "FAIL", next(l for l in log.splitlines() if "ERROR" in l)
        if render_only:
            return name, "ok", "renders, its asserts pass"
        v = [tuple(map(float, m)) for m in re.findall(r"vertex\s+(\S+)\s+(\S+)\s+(\S+)", open(out).read())] if os.path.exists(out) and os.path.getsize(out) else []
    if not v:
        return name, "ok", "clear"
    r = [(min(p[i] for p in v), max(p[i] for p in v)) for i in range(3)]
    span = " ".join(f"{'xyz'[i]} {lo:.1f}..{hi:.1f}" for i, (lo, hi) in enumerate(r))
    if any(hi - lo < 0.02 for lo, hi in r):
        return name, "ok", "resting on each other (" + span + ")"
    return name, "FAIL", "overlap " + span


def main():
    jobs = [(f"asserts: {p}", f"{m};\n", True) for p, m in
            [("box", "P_box()"), ("base", "P_base()"), ("lid", "P_lid()"), ("cover", "P_cover()"), ("wire guard", "P_guard()")]]
    for a, b in PAIRS:
        jobs.append((f"{a} / {b}", f"intersection() {{ {mod(a)}; {mod(b)}; }}\n", False))
    for name, moving, how, fixed, floor in SWEEPS:
        fx = " ".join(mod(x) + ";" for x in fixed)
        path = f"sweep({how[1]}) {mod(moving)};" if how[0] == "sweep" else f"dogleg({how[1]}, {how[2]}) {mod(moving)};"
        jobs.append((f"path: {name}", f"intersection() {{ union() {{ {path} }} union() {{ {fx} }} translate([-1, -1, {floor}]) cube([500, 500, 500]); }}\n", False))
    for part in ["lid", "cover"]:
        for a in SWING_ANGLES:
            jobs.append((f"swing: {part} shut on its hooks, {a} deg open", f"intersection() {{ P_box(); P_{part}_swing({a}); }}\n", False))
    # hooking on: tilted HOOK_TILT degrees, lifted up from below into the slots (every 0.25 mm)
    for part, rise in [("lid", 1.5), ("cover", 3.0)]:
        steps = " ".join(f"translate([0, {-0.25 * i:.2f}, 0]) P_{part}_swing({HOOK_TILT});" for i in range(int(rise / 0.25) + 1))
        jobs.append((f"hook on: {part} tilted {HOOK_TILT} deg, lifted {rise} mm into its slots", f"intersection() {{ P_box(); union() {{ {steps} }} }}\n", False))
    fails = 0
    tasks = [lambda j=j: run(*j) for j in jobs] + [lambda p=p: one_piece(p) for p in PRINTED]
    with cf.ThreadPoolExecutor(max_workers=os.cpu_count() or 4) as ex:
        for name, status, note in ex.map(lambda f: f(), tasks):
            fails += status == "FAIL"
            print(f"{'OK  ' if status == 'ok' else 'FAIL'}  {name}: {note}")
    print(f"\n{len(tasks)} checks, {fails} failed")
    sys.exit(1 if fails else 0)


if __name__ == "__main__":
    main()

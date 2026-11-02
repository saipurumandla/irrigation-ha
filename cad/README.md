# Irrigation controller case

OpenSCAD model of the case planned in [docs/irrigation-case.md](../../docs/irrigation-case.md).
Every size is a named value at the top of `irrigation_case.scad`.

    openscad -D 'part="test_inserts"' -o stl/test_inserts.stl irrigation_case.scad

Parts: `box`, `base` (the A8's plate, wire channels on its back), `lid` (screen), `wiring_cover`,
`power_cover`, and the test prints `test_inserts` (pick the heat-set insert hole) and `test_base`
(the A8's 4 standoffs on a thin plate: check the fit before the box). Previews: `assembly`,
`exploded`, `open` (covers off). STL output goes to `stl/` (not committed).

Estimates still to check on the real parts: the EVEPS height and the CPT's tabs. The screen is
measured (holes 92 x 45 mm, 3 mm; glass 4.07 mm above the board).

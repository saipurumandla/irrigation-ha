# Irrigation controller case

OpenSCAD model of the case planned in [docs/irrigation-case.md](../../docs/irrigation-case.md).
Every size is a named value at the top of `irrigation_case.scad`.

    openscad -D 'part="test_inserts"' -o stl/test_inserts.stl irrigation_case.scad

Parts: `box`, `base` (the A8's plate, wire channels on its back; 4 M3 screws into the box's
bosses), `lid` (screen), `wiring_cover`, `power_cover`, `clips` (the two strip clips, printed
lip up), and the test prints `test_inserts` (pick the heat-set insert hole) and `test_base`
(the A8's 4 standoffs on a thin plate: check the fit before the box). Previews: `assembly`,
`exploded`, `open` (covers off). STL output goes to `stl/` (not committed).

Two colours (beige PETG + a dark PETG for the labels): `lid`, `wiring_cover`, `power_cover` and
`clips` have their labels cut 0.6 mm in; `lid_labels`, `wiring_cover_labels`, `power_cover_labels`
and `clips_labels` are the inlays. In OrcaSlicer load a part and its labels together as one object
(it asks: "multi-part object" -> yes) and give the labels the 2nd filament. The labels: IRRIGATION,
Z1-Z8 COM RAIN, POWER outside; each terminal's name on the clips; the valve wire colours inside the
wiring cover.

Estimates still to check on the real parts: the EVEPS height and the CPT's tabs. The screen is
measured (holes 92 x 45 mm, 3 mm; glass 4.07 mm above the board).

Screws (M3 unless noted) and heat-set inserts (M3, 5 mm across: 8 x L6, 4 x L4; the hole from
`test_inserts`):
- Screen to the lid: 4 x M3 x 6, straight into its posts (2.7 mm holes).
- Base plate to the box: 4 x M3 x 8 into L4 inserts (heads sunk in the plate).
- Lid: 2 x M3 x 8 up through the shelf from the wiring bay, into L6 inserts in its flange posts.
- Power cover: 2 x M3 x 8 up through its lip, into L6 inserts under the box.
- Strip clips: 4 x M3 x 8 into the strip trays' L6 inserts.
- The A8: 4 x M2 into its standoffs (1.7 mm holes). Wall: 4 x #8 with anchors, through the keyholes.

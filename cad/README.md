# Irrigation controller case

OpenSCAD model of the case planned in [docs/irrigation-case.md](../../docs/irrigation-case.md).
Every size is a named value at the top of `irrigation_case.scad`; asserts there stop the build
if a screw, insert or plate lands in a wall or can't go in.

    openscad -D 'part="box"' -o stl/box.stl irrigation_case.scad

Parts: `box` (one wiring bay under the A8 section), `base` (the A8's plate, wire channels on its
back; 196.6 x 134.2 so it drops in past the lid's ledge), `lid` (screen), `wiring_cover` (one,
full width), `wire_guard` (over both terminal strips, names recessed, printed names down),
`thumb_knob`. Test pieces: `test_inserts`, `test_base`, `test_fits`, `test_screen`,
`test_strip_end`, `test_labels`. Previews: `assembly`, `exploded`, `open`. STL output goes to
`stl/` (not committed).

One colour (beige PETG). The front has no words: a water drop pressed into the lid and a line
framing the screen.

Measured: screen board 101.54 x 54.26, holes 94.46 x 47.96 c-c (3 mm), glass 4.07 above the
board; terminal strips 12.27 tall, 16.8 deep, 12-pos 109.5 long, the 5-pos (cut from a 12)
43.79; insert hole 4.2.

## Screws and inserts

Heat-set inserts M3, 5 mm across: L6 in the lid's 2 flange posts, the 4 wire-guard bosses and
the thumb-screw post (7); L4 in the box's 4 base-plate bosses (4).

| What | Screw | Into |
|---|---|---|
| Screen to the lid | 4 x M3 x 6 | its posts (2.7 mm, self-threading; 0.4 mm spare) |
| A8 to the base plate | 4 x M3 x 6 | its standoffs (2.7 mm, self-threading) |
| Base plate to the box | 4 x M3 x 8 (socket or button head) | L4 inserts in the box's bosses |
| Converters (EVEPS, CPT) | 4 x M3 x **6** + washers | M3 nuts slid into the nut rails (x 10 jams) |
| Wire guard | 4 x M3 x 8 | L6 inserts in the strip bosses (clamps the strips) |
| Lid | 2 x M3 x **10**, up through the shelf from the bay (stubby driver or L hex key) | L6 inserts in its flange posts |
| Wiring cover | hooks at the top; 1 x M3 x 10 socket screw pressed into `thumb_knob` | L6 insert in the post at the bottom |
| Wall | 4 x #8 + anchors | through the keyholes |

## Assembly order

Checked by `python3 check.py` (every part pair in place, every printed part one solid piece, these
insertion paths, and the lid and cover hooking on and swinging shut). Do it on
the table, the box lying on its back (the rails' nuts would slide out with the box upright).

1. Inserts: melt all 11 in (iron straight down each hole).
2. Wire the back of the base plate: lay the zone jumpers, rain pair and the 24 V AC pair in its
   back channels (they can't be fished through once the plate is in).
3. Base plate straight in, 4 screws (they're under the A8's footprint, so before the A8).
4. Nuts into the rails (slide them in at the CPT rail's lower end, up into the EVEPS rail).
   EVEPS: thread the 24 V AC pair up through the hole under it, lower it in 2-3 mm to the left
   and slide it right under the ledge, 2 screws. Then the CPT the same way.
5. A8: lower it in 1-2 mm to the right, slide it left under the ledge, 4 screws.
6. Strips into their trays, jumpers onto the upper row, wire guard on (4 screws).
7. 12 V EVEPS -> A8 power terminal -> CPT; 5 V CPT and the A8's S1/S2 -> screen cable, all in
   front of the plate.
8. Hang the box: wall screws through the keyholes (the 2 upper heads go into the plate's back
   pockets), slide it down.
9. Field wires on the strips' front row. Screen onto the lid, plug its cable, lid on: hooks into
   the top slots, 2 screws from the bay. Wiring cover on.

   Hooking the lid (and the cover) on: hold it tilted a few degrees, bottom out, about 1.5 mm
   (cover: 3 mm) lower than its place; push it up so the hooks go into their slots, then swing
   the bottom shut and screw it.

The box comes off the wall by lifting it (the keyhole heads slide down their slots).

# Irrigation controller case (plan)

A printed, wall-mounted box for the KC868-A8 that works like the Rain Bird it replaces: the
electronics are sealed at the top, and the bottom holds the terminals you wire. Runs from **one
plug**. Agreed 2026-10-31; sizes are estimates until the parts are measured. See
[irrigation.md](irrigation.md) for the controller itself.

![Case layout](irrigation-case-layout.svg)

## Layout (208 × 225 × 66 mm)

Confirmed 2026-11-02: A8 + screen across the top. **Changed 2026-11-03: one wiring bay** under it,
full width, one cover (it was a wiring bay and a screwed power bay). One print on the 260 mm bed.

| Part of the box | Holds | Opened |
|---|---|---|
| **Upper, sealed** | KC868-A8 on its base plate; the Hosyond screen on the lid, over the A8's **right half** (the A8's ESP32 antenna at the left end stays under plain plastic) | rarely: lid hooks over a lip at the top, held by 2 screws reached from the wiring bay |
| **Lower, WIRING (one bay)** | Both terminal strips in a row under the shelf: Z1-Z8, COM, COM 2, RAIN, RAIN, then 24V, 0V, FLOW+, SIG, GND (17). Valve wires in through the back wall; the transformer's cable through a PG7 gland under 24V / 0V; rain and flow cables through knockouts under their terminals. No Wagos. | often: one cover, hooks at the top, a thumb screw at the bottom |

- No screws on the front. Labels ("IRRIGATION", terminal names) printed in dark grey with the
  Kobra X's multi-colour.
- Jumpers from the terminals up to the A8 are wired once and **run behind the A8**: the A8 sits
  on a printed **base** whose back face has the wire channels; the box's back wall closes them.
  A long **slot through the base** runs along the relay edge, and another along the green blocks'
  edge opens into the bays, so a jumper goes from its relay screw through the slot, down its
  channel, and out next to its terminal. Nothing shows in front, beside or behind
  the board. Adds about 8 mm of depth. All 8 zones, COM and power are pre-wired now, so the
  channels never need opening. Ends marked Z1… with heat-shrink or tape.
- The **screen cable** (4 wires: 5 V and GND from the CPT, plus TX/RX to two of the A8's sensor terminals)
  gets its own channel in the base too, from the POWER bay up the right edge to just behind the
  screen, then a short slack loop to a plug, so the lid lifts off after unplugging one connector.
- The screen talks to the A8 **directly over that wire (UART)**, not through Home Assistant or
  Wi-Fi: it shows the A8's status and sends its commands (run zone, stop, rain delay), and keeps
  working with Wi-Fi or HA down. HA still sees the A8 as before. Pins: see Wire channels.

## Power: one plug

```
outlet → Centropower PSU-40 (24 V AC 40 VA, auto-reset PTC; plugs in, 120 V stays in it)
          24V / 0V screws → 18/2 thermostat wire → gland under the 24V / 0V terminals
  24V terminal: transformer on the outer screw; inner screw: relay COM1 (COM1-COM5 jumpered)
                + EVEPS AC in (up the right channel)
  0V terminal:  transformer on the outer screw; inner screw: COM (linked to COM 2) + EVEPS AC in
  EVEPS out (yellow +, black −) → A8 +12V / GND; from the same A8 terminals on to the CPT in
  CPT out (5 V) → screen 5 V / GND (and FLOW+ / GND for a flow sensor later)
```
As built (2026-11-05) the splits are **Wagos** instead (the GYVRM's leads were too short for the
strip): Wago 1 (+12 V: GYVRM yellow, A8 +12V, CPT in +), Wago 2 (GND: GYVRM black, A8 GND, CPT in
−), Wagos 3 / 4 (GYVRM AC in, fed from the strip's 24V / 0V inner screws). See "As built" below.

- **EVEPS:** yellow is **+**, black is **−**. Check both converters with the meter on DC before
  connecting (12 V and 5 V) and the transformer's no-load voltage on AC (EVEPS takes up to 28 V).
- No fuse: the transformer's PTC protects it. No fan, no temperature probe (about 6 W in total).
- Load: under 1 A of the transformer's 1.6 A; the A8 + screen draw under 1 A of the EVEPS's 3 A.

## Terminals

Decided 2026-11-02: only a **rain sensor** and a **flow sensor** (for water used per zone; maybe a
ZJ-B10S, later) come in from outside, so 12 + 5 positions as below. 12 V, 5 V and 3.3 V stay inside
at the A8 and the converters. The transformer is a Class 2 plug-in doorbell transformer (24 V AC 40 VA,
auto-reset): two wires, no ground needed. No speaker in the lid.

| WIRING (left) | | POWER (right) | |
|---|---|---|---|
| Z1-Z8 | zone wires → relay NO1-NO8 | 24V, 0V | transformer |
| COM | white valve common → 0V | FLOW+, SIG, GND | flow sensor, later (5 V supply) |
| COM 2 | second common, spare | | |
| RAIN, RAIN | rain sensor, later → an input + GND | | |

Relay screws read **NC - COM - NO** left to right with the orange block at the top, and **relay 1
is at the left end** (Ethernet port side); zone jumpers go on **NO**.

Both sides use the GUBCUB screw strips, cut to length (12 positions on the WIRING side, 5 on the
POWER side), screwed down through their own mounting holes. On each strip a small printed
**clip** covers the upper row (the jumpers to the A8), so only the screws you wire are exposed.

## Wire channels (behind the A8)

![Wire channels](irrigation-case-channels.svg)

| Run | From → to | Route |
|---|---|---|
| Zone trunk (8 wires) | relay NO1-NO8 (relay 1 at the left end) → WIRING Z1-Z8 | through the long slot above the relay row → the base plate's back channel along the top → down the left edge → the left pass-through into the bay → the strip's upper row (under the wire guard) |
| 24 V feed (1) + EVEPS AC in (2) | 24V terminal (inner screw) → relay COM8; 24V / 0V terminals → EVEPS | up the right channel (it comes down right over 24V / 0V); COM1-COM8 jumpered on the front |
| 12 V (2) | EVEPS out → A8 +12V / GND, then on to the CPT from the same terminals | in front of the base plate (the gap beside the A8 is only ~2.5 mm) |
| Screen cable (4) | CPT 5 V + GND, A8 sensor terminals GPIO14/GPIO13 (TX/RX) → screen | in front of the base plate (the CPT sits beside the A8), up to the screen's socket with a slack loop; no hole (review 2026-11-03) |
| Rain (2) | WIRING RAIN → A8 **IN8** + the input block's GND (as built) | the left pass-through and the back channel, out through the long slot along the green blocks |
| Common (1) | 0V terminal (inner screw) → COM, COM linked to COM 2 | short jumpers along the strips, in the bay |

- Base about 10 mm thick, grooves about 7 mm deep; zone trunk about 12 mm wide, the right trunk
  about 10 mm. Holes 4 mm, chamfered so insulation isn't cut. Hole rows are placed from the A8's
  measured screw positions.
- **Screen link pins (KC868-A8, per the ESPHome device page):** the 1-wire/sensor terminals are
  terminals **S1** (DS18B20, GPIO14) and **S2** (DHT, GPIO13) for UART TX/RX to the screen, **S3**
  (GPIO32) for the flow sensor, **S4** (GPIO33) spare, all on the green 6-pin block GND / S1 / S2 /
  S3 / S4 / Vcc. Vcc measures **3.27 V** (the 3.3 V rail): fine for 3.3 V sensors, not for
  the screen. The flow sensor runs on 5 V from the POWER bay, so its signal needs a divider
  (5 V → 3.3 V) before S3. Not the board's S1/S2 *buttons* (reset and
  function key), which share the names. Confirm the terminal labels before wiring. Avoid the 433 MHz pins
  (GPIO2, GPIO15: boot strapping pins) and the I2C port P19 (SDA/SCL/GND/3V3: it carries the relay
  and input chips).

## Air and cables

- Vents: straight 3 mm slots: under the bays, low on both sides of the A8 section, and on top. No
  louvres (decided 2026-11-02): the user adds a mesh inside if dust or insects get in. Screen backlight off after 1 minute idle.
- The valve wires (18 AWG, loose) come **out of the wall** behind the controller (a punched hole the
  Rain Bird sits over, size unknown): a **50 x 35 mm opening in the back of the WIRING bay**, rounded,
  with a rim for a grommet or brush strip; any wall hole behind the bay lines up. No gland for them.
- The transformer (bought, plugs into an outlet) comes from outside: its wire enters the **bottom
  of the POWER bay** through a **PG7** gland.
- Spare **knockouts** (thin printed discs to pop out) on the bottom for later cables (flow sensor).
  None on top.
- Transformer: printed **terminal clip** covers its two screws and holds the cable; the cable runs
  up the wall in paintable raceway. Wire: solid 18 AWG, hooked clockwise under the screws.

## Printed parts (PETG, white or light grey, no supports)

| # | Part |
|---|---|
| P1 | box (upper + both lower bays, one piece) |
| P2 | lid with the screen window |
| P3 | WIRING slide-down cover |
| P4 | POWER cover (2 screws) |
| P5 | transformer terminal clip |
| P6 | A8 base: wire channels on its back, pass-through holes at the relay row and the bays |
| P7 | terminal strip clips (cover the strips' upper row) |
| — | test strip: insert holes 3.9 / 4.0 / 4.1 / 4.2 mm, to pick the fit |

0.4 mm nozzle, 0.2 mm layers, 4 walls, 25% gyroid. Threads: M3 brass heat-set inserts
(M3 × 4 × 5 for lids and covers, M3 × 6 × 5 for posts), soldering iron at about 240 °C; nut
pockets are a fallback. Wall: #8 screws and anchors through keyholes in the back.

## Parts

All ordered or in hand (2026-10-31): Centropower PSU-40, EVEPS EV36-A121203, CPT C1205003,
GUBCUB terminal strips, M3 screw kit, M3 heat-set inserts, Hosyond ESP32-S3 3.5" screen, PG
gland pack, wall screws and anchors, PETG, soldering iron, ferrules (twin for two wires under one screw), 18/2 thermostat wire,
heat-shrink.

## Measured (KC868-A8, 2026-11-02, calipers; orange relay block at the top)

| What | Inches | mm |
|---|---|---|
| Board, left-right | 5 | 127.0 |
| Board, top-bottom | 4.35 | 110.5 |
| Overall left-right, with what sticks out | 6 | 152.4 |
| H1-H4: half holes (open at the edge), one per corner, centre from the edge | 0.1 | 2.5 |
| H5 (full hole, on the corner flap): from left / from top | 0.1 / 0.54 | 2.5 / 13.7 |
| H6 (full hole): from left / from top | 2.715 / 0.7 | 69.0 / 17.8 |
| H7 (full hole): from right / from top (= 3.5" / 88.9 mm from left) | 1.5 / 1.8 | 38.1 / 45.7 |
| 2.25" on the sketch: straight part of the right edge between the corner notches (to confirm) | 2.25 | 57.2 |

**From the "Kincony KC868-A8 Rail Mount" model (Printables 6665458; STL files kept by the user,
not in the repo), which fits the board:**
- Base plate (Grundplatte.stl): 152.2 x 110.2 mm, 4.4 mm thick; the measured outline.
- The board's 4 screws: standoffs Ø8 mm, 2.4 mm tall on the 2 mm plate (that gap clears the
  solder leads under the board, checked by the user), each with a Ø2.0 mm hole (self-tapping M2 /
  M2.5 into plastic), at (from the plate's left, from its top) 13.6 / 7.5, 139.1 / 7.5, 42.4 / 61.8 and
  68.9 / 89.8 mm. These win over the hand measurements of H5-H7 above.
- Its enclosure (Gehause_1.stl) stands 46.4 mm out from the plate: everything on the board fits
  in about 42 mm above it. Enough for the planned 66 mm box.

Test print (PLA, 2026-11-02): the A8's 4 holes line up with the standoffs, relays up. The terminal
strip was a little tight in its tray (exact size); the user wants a press fit so it can't wiggle:
the original exact-size tray (0 play; 0.1 looked loose), walls 2 mm (higher covers the strip's
wire holes), plus the clamping clip. The PG7 gland fits its
hole; the keyholes are fine (the user's screws fit). Its holes
pass M3 freely, so it's screwed with M3 (the model uses only M3).

Relay terminals (user, 2026-11-02): 24 screws 5.0 mm apart, the row centred along the relay
edge (between the corner half holes), about 10.5 mm in from that edge; the orange block is flush
with the edge (doesn't stick out); the board is 1.6 mm thick.

**Other parts (2026-11-02):**
- GUBCUB screw strip (seller's drawing): 12 positions 109.5 mm long, about 9.1 mm apart, 16.8 mm
  deep (wire in to wire out), 14.0 mm to the top of the screw towers, base 7.9 mm, wire hole 2.5
  mm; a mounting hole in the web between every two positions (M3). WIRING bay: the full 12
  (about 110 mm); POWER bay: 5 positions (about 46 mm).
- WAGO 221-413: about 18.7 x 18.6 x 8.3 mm (distributors' data); they sit loose in the power bay,
  held by their wires (no holder).
- Glands (combo set), thread for the holes: PG7 12.5, PG9 15.2, PG11 18.6, PG13.5 20.4 mm.
  The valve wires come out of the wall into the back of the box (no gland for them).
- M3 heat-set inserts (a set): hole size from the test strip.
- EVEPS EV36-A121203 (seller's drawing): 70 mm over its two slotted mounting tabs x 40 mm; height
  not given (about 20-22 mm, use 22 until measured); all four wires leave one long side; input
  10-28 V AC (check the transformer's no-load voltage first: the Rain Bird's read 28.8-29.3 V).
- CPT C1205003 (seller's drawing): body 46 x 27 x 14 mm, slotted tabs at both short ends (about
  58 mm over them, to confirm), all four wires leave one long side, leads about 13.5 cm.
- Hosyond screen, measured (2026-11-02/03): board 101.54 x 54.26 mm, 10 mm deep with the parts
  behind; holes **94.46 x 47.96 mm** centre to centre (calipers 2026-11-03: outer edges 97.45 / 51.0,
  inner 91.47 / 44.91, holes 3.0 mm; the published cases' 89.7 x 51.2 are for another board and the
  v2 test was 4.8 mm off; **screen test v3 fits**, 2026-11-03: posts line up, picture centred, glass against the lid), 3 mm (M3 self-tapping into the lid's posts); 5.67 mm
  board + glass (glass 4.07 above the board; the test print left a gap over 0.8 mm with 4.4 mm
  posts, so posts 3.5: the glass rests against the lid); picture 73.4 x 49.0 centred (window 76 x
  51). One socket, UART (5V GND TXD RXD), on the bottom edge carries the A8 link and its power;
  USB-C and RESET/BOOT on the end opposite the mic (reached with the lid open).
- Hosyond ESP32-S3 3.5" screen (seller's picture, before it arrived): board 100 x 54 mm, a mounting hole in each
  corner about 3 mm in from the edges; the glass spans about 9.5-92 mm along the board, visible
  area about 74 x 49 mm (lid window about 76 x 51 mm); mic hole on the left end; comes with a
  speaker, an SH1.25-to-Dupont 4-wire cable (the A8 link) and USB-C. Thickness not given: 15 mm
  until measured. Speaker grille in the lid: to decide.
- Still to measure on arrival: the EVEPS height, the screen's thickness and hole size; the wall space and the
  distance to the outlet.

**Decided 2026-11-02: no exact terminal positions.** Wires pass behind the board through one
long slot along the relay edge and one along the green blocks' edge (not a hole per screw), so
only the footprint, the 4 standoffs and the height (42 mm) have to be exact. The A8 is wired with
the lid open; anything can be changed later by opening it.

## Needed before modelling

1. Base plate: length × width, hole positions and diameter.
2. KC868-A8: tallest part above the board.
3. Screen: outer size, thickness, visible area, hole positions; a photo of the back (for drivers).
4. Converters and the Centropower's bottom end (width × depth, screw spacing): measured on arrival.
5. Valve cable thickness (gland size).

## Where it stands (2026-11-02)

Modelled in `cad/` (OpenSCAD; README there lists parts and screws). Test prints:
- PLA: the A8's standoffs line up (relays up); the terminal strip fits its tray (now a 0.1 mm press
  fit, 2 mm walls); the PG7 gland fits; keyholes fine.
- PETG (2026-11-02): insert hole **4.2 mm** is the best fit (goes in nicely, M3 holds). Nut rail
  works: nuts slide in, don't turn, a converter tightened down doesn't move. Screen fit: printing.

Final plates (PETG, "Hearth case - strong", one-bay version, sliced 2026-11-03): 1 box 11 h 23 /
305 g; 2 base plate 5 h 38 / 123 g; 3 lid 2 h 31 / 66 g; 4 wiring cover + thumb knob 1 h 31 / 40 g;
5 wire guard (replaces the 2 clips, 2026-11-03: one piece over both strips' upper rows and the band up to the shelf, hiding the jumpers; the 17 names recessed above the front-row screws; the strips' 4 bosses, M3) on the base plate's plate. About 21.5 h, 541 g. No supports. Big flat parts (box, base,
lid, cover): bed 85 C, 10 mm brim, fan off for 5 layers then max 30%.

Marks: the water drop and the 1.2 mm window line are pressed 0.6 mm into the lid's face (the lid
prints face down: raised marks there, or printing it face up, would need supports under the whole
face plate). The terminal names on the clips are black inlays (`clips.stl+clips_labels.stl`).
OrcaSlicer 2.4.2's command line crashes (139) when a part exported turned over (lid, covers) goes
through its assemble list, so those stay one colour, and the clips are a plate of their own.

Fixes after the first full box (2026-11-03): the strip clips' screw bosses (9 mm, 6 mm past the
tray ends) landed half inside the bay walls (the 12-strip leaves only ~6 mm at each end; the
5-strip sat 4 mm from the divider). Now 7 mm bosses, centres 3.5 mm from the wall (fused to it,
insert hole 1.4 mm clear), clip screws 2.5 mm past the tray ends, the 5-strip moved to the same
6 mm from the divider; asserts in the CAD fail if a clip insert hole comes within 1 mm of a wall.
The strip trays were very tight in PETG: 0.3 mm clearance now (the clip clamps the strip). The
first box also warped (the front edge lifted ~5 mm; keyholes and A8 area flat): reprint with
bed 85 C, 10 mm brim, fan off for 5 layers then max 30%, washed bed + glue stick. Test piece:
`test_strip_end` (bay wall, tray end, boss, clip end; ~27 min).

Also 2026-11-03: the base plate's back has a 5 mm pocket (slot-shaped, along the keyhole) over
each high keyhole for the wall screw's head, instead of a 14 mm hole through: the through hole at
(20, 200) cut the A8's top-left standoff away. The box hangs first, then the plate goes in; the
box comes off the wall by lifting it (heads slide down the slots), plate and all.

Strip-end test (2026-11-03): tray 0.3 mm clearance was a little wiggly, now 0.15 (0 was very
tight). Measured over the test piece's back: terminal top 16.27, pillar top 17.47, so the strips
are 12.27 mm tall (not the seller's 14) and the pillars stood 1.2 mm above them: the guard wouldn't
clamp. strip height now 12.27, pillars 0.6 below the strips' top again (15.67). The 5-strip is 5 positions cut from a 12-strip: 43.79 mm long (was 46).

Independent review + collision checks (2026-11-03), fixed before the final prints: the lid's
ledge had a bottom side under the lid's flange and screw posts (lid couldn't seat) - now top and
sides only; the lid's top hooks were in the lid's plane and hit the top wall - now behind the plate,
through notches in the top ledge into the wall slots; the flange stops 3.3 mm short of the side
ledges; the base plate's screen-cable hole (under the A8, no channel) removed - the screen cable
runs in front; the converter hole no longer cuts the EVEPS rail's nut channel; the base plate
bosses' insert holes 1 mm deeper (an M3 x 8 bottomed out); lid screws moved to 42 mm from each
side (their heads were 0.25 mm under the cover's hooks); 45-degree slopes under the cover's rest
strips; the frame line clear of the mic hole; screen screw holes 1.3 mm into the lid (M3 x 6 fits).
Collision checks (OpenSCAD intersections): lid/box only touching, cover/box, guard/box, base/box,
cover/lid clear. Lid screws need a stubby driver or an L hex key. A8 screws: M3 x 6.
Final plates: 1 base + wire guard + knob 6 h 16 / 133 g; 2 lid + cover 3 h 54 / 104 g; 3 box
11 h 12 / 302 g (overnight). About 21.5 h, 539 g.

Second review (2026-11-03), fixed: the base plate (202.6 x 137.2) was bigger than the opening
inside the lid's ledge (197.2 x 134.8): now 196.6 x 134.2, it drops straight in (checked by
sweeping it along z against the box; everything on it keeps its place); converter screws M3 x 6
(x 10 jammed into the plate under the nut); lid hooks 0.3 mm behind the plate and their slots
0.5 mm taller (room to tilt in and out); base screw heads sink 3.1 mm (flush socket heads); the
frame line 0.9 mm clear of the mic hole. Assembly order and the screw table: cad/README.md.
Full check: `python3 cad/check.py` (asserts, 22 part pairs in place, 8 insertion
paths: the converters and the A8 slide under the ledge after the plate is in; run before slicing).

**Next:** print the final plates (lid + cover, then base + wire guard + knob, then the box overnight) and assemble in the order in cad/README.md.
a USB stick.

## Steps

1. Measure (above). 2. Model in OpenSCAD (parametric) and send a preview. 3. Print the insert test
strip and a thin back-plate test fit. 4. Print P1-P5. 5. Assemble and wire, switch from the Rain
Bird to the Centropower, run each zone for a minute.


## As built (2026-11-05)

Assembled, wired and tested on the bench; **not hung yet, and the valves are still on the Rain
Bird** until the switch-over.

- **Converters swapped:** the CPT (12 → 5 V) on the top rail, the GYVRM / EVEPS (24 V AC → 12 V) on
  the bottom one. The real converters are smaller than the CAD stand-ins (EVEPS/GYVRM about
  40 x 70 x 22, CPT about 27 x 58 x 14), so the plate goes in with them already on. The GYVRM's
  wire side is ~4 mm from the right wall: its leads bend down along the body.
- **Wagos** (4) beside the converters, as listed under Power. Measured: transformer 27 V AC,
  GYVRM 12.13 V DC, CPT 5 V DC.
- **Feed:** strip 24V inner → relay 8 C (all C jumpered); **common:** strip 0V inner → COM → COM 2.
  Zone wires on relay **NO**.
- **Rain:** the two RAIN screws go to **IN8** and that block's GND (on the mounted board the input
  numbering runs the other way from KinCony's picture). In the A8's settings, rain sensor input =
  Input 8 when a sensor is fitted.
- **Flow:** SIG → A8 **S3**, flow GND → the sensor block's GND; **FLOW+ empty** until the sensor is
  chosen (a Rain Bird FG100 is two-wire; whether it needs power is tested when it arrives).
- **Screen cable:** screen 5V / GND → CPT out, screen RXD → A8 **S1** (GPIO14), TXD → **S2**
  (GPIO13); the grounds are common (checked). Firmware and link: [irrigation-screen.md](irrigation-screen.md).
- **Tests passed:** relays 1-8 one at a time (twice, 27.67 V AC at the active zone), restart (no
  clicks, all off, Idle after ~20 s waiting for the clock), rain input (shorting RAIN turns IN8 on).

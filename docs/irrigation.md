# Irrigation controller (KinCony KC868-A8)

Replaces the Rain Bird ESP-TM2 + LNK2 in the garage. Firmware: `esphome/irrigation.yaml`
(schedule logic in `esphome/irrigation/irrigation_core.h`, tested by
`esphome/irrigation/core.test.ts`, which `npx vitest run` builds with g++ and runs).

The board runs the schedule itself: watering continues without Wi-Fi or Home Assistant, the
clock comes from the internet (SNTP), and every setting is kept on the board. Home Assistant is
where settings are changed; Hearth will read and edit them there.

## Hardware notes

- **Board:** KC868-A8 **V1.7.1**, ESP32, relays on a PCF8574 at **0x24**, inputs on one at
  **0x22** (I2C SDA GPIO4 / SCL GPIO5; confirmed by the boot scan).
- **Flashing over USB needs both:** a **USB-A to USB-C** cable (C-to-C isn't detected: the board
  can't ask a C port for power) **and the 12 V supply connected** (USB doesn't power the board).
  It shows up as a CH340 (`/dev/ttyUSB0`). After the first flash, updates go over Wi-Fi:
  `esphome upload irrigation.yaml --device <ip>`.
- **Power:** +12 V on the left screw of the far-left 2-pin block, GND on the right.
- **Relays:** each has NO / C / NC; zones use C and NO. Mounted with the orange block at the top,
  each relay's screws read **NC - COM - NO** left to right, and **relay 1 is at the left end, the
  Ethernet port's side** (checked on the board 2026-10-31; KinCony's product diagram numbers them
  the other way round, so go by the board). The zone wire goes on the screw **right** of COM. A zone
  wire on NC waters whenever the relay is off (found 2026-10-31: every zone came on at once).
- **Inputs (9-pin block):** a contact between an input and the block's GND turns it on.
  Tested 2026-10-29 on IN8; the input numbers in HA match the board's labels.
- **Wi-Fi:** -48 to -50 dBm on the bench (IoT SSID). Never reboots for lack of Wi-Fi or HA, since a
  reboot would stop a running zone.

## Wiring (from the Rain Bird, photographed 2026-10-28)

| Rain Bird terminal | Wire | Goes to on the A8 |
|---|---|---|
| 1 | red | relay 1 NO (Left front) |
| 2 | blue | relay 2 NO (Drip) |
| 3 | yellow | relay 3 NO (Sides) |
| 4 | green | relay 4 NO (Back) |
| 5 | black | relay 5 NO (Right front) |
| C | white (valve common) | 24 V AC leg 2 (Wago) |
| — | — | 24 V AC leg 1 to C of relays 1-5, jumpered |
| SENS | yellow jumper | nothing: no rain sensor |
| M | empty | no master valve |

Spare coiled conductors (brown and others) in the valve cable can serve a rain or flow sensor
later. 24 V AC: from the Rain Bird's 24VAC screws for now (it stays plugged in, schedule off), or a
24 V AC 40 VA plug-in transformer once the Rain Bird is removed.

## Settings (all Home Assistant entities on the "Irrigation" device)

- **Zones 1-8:** the zone's switch (on runs it for its *minutes by hand*, off stops it), enabled,
  minutes by hand, max minutes (hard cap), cycle and soak minutes, last run.
- **Programs A-D:** on/off, day mode (days of the week, every N days, odd dates, even dates),
  days ("Mon, Wed, Sat", "daily", "weekdays"), start times (up to 4: "5:00, 18:30" or "5am"),
  every N days (counts from the day it's set), minutes per zone (0 = not in the program),
  *Run program*.
- **By hand:** *Zones to run* ("1, 3, 5", "2-4", "all") + *Minutes each* (0 = each zone's own) +
  *Run selected zones*; *Run all zones*; *Next zone*; *Stop*. By hand ignores the schedule, rain
  delay and rain sensor; the caps still hold.
- **Adjustments:** seasonal adjust %, monthly adjust (12 numbers, Jan-Dec; overrides seasonal),
  rain delay (days; counts down), skip next run, gap between zones (s).
- **Watering rules:** off / warn / block, allowed days, no-water hours ("10:00-16:00"), max minutes
  per zone; water source (potable / well / reclaimed, for presets; this house is reclaimed).
- **Hardware:** master valve or pump (any relay; that zone isn't watered itself), rain sensor
  input (any) and type (normally closed / open).
- **Status:** status, last event, schedule problems ("OK" or what's wrong), active zone, time
  remaining, next run, Wi-Fi signal, uptime, inputs 1-8.

Safety, always: one zone at a time, every relay off after a restart, and a zone open past its cap
(+2 min) is closed even if the sequencer were wrong.

## Bench test, 2026-10-29 (no valves connected)

| Test | Result |
|---|---|
| First flash over USB-C (A-to-C cable, 12 V on) | Pass |
| I2C scan: 0x22 and 0x24 | Pass |
| Wi-Fi join, clock set | Pass (first join attempt failed, second connected) |
| Update over Wi-Fi | Pass (7 s) |
| Program A at 17:21, zones 1-5 × 1 min, 5 s gap | Pass: 17:21:02 → 17:26:21, in order, one at a time, stopped itself |
| Run selected "1, 3" → Next zone → Stop | Pass |
| Relays 6, 7, 8 on and off from HA | Pass |
| Rain delay 1 day, Program A at 17:31 | Pass: "Program A skipped: rain delay", nothing ran |
| Input IN8 to GND | Pass: input 8 on, then off |

Found and fixed during the test: "Zone N stopped by hand" logged for every zone at boot; last-run
and next-run times rounded to about 2 minutes (they're now exact text timestamps).

Afterwards the test settings were cleared (Program A off and empty, rain delay 0, gap 2 s) and the
integration was **disabled in HA** until the controller is installed
(`inventory/changes/2026-10-29-irrigation-disable.json`; re-enable with `"disabled": false`).

## Garage test, 2026-10-31 (valves connected)

24 V AC from the Rain Bird's **HOT** screw (28.8-29.3 V to C with no valve on; the Rain Bird must
be plugged in, dial on OFF) to COM1-COM5, valve common still on the Rain Bird's C. Zones 1-5 run
by hand one at a time (1 min, then 20 s each): **all five watered the area their name says.**
Two wiring slips on the way: the Rain Bird unplugged (relay clicked, no water), and the zone
wires on NC (every zone came on at once while the board was idle).

Afterwards (2026-10-31) the valves went **back on the Rain Bird** until the case is built; the A8
is unpowered and its integration **disabled in HA** again.

## Still to do

1. The Rain Bird's current schedule (programs, days, start times, minutes per zone, seasonal %),
   copied here and loaded onto the board.
2. More scheduling features before install (repeating and sunrise/sunset starts, program date
   ranges, odd/even on top of weekdays, per-program seasonal on/off, per-zone ignore-rain,
   pause/resume, master valve timing, program button on an input, soil-moisture skip).
3. Printed case and one-plug power: planned in [irrigation-case.md](irrigation-case.md).
4. Later: flow sensor on the reclaimed main line, weather-based adjust from HA.

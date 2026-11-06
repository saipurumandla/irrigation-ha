# Irrigation screen

The touch screen in the irrigation case's lid: an LCDWIKI **ES3C35P** (sold by Hosyond; the listing
says "240x320", the board is 320x480). Firmware: `esphome/irrigation-screen.yaml`, with
`esphome/screen/` (the A8 link client, UI helpers, history) and `esphome/components/st77922_qspi`
(the display driver). It talks to the A8 over a cable, not through Wi-Fi or HA, so it keeps working
with the router or HA down; the A8 stays the one source of truth and HA sees every change.

## Board

ESP32-S3 (8 MB PSRAM, 16 MB flash, native USB-C), 3.5" IPS 320x480, **ST77922** over QSPI, with the
ST77922's own (Sitronix) touch on I2C 0x55. Pins (spec V1.0 and the schematic in the user manual):

| | GPIO |
|---|---|
| LCD CS / CLK / D0-D3 | 10 / 12 / 11, 13, 14, 9 |
| LCD TE (tearing effect) | 42 |
| Backlight (high = on, PWM) | 41 |
| Touch SDA / SCL / INT | 38 / 39 / 47 |
| **Reset of the whole ST77922** (display and touch) | **48** |
| UART socket (5V GND TXD RXD) = UART0 | TX 43, RX 44 |
| Audio amp enable (low = on; kept off) | 1 |
| Spare (socket) | 45, 46 |

The factory firmware is backed up at `~/esp-backups/es3c35p-screen-factory-2026-11-05.bin` (full
16 MB; restore with `esptool write-flash 0 <file>`).

## The display: what it took (2026-11-05)

ESPHome's `mipi_spi` woke the panel but never showed an image. All four of these were needed:

1. **GPIO48 resets the whole chip**, not just touch. Without it driven the chip stays in reset;
   pulsed by the touch driver after the display was set up, it wiped the display. The display
   driver now resets it first, and the touchscreen (ESPHome's `st7123`) has **no** reset pin.
2. **The seller's own init table** (63 commands), read out of the factory firmware: Espressif's
   default table (written for a 532x300 panel) shows nothing on this one.
3. **Whole frames, one stream:** the ST77922 keeps the frame compressed, so partial writes leave
   streaks. The driver keeps a frame copy in PSRAM and sends all of it from the top-left: one
   window, then RAMWR (2Ch) for the first band and RAMWRC (3Ch, "write continue") for the rest,
   synced to TE.
4. **A real reset after flashing over USB:** a software restart doesn't reset the panel (unplug,
   or the driver's GPIO48 reset).

Hence `components/st77922_qspi`: a small ESPHome display that drives Espressif's
`esp_lcd_st77922` with the seller's table (`es3c35p_init.h`).

## The link to the A8

UART at 115200, one text line per message ending `*XX` (XOR checksum; bad lines are dropped).
Protocol in `esphome/irrigation/a8_link.h`:

- A8 → screen: `N <key> <name>` and `S <key> <value>` for **every entity** (all on `SYNC`, then
  each change), `Z <n> <key>` (which switch is zone n), `H <uptime> <seconds left>` once a second.
- Screen → A8: `SYNC`, `SET <key> <value>`, `PRESS <key>`, `WIFI <ssid>\t<password>`.

Keys are `<domain>.<object_id>`. The screen holds only a copy; nothing on the screen is an A8
setting of its own, so a new A8 setting shows up on the screen without a protocol change.

## Apps (light theme; a launcher, no tabs)

- **Home:** date and time, link and Wi-Fi icons; NEXT RUN (big day, small time) or WATERING with an
  m:ss countdown; a status pill whose icon says what the garden is doing (sprout by day, moon at
  night, umbrella for rain delay, skip). Tap the pill for quick actions (rain delay 1 / 3 days,
  clear, skip next run). A flow box appears once the A8 has a flow sensor.
- **Zones:** tiles; a zone page to run it by hand (minutes, then a countdown and Stop); its settings
  in plain words (enabled, longest run, water in bursts of / pause between bursts) and rename.
- **Schedule:** programs A-D with Rain Bird's words: watering days Custom / Cyclic / Odd / Even, up to
  four start times (scroll wheels), run times per zone, seasonal adjust.
- **History:** the last 7 days as bars stacked by zone; tap a day for minutes and start times per
  zone. Recorded **by the screen** from the A8's live zone states (kept in its flash); runs while
  the screen is off or unlinked aren't seen.
- **Settings** (behind a PIN, default **0000**, set or reset under Screen; stored on the screen only):
  Setup (zones on / off and names, rain sensor input and type, master valve, water source; flow
  sensor later), Wi-Fi (pick a network; the A8 joins it too), Watering (rain delay, skip, gap,
  watering rules), Screen (dim / off timeouts, day hours, day and night brightness, PIN), About.

The black strip on the left (the panel's picture is off-centre in its glass, so it balances the
black edge at the top and right) is a hidden brightness control: slide up or down. Backlight:
day / night levels, dim after 30 s, off after 60 s, any touch wakes it.

## Updating

Over Wi-Fi: `esphome run irrigation-screen.yaml --device irrigation-screen.local`. Over USB-C (A to
C cable), with the 4-pin cable to the A8 unplugged so the screen isn't powered from both.

# Irrigation controller for Home Assistant

Everything the irrigation controller's screen can do, from Home Assistant. It sits on top of the
ESPHome irrigation firmware (KinCony KC868-A8) and uses that device's own entities.

What it adds:

- **Zone names everywhere.** Rename a zone on the screen (or with `rename_zone`) and every entity
  of that zone gets the name in HA: "Back Bed", "Back Bed enabled", "Back Bed minutes by hand",
  "Program A Back Bed minutes"... Entity ids don't change. There's also an "Apply zone names"
  button. An empty name puts the firmware's name back.
- **Actions:** `run_zone` (zone by number or name, minutes), `run_zones`, `stop`, `rename_zone`,
  `set_program` (on/off, which days, start times, minutes per zone, in one go),
  `sync_zone_names`, `get_history` (every run and minutes per zone).
- **History:** a "watered last 7 days" sensor per zone, with today, per day and the last runs as
  attributes, from HA's own records.

## What's in here

- `custom_components/irrigation_controller/`: the Home Assistant integration
- `firmware/`: ESPHome firmware for the A8 (`irrigation.yaml`) and its touch screen
  (`irrigation-screen.yaml`, ES3C35P), with the screen's display driver in `components/`.
  Put your Wi-Fi and keys in `firmware/secrets.yaml` (not in git).
- `cad/`: OpenSCAD case, transformer boot and wall template, with ready STLs in `cad/stl/`
- `docs/`: how it's wired and built

## Install

Copy `custom_components/irrigation_controller` into HA's `config/custom_components/`, restart
HA, then Settings → Devices & services → Add integration → "Irrigation controller" and pick the
controller.

## Tests

```
python -m venv .venv && .venv/bin/pip install -r requirements_test.txt
.venv/bin/pytest
```

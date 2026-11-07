"""Irrigation controller: what the controller's screen can do, from Home Assistant.

Works on top of the ESPHome irrigation firmware (KinCony A8): it finds that device's entities
and adds zone renames that reach every entity, one-step actions (run a zone for some minutes,
run several zones, stop, set a whole program, rename a zone) and watering history.
"""

from __future__ import annotations

from datetime import timedelta
from typing import Any

import voluptuous as vol

from homeassistant.config_entries import ConfigEntry
from homeassistant.const import Platform
from homeassistant.core import HomeAssistant, ServiceCall, ServiceResponse, SupportsResponse
from homeassistant.exceptions import ServiceValidationError
from homeassistant.helpers import config_validation as cv
from homeassistant.util import dt as dt_util

from . import logic
from .const import DOMAIN, PROGRAMS
from .controller import Controller

PLATFORMS = [Platform.BUTTON, Platform.SENSOR]

type IrrigationConfigEntry = ConfigEntry[Controller]

ZONE = vol.Any(vol.Coerce(int), cv.string)
BASE = {vol.Optional("device_id"): cv.string}

SCHEMAS = {
    "run_zone": vol.Schema({**BASE, vol.Required("zone"): ZONE, vol.Optional("minutes"): vol.All(vol.Coerce(int), vol.Range(1, 240))}),
    "run_zones": vol.Schema({**BASE, vol.Required("zones"): vol.All(cv.ensure_list, [ZONE]), vol.Optional("minutes"): vol.All(vol.Coerce(int), vol.Range(0, 240))}),
    "stop": vol.Schema(BASE),
    "rename_zone": vol.Schema({**BASE, vol.Required("zone"): ZONE, vol.Required("name"): vol.All(cv.string, vol.Length(max=20))}),
    "set_program": vol.Schema({
        **BASE,
        vol.Required("program"): vol.All(cv.string, vol.Upper, vol.In(PROGRAMS)),
        vol.Optional("enabled"): cv.boolean,
        vol.Optional("day_mode"): cv.string,
        vol.Optional("days"): vol.Any(cv.string, [cv.string]),
        vol.Optional("every_n_days"): vol.All(vol.Coerce(int), vol.Range(1, 30)),
        vol.Optional("starts_in"): vol.All(vol.Coerce(int), vol.Range(0, 29)),
        vol.Optional("start_times"): vol.Any(cv.string, [cv.string]),
        vol.Optional("minutes"): {ZONE: vol.All(vol.Coerce(int), vol.Range(0, 240))},
    }),
    "sync_zone_names": vol.Schema(BASE),
    "get_history": vol.Schema({**BASE, vol.Optional("days", default=7): vol.All(vol.Coerce(int), vol.Range(1, 30))}),
}


async def async_setup_entry(hass: HomeAssistant, entry: IrrigationConfigEntry) -> bool:
    controller = Controller(hass, entry)
    entry.runtime_data = controller
    await controller.async_start()
    await hass.config_entries.async_forward_entry_setups(entry, PLATFORMS)
    _register_services(hass)
    return True


async def async_unload_entry(hass: HomeAssistant, entry: IrrigationConfigEntry) -> bool:
    entry.runtime_data.async_stop()
    return await hass.config_entries.async_unload_platforms(entry, PLATFORMS)


def _controller(hass: HomeAssistant, call: ServiceCall) -> Controller:
    loaded = [e.runtime_data for e in hass.config_entries.async_loaded_entries(DOMAIN)]
    want = call.data.get("device_id")
    if want:
        hit = [c for c in loaded if c.device_id == want]
        if not hit:
            raise ServiceValidationError("That device isn't an irrigation controller set up here")
        return hit[0]
    if len(loaded) == 1:
        return loaded[0]
    raise ServiceValidationError("More than one controller: say which one with device_id" if loaded else "No irrigation controller is set up")


def _register_services(hass: HomeAssistant) -> None:
    if hass.services.has_service(DOMAIN, "run_zone"):
        return

    async def run_zone(call: ServiceCall) -> None:
        await _controller(hass, call).run_zone(call.data["zone"], call.data.get("minutes"))

    async def run_zones(call: ServiceCall) -> None:
        await _controller(hass, call).run_zones(call.data["zones"], call.data.get("minutes"))

    async def stop(call: ServiceCall) -> None:
        await _controller(hass, call).stop()

    async def rename_zone(call: ServiceCall) -> None:
        await _controller(hass, call).rename_zone(call.data["zone"], call.data["name"])

    async def set_program(call: ServiceCall) -> None:
        data = {k: v for k, v in call.data.items() if k not in ("device_id", "program")}
        await _controller(hass, call).set_program(call.data["program"], data)

    async def sync_zone_names(call: ServiceCall) -> ServiceResponse:
        return {"renamed": await _controller(hass, call).async_sync_names()}

    async def get_history(call: ServiceCall) -> ServiceResponse:
        c = _controller(hass, call)
        days = call.data["days"]
        runs = await c.history(days)
        out: list[dict[str, Any]] = []
        totals: dict[str, float] = {}
        for n, rs in runs.items():
            name = c.zone_label(n)
            start = dt_util.start_of_local_day() - timedelta(days=days - 1)
            totals[name] = logic.minutes_between(rs, start, dt_util.utcnow())
            for s, e in rs:
                if e > start:
                    out.append({"zone": n, "name": name, "start": dt_util.as_local(s).isoformat(), "end": dt_util.as_local(e).isoformat(), "minutes": round((e - s).total_seconds() / 60, 1)})
        out.sort(key=lambda r: r["start"])
        return {"runs": out, "minutes_per_zone": totals}

    for name, fn in [("run_zone", run_zone), ("run_zones", run_zones), ("stop", stop), ("rename_zone", rename_zone), ("set_program", set_program)]:
        hass.services.async_register(DOMAIN, name, fn, schema=SCHEMAS[name])
    hass.services.async_register(DOMAIN, "sync_zone_names", sync_zone_names, schema=SCHEMAS["sync_zone_names"], supports_response=SupportsResponse.OPTIONAL)
    hass.services.async_register(DOMAIN, "get_history", get_history, schema=SCHEMAS["get_history"], supports_response=SupportsResponse.ONLY)

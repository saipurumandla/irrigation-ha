"""One irrigation controller (the ESPHome device): finds its entities and drives them."""

from __future__ import annotations

import asyncio
import logging
from datetime import datetime, timedelta
from typing import Any

from homeassistant.config_entries import ConfigEntry
from homeassistant.core import Event, EventStateChangedData, HomeAssistant, callback
from homeassistant.exceptions import HomeAssistantError, ServiceValidationError
from homeassistant.helpers import device_registry as dr, entity_registry as er
from homeassistant.helpers.dispatcher import async_dispatcher_send
from homeassistant.helpers.event import async_track_state_change_event
from homeassistant.util import dt as dt_util, slugify

from . import logic
from .const import CONF_DEVICE_ID, DOMAIN, OPT_ZONES, PROGRAMS

_LOGGER = logging.getLogger(__name__)
SIGNAL_UPDATE = f"{DOMAIN}_update_{{}}"


class Controller:
    """Everything the screen can do, as calls on the controller's own entities."""

    def __init__(self, hass: HomeAssistant, entry: ConfigEntry) -> None:
        self.hass = hass
        self.entry = entry
        self.device_id: str = entry.data[CONF_DEVICE_ID]
        self.entries: list[logic.Entry] = []
        self._by_name: dict[tuple[str, str], str] = {}
        self._unsub: list[Any] = []
        self._syncing = False
        self._zone_unsub: Any = None

    # ---- the device and its entities -------------------------------------------------

    @property
    def device(self) -> dr.DeviceEntry | None:
        return dr.async_get(self.hass).async_get(self.device_id)

    @property
    def device_name(self) -> str:
        d = self.device
        return (d.name_by_user or d.name or "") if d else ""

    @callback
    def refresh(self) -> None:
        """Re-read the device's entities from the registry."""
        reg = er.async_get(self.hass)
        self.entries = [
            logic.Entry(e.entity_id, e.original_name or "", e.name)
            for e in er.async_entries_for_device(reg, self.device_id, include_disabled_entities=True)
            if e.platform == "esphome"
        ]
        self._by_name = {(e.domain, e.original_name): e.entity_id for e in self.entries}

    def entity(self, domain: str, original_name: str) -> str:
        """The entity id of the firmware entity with this name."""
        eid = self._by_name.get((domain, original_name))
        if eid is None:
            raise HomeAssistantError(f"The controller has no {domain} called {original_name!r}")
        return eid

    def opt(self, domain: str, original_name: str) -> str | None:
        """The entity id, or None when this firmware doesn't have it."""
        return self._by_name.get((domain, original_name))

    def entity_map(self) -> dict:
        """Every entity a dashboard needs, by what it is (for Hearth and cards)."""
        reg = er.async_get(self.hass)

        def own(key: str) -> str | None:
            return reg.async_get_entity_id("sensor", DOMAIN, f"{self.device_id}_{key}")

        zones = []
        for n in sorted(self.zone_of()):
            base = self.zone_of()[n]
            zones.append({
                "zone": n,
                "name": self.zone_label(n),
                "switch": self.opt("switch", base),
                "enabled": self.opt("switch", f"{base} enabled"),
                "minutes": self.opt("number", f"{base} minutes by hand"),
                "last_run": self.opt("sensor", f"{base} last run"),
                "name_text": self.opt("text", f"Zone {n} name"),
                "watered": own(f"zone_{n}_watered_7_days"),
            })
        programs = []
        for p in PROGRAMS:
            if not self.opt("switch", f"Program {p}"):
                continue
            programs.append({
                "program": p,
                "switch": self.opt("switch", f"Program {p}"),
                "run": self.opt("button", f"Run program {p}"),
                "day_mode": self.opt("select", f"Program {p} day mode"),
                "days": self.opt("text", f"Program {p} days"),
                "every_n_days": self.opt("number", f"Program {p} every N days"),
                "starts_in": self.opt("number", f"Program {p} starts in"),
                "start_times": self.opt("text", f"Program {p} start times"),
                "minutes": {str(z["zone"]): self.opt("number", f"Program {p} zone {z['zone']} minutes") for z in zones},
            })
        names = {
            "status": ("sensor", "Status"), "next_run": ("sensor", "Next run"), "time_remaining": ("sensor", "Time remaining"),
            "active_zone": ("sensor", "Active zone"), "last_event": ("sensor", "Last event"), "problems": ("sensor", "Schedule problems"),
            "stop": ("button", "Stop"), "next_zone": ("button", "Next zone"), "skip_next_run": ("switch", "Skip next run"),
            "rain_delay": ("number", "Rain delay"), "seasonal_adjust": ("number", "Seasonal adjust"),
            "rain_sensor": ("binary_sensor", "Rain sensor"), "rain_sensor_input": ("select", "Rain sensor input"),
        }
        return {"zones": zones, "programs": programs, "controls": {k: self.opt(*v) for k, v in names.items()}}

    def state(self, domain: str, original_name: str) -> str:
        s = self.hass.states.get(self.entity(domain, original_name))
        return s.state if s else "unavailable"

    @property
    def zone_count(self) -> int:
        return sum(1 for e in self.entries if e.domain == "text" and logic.ZONE_TEXT.match(e.original_name))

    def zone_names(self) -> dict[int, str]:
        """Zone number -> its name as set on the screen (or in HA)."""
        out = {}
        for e in self.entries:
            if e.domain == "text" and (m := logic.ZONE_TEXT.match(e.original_name)):
                s = self.hass.states.get(e.entity_id)
                out[int(m.group(1))] = s.state if s else "unavailable"
        return dict(sorted(out.items()))

    def zone_label(self, n: int) -> str:
        v = self.zone_names().get(n, "")
        return v if v not in logic.BAD else f"Zone {n}"

    async def async_start(self) -> None:
        self.refresh()
        await self.async_sync_names()  # also works out which zone is which, the first time
        texts = [e.entity_id for e in self.entries if e.domain == "text" and logic.ZONE_TEXT.match(e.original_name)]

        @callback
        def names_changed(event: Event[EventStateChangedData]) -> None:
            new = event.data["new_state"]
            if new is None or new.state in ("unknown", "unavailable"):
                return
            self.hass.async_create_task(self.async_sync_names())

        self._unsub.append(async_track_state_change_event(self.hass, texts, names_changed))
        self._track_zones()

    @callback
    def _track_zones(self) -> None:
        """Follow the zone switches (again after their ids move)."""
        if self._zone_unsub:
            self._zone_unsub()
            self._zone_unsub = None
        zone_of = self.zone_of()
        switches = [x for n, base in zone_of.items() for x in (self.opt("switch", base), self.opt("switch", f"{base} enabled")) if x]

        @callback
        def zone_changed(event: Event[EventStateChangedData]) -> None:
            async_dispatcher_send(self.hass, SIGNAL_UPDATE.format(self.entry.entry_id))

        if switches:
            self._zone_unsub = async_track_state_change_event(self.hass, switches, zone_changed)

    @callback
    def async_stop(self) -> None:
        for u in self._unsub:
            u()
        self._unsub.clear()
        if self._zone_unsub:
            self._zone_unsub()
            self._zone_unsub = None

    # ---- zones: which firmware zone is which ------------------------------------------

    def zone_of(self) -> dict[int, str]:
        """Zone number -> firmware name, as worked out and saved (empty until then)."""
        saved = self.entry.options.get(OPT_ZONES, {})
        return {int(k): v for k, v in saved.items()}

    def zone_switch(self, n: int) -> str:
        base = self.zone_of().get(n)
        if base is None:
            raise HomeAssistantError(f"Zone {n} isn't matched to the controller's zones yet")
        return self.entity("switch", base)

    def zone_entity(self, n: int, domain: str, suffix: str) -> str:
        base = self.zone_of().get(n)
        if base is None:
            raise HomeAssistantError(f"Zone {n} isn't matched to the controller's zones yet")
        return self.entity(domain, base + suffix)

    async def _async_match_zones(self) -> tuple[dict[int, str], list[str]]:
        values = self.zone_names()
        bases, suffixes = logic.zone_bases(self.entries, len(values))
        if not bases:
            return {}, []
        saved = self.zone_of()
        if saved and set(saved.values()) <= set(bases) and len(saved) == len(bases):
            return saved, suffixes
        first = {}
        quick = logic.match_zones(values, self.entries, bases, {}, self.device_name)
        need = [n for n in values if n not in quick]
        if need:
            first = await self._first_names(need)
        zone_of = logic.match_zones(values, self.entries, bases, first, self.device_name)
        if len(zone_of) == len(bases):
            self.hass.config_entries.async_update_entry(
                self.entry, options={**self.entry.options, OPT_ZONES: {str(k): v for k, v in zone_of.items()}}
            )
        else:
            _LOGGER.warning("Couldn't tell which zone is which (%s of %s matched)", len(zone_of), len(bases))
        return zone_of, suffixes

    async def _first_names(self, zones: list[int]) -> dict[int, str]:
        """Each zone's first good name in HA's history (for zones renamed before this was installed)."""
        if "recorder" not in self.hass.config.components:
            return {}
        from homeassistant.components.recorder import get_instance, history

        ids = {n: self.entity("text", f"Zone {n} name") for n in zones}
        now = dt_util.utcnow()
        found = await get_instance(self.hass).async_add_executor_job(
            lambda: history.get_significant_states(
                self.hass, now - timedelta(days=30), now, list(ids.values()), significant_changes_only=False
            )
        )
        out = {}
        for n, eid in ids.items():
            good = next((s.state for s in found.get(eid, []) if s.state not in logic.BAD), None)
            if good:
                out[n] = good
        return out

    # ---- zone names -> entity names ----------------------------------------------------

    async def async_sync_names(self) -> int:
        """Give each zone's entities its current name. Returns how many were renamed."""
        if self._syncing:
            return 0
        self._syncing = True
        try:
            self.refresh()
            values = self.zone_names()
            if not values or any(v == "unavailable" for v in values.values()):
                return 0  # the controller is offline: wait for it
            zone_of, suffixes = await self._async_match_zones()
            plan = logic.plan_names(values, self.entries, zone_of, suffixes, self.device_name)
            reg = er.async_get(self.hass)
            for eid, name in plan.items():
                reg.async_update_entity(eid, name=name)
                _LOGGER.debug("Renamed %s to %s", eid, name)
            moved = await self._sync_ids(zone_of, suffixes)
            if plan or moved:
                self.refresh()
            if moved:
                self._track_zones()
            async_dispatcher_send(self.hass, SIGNAL_UPDATE.format(self.entry.entry_id))
            return len(plan) + moved
        finally:
            self._syncing = False

    async def _sync_ids(self, zone_of: dict[int, str], suffixes: list[str]) -> int:
        """Give each zone's entities zone-numbered ids. Two steps, so ids can trade places."""
        reg = er.async_get(self.hass)
        watered = {}
        for e in er.async_entries_for_config_entry(reg, self.entry.entry_id):
            n = e.unique_id.removesuffix("_watered_7_days").rsplit("_zone_", 1)[-1]
            if e.unique_id.endswith("_watered_7_days") and n.isdigit() and self.hass.states.get(e.entity_id):
                watered[int(n)] = e.entity_id  # only once it's running: a sensor still being added keeps its id
        plan = logic.plan_ids(self.entries, zone_of, suffixes, self.device_name, slugify, watered)
        # Leave alone anything whose new id is held by an entity that isn't moving.
        while bad := [a for a, b in plan.items() if b not in plan and reg.async_get(b)]:
            for a in bad:
                _LOGGER.warning("Can't move %s to %s: that id is taken", a, plan.pop(a))
        # One rename per entity where the new id is free: a running entity follows one rename,
        # not two in a row. Only ids that trade places go through a temporary id, with a pause.
        todo = dict(plan)
        while free := [a for a, b in todo.items() if not reg.async_get(b)]:
            for a in free:
                reg.async_update_entity(a, new_entity_id=todo.pop(a))
                _LOGGER.info("Entity id now %s", plan[a])
        temp = {}
        for i, (old, new) in enumerate(todo.items()):
            t = f"{new.split('.', 1)[0]}.{DOMAIN}_moving_{i}"
            reg.async_update_entity(old, new_entity_id=t)
            temp[t] = new
        if temp:
            await asyncio.sleep(2)  # let each entity move to its temporary id first
        for t, new in temp.items():
            reg.async_update_entity(t, new_entity_id=new)
            _LOGGER.info("Entity id now %s", new)
        return len(plan)

    # ---- actions -------------------------------------------------------------------------

    def _zone(self, zone: int | str) -> int:
        try:
            return logic.zone_number(zone, self.zone_names())
        except ValueError as err:
            raise ServiceValidationError(str(err)) from err

    async def _call(self, domain: str, service: str, entity_id: str, **data: Any) -> None:
        await self.hass.services.async_call(domain, service, {"entity_id": entity_id, **data}, blocking=True)

    async def run_zone(self, zone: int | str, minutes: int | None) -> None:
        n = self._zone(zone)
        if minutes is not None:
            await self._call("number", "set_value", self.zone_entity(n, "number", " minutes by hand"), value=minutes)
        await self._call("switch", "turn_on", self.zone_switch(n))

    async def run_zones(self, zones: list[int | str], minutes: int | None) -> None:
        picked = [self._zone(z) for z in zones]
        await self._call("text", "set_value", self.entity("text", "Zones to run"), value=", ".join(map(str, picked)) or "all")
        await self._call("number", "set_value", self.entity("number", "Minutes each"), value=minutes or 0)
        await self._call("button", "press", self.entity("button", "Run selected zones"))

    async def stop(self) -> None:
        await self._call("button", "press", self.entity("button", "Stop"))

    async def rename_zone(self, zone: int | str, name: str) -> None:
        n = self._zone(zone)
        await self._call("text", "set_value", self.entity("text", f"Zone {n} name"), value=name.strip())
        await self.async_sync_names()

    async def set_program(self, program: str, data: dict[str, Any]) -> None:
        p = program.upper()
        try:
            if "enabled" in data:
                await self._call("switch", "turn_on" if data["enabled"] else "turn_off", self.entity("switch", f"Program {p}"))
            if "day_mode" in data:
                await self._call("select", "select_option", self.entity("select", f"Program {p} day mode"), option=logic.day_mode(data["day_mode"]))
            if "days" in data:
                await self._call("text", "set_value", self.entity("text", f"Program {p} days"), value=logic.days_text(data["days"]))
            if "every_n_days" in data:
                await self._call("number", "set_value", self.entity("number", f"Program {p} every N days"), value=data["every_n_days"])
            if "starts_in" in data:  # after every_n_days: the controller keeps it under N
                await self._call("number", "set_value", self.entity("number", f"Program {p} starts in"), value=data["starts_in"])
            if "start_times" in data:
                await self._call("text", "set_value", self.entity("text", f"Program {p} start times"), value=logic.times_text(data["start_times"]))
            for zone, minutes in (data.get("minutes") or {}).items():
                n = self._zone(zone)
                await self._call("number", "set_value", self.entity("number", f"Program {p} zone {n} minutes"), value=minutes)
        except ValueError as err:
            raise ServiceValidationError(str(err)) from err

    # ---- history -----------------------------------------------------------------------

    async def history(self, days: int) -> dict[int, list[tuple[datetime, datetime]]]:
        """Zone number -> its runs over the last `days` days, from HA's own records."""
        zone_of = self.zone_of()
        if not zone_of or "recorder" not in self.hass.config.components:
            return {}
        from homeassistant.components.recorder import get_instance, history

        ids = {n: self.zone_switch(n) for n in zone_of}
        now = dt_util.utcnow()
        start = dt_util.start_of_local_day() - timedelta(days=days - 1)
        found = await get_instance(self.hass).async_add_executor_job(
            lambda: history.get_significant_states(
                self.hass, start, now, list(ids.values()), significant_changes_only=False, include_start_time_state=True
            )
        )
        return {
            n: logic.runs([(s.last_changed, s.state) for s in found.get(eid, [])], now)
            for n, eid in ids.items()
        }

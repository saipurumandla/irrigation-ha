"""Watering history per zone, from HA's own records of the zone switches."""

from __future__ import annotations

from datetime import timedelta

from homeassistant.components.sensor import SensorEntity, SensorStateClass
from homeassistant.const import UnitOfTime
from homeassistant.core import HomeAssistant
from homeassistant.helpers.entity_platform import AddConfigEntryEntitiesCallback
from homeassistant.helpers.event import async_track_time_interval
from homeassistant.util import dt as dt_util

from . import IrrigationConfigEntry, logic
from .entity import IrrigationEntity

DAYS = 7


async def async_setup_entry(hass: HomeAssistant, entry: IrrigationConfigEntry, add: AddConfigEntryEntitiesCallback) -> None:
    c = entry.runtime_data
    add([Watered(c, n) for n in sorted(c.zone_of())], update_before_add=True)


class Watered(IrrigationEntity, SensorEntity):
    """Minutes a zone watered in the last 7 days; today, per day and recent runs as attributes."""

    _attr_icon = "mdi:sprinkler-variant"
    _attr_native_unit_of_measurement = UnitOfTime.MINUTES
    _attr_state_class = SensorStateClass.MEASUREMENT

    def __init__(self, controller, zone: int) -> None:
        super().__init__(controller, f"zone_{zone}_watered_7_days")
        self.zone = zone

    @property
    def name(self) -> str:
        return f"{self.controller.zone_label(self.zone)} watered last 7 days"

    async def async_added_to_hass(self) -> None:
        await super().async_added_to_hass()
        # The day rolls over even when nothing waters.
        self.async_on_remove(async_track_time_interval(self.hass, self._updated, timedelta(minutes=15)))

    async def async_update(self) -> None:
        runs = (await self.controller.history(DAYS)).get(self.zone, [])
        now = dt_util.utcnow()
        today = dt_util.start_of_local_day()
        start = today - timedelta(days=DAYS - 1)
        self._attr_native_value = logic.minutes_between(runs, start, now)
        per_day = {}
        for i in range(DAYS):
            a = today - timedelta(days=i)
            per_day[a.date().isoformat()] = logic.minutes_between(runs, a, a + timedelta(days=1))
        self._attr_extra_state_attributes = {
            "zone": self.zone,
            "today": per_day[today.date().isoformat()],
            "per_day": per_day,
            "last_runs": [
                {"start": dt_util.as_local(s).isoformat(), "minutes": round((e - s).total_seconds() / 60, 1)}
                for s, e in runs[-10:]
                if e > start
            ],
        }

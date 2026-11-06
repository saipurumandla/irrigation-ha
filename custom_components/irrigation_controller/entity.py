"""Shared bits for this integration's entities: they sit on the controller's own device."""

from __future__ import annotations

from homeassistant.core import callback
from homeassistant.helpers.device_registry import DeviceInfo
from homeassistant.helpers.dispatcher import async_dispatcher_connect
from homeassistant.helpers.entity import Entity

from .controller import SIGNAL_UPDATE, Controller


class IrrigationEntity(Entity):
    _attr_has_entity_name = True
    _attr_should_poll = False

    def __init__(self, controller: Controller, key: str) -> None:
        self.controller = controller
        self._attr_unique_id = f"{controller.device_id}_{key}"
        dev = controller.device
        self._attr_device_info = DeviceInfo(connections=dev.connections, identifiers=dev.identifiers) if dev else None

    async def async_added_to_hass(self) -> None:
        self.async_on_remove(
            async_dispatcher_connect(self.hass, SIGNAL_UPDATE.format(self.controller.entry.entry_id), self._updated)
        )

    @callback
    def _updated(self, *_: object) -> None:
        self.async_schedule_update_ha_state(True)

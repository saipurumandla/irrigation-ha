"""Button: apply the zone names to every zone entity (it also happens by itself on a rename)."""

from __future__ import annotations

from homeassistant.components.button import ButtonEntity
from homeassistant.const import EntityCategory
from homeassistant.core import HomeAssistant
from homeassistant.helpers.entity_platform import AddConfigEntryEntitiesCallback

from . import IrrigationConfigEntry
from .entity import IrrigationEntity


async def async_setup_entry(hass: HomeAssistant, entry: IrrigationConfigEntry, add: AddConfigEntryEntitiesCallback) -> None:
    add([ApplyNames(entry.runtime_data)])


class ApplyNames(IrrigationEntity, ButtonEntity):
    _attr_name = "Apply zone names"
    _attr_icon = "mdi:rename-outline"
    _attr_entity_category = EntityCategory.CONFIG

    def __init__(self, controller) -> None:
        super().__init__(controller, "apply_zone_names")

    async def async_press(self) -> None:
        await self.controller.async_sync_names()

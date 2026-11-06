"""Set up: pick the ESPHome irrigation controller."""

from __future__ import annotations

from typing import Any

import voluptuous as vol

from homeassistant.config_entries import ConfigFlow, ConfigFlowResult
from homeassistant.helpers import device_registry as dr, entity_registry as er
from homeassistant.helpers.selector import SelectOptionDict, SelectSelector, SelectSelectorConfig

from .const import CONF_DEVICE_ID, DOMAIN


def controllers(hass) -> dict[str, str]:
    """ESPHome devices running the irrigation firmware: device id -> name."""
    ents = er.async_get(hass)
    devs = dr.async_get(hass)
    found: dict[str, str] = {}
    for e in ents.entities.values():
        if e.platform == "esphome" and e.device_id and e.original_name == "Zone 1 name" and e.entity_id.startswith("text."):
            has_stop = any(
                x.original_name == "Stop" and x.entity_id.startswith("button.")
                for x in er.async_entries_for_device(ents, e.device_id)
            )
            d = devs.async_get(e.device_id)
            if has_stop and d:
                found[e.device_id] = d.name_by_user or d.name or e.device_id
    return found


class IrrigationConfigFlow(ConfigFlow, domain=DOMAIN):
    VERSION = 1

    async def async_step_user(self, user_input: dict[str, Any] | None = None) -> ConfigFlowResult:
        found = controllers(self.hass)
        taken = {e.data[CONF_DEVICE_ID] for e in self._async_current_entries()}
        free = {k: v for k, v in found.items() if k not in taken}
        if not free:
            return self.async_abort(reason="no_controllers" if not found else "already_configured")
        if user_input is not None:
            device_id = user_input[CONF_DEVICE_ID]
            await self.async_set_unique_id(device_id)
            self._abort_if_unique_id_configured()
            return self.async_create_entry(title=free[device_id], data={CONF_DEVICE_ID: device_id})
        options = [SelectOptionDict(value=k, label=v) for k, v in free.items()]
        return self.async_show_form(
            step_id="user",
            data_schema=vol.Schema({
                vol.Required(CONF_DEVICE_ID, default=options[0]["value"]): SelectSelector(SelectSelectorConfig(options=options)),
            }),
        )

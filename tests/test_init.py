"""The integration in a real (test) Home Assistant, on a fake ESPHome controller."""

from homeassistant.core import HomeAssistant, ServiceCall
from homeassistant.helpers import device_registry as dr, entity_registry as er
from pytest_homeassistant_custom_component.common import MockConfigEntry

from custom_components.irrigation_controller.const import DOMAIN

MAC = "8c:8c:29:cd:10:90"
ZONES = ["Left front", "Drip", "Sides"]
NAMES = ["Left front", "Drip Front", "Back Bed"]
FAKES = {}
ZONE_SUFFIX = {"": "switch", " enabled": "switch", " minutes by hand": "number"}


def slug(s):
    return s.lower().replace(" ", "_")


async def setup_controller(hass: HomeAssistant):
    """A fake ESPHome irrigation controller: device, entities, states; and recorded service calls."""
    esp = MockConfigEntry(domain="esphome", title="irrigation")
    esp.add_to_hass(hass)
    dev = dr.async_get(hass).async_get_or_create(
        config_entry_id=esp.entry_id, connections={(dr.CONNECTION_NETWORK_MAC, MAC)}, name="Irrigation"
    )
    reg = er.async_get(hass)

    def add(domain, name, state):
        e = reg.async_get_or_create(
            domain, "esphome", f"{MAC}/0/{domain}/{name}", device_id=dev.id, config_entry=esp,
            original_name=name, has_entity_name=True, suggested_object_id=f"irrigation_{slug(name)}",
        )
        hass.states.async_set(e.entity_id, state)
        return e.entity_id

    for i, base in enumerate(ZONES, 1):
        for s, d in ZONE_SUFFIX.items():
            add(d, base + s, "off" if d == "switch" else "10")
        add("text", f"Zone {i} name", NAMES[i - 1])
        for p in "AB":
            add("number", f"Program {p} zone {i} minutes", "0")
    add("button", "Stop", "unknown")
    add("button", "Run selected zones", "unknown")
    add("text", "Zones to run", "all")
    add("number", "Minutes each", "0")
    for p in "AB":
        add("switch", f"Program {p}", "off")
        add("select", f"Program {p} day mode", "Days of the week")
        add("text", f"Program {p} days", "")
        add("text", f"Program {p} start times", "")
        add("number", f"Program {p} every N days", "2")

    calls = []

    async def record(call: ServiceCall):
        calls.append((call.domain, call.service, dict(call.data)))

    def fake_services():
        for d, s in [("number", "set_value"), ("text", "set_value"), ("switch", "turn_on"), ("switch", "turn_off"), ("button", "press"), ("select", "select_option")]:
            hass.services.async_register(d, s, record)

    fake_services()
    FAKES[dev.id] = fake_services  # again after setup: loading our button platform brings the real button.press
    return dev, calls


async def add_entry(hass, dev):
    entry = MockConfigEntry(domain=DOMAIN, data={"device_id": dev.id}, unique_id=dev.id, title="Irrigation")
    entry.add_to_hass(hass)
    assert await hass.config_entries.async_setup(entry.entry_id)
    await hass.async_block_till_done()
    FAKES[dev.id]()
    return entry


async def test_setup_finds_zones_and_renames(hass: HomeAssistant):
    dev, _ = await setup_controller(hass)
    hass.states.async_set("text.irrigation_zone_2_name", "Drip")  # zone 2 not renamed yet
    entry = await add_entry(hass, dev)
    # Zone 3 was renamed before: the last one left is Sides.
    assert entry.options["zones"] == {"1": "Left front", "2": "Drip", "3": "Sides"}
    reg = er.async_get(hass)
    assert reg.async_get("switch.irrigation_sides").name == "Irrigation Back Bed"
    assert reg.async_get("number.irrigation_sides_minutes_by_hand").name == "Irrigation Back Bed minutes by hand"
    assert reg.async_get("number.irrigation_program_b_zone_3_minutes").name == "Irrigation Program B Back Bed minutes"
    assert reg.async_get("switch.irrigation_drip").name is None

    # A rename on the screen reaches HA by itself.
    hass.states.async_set("text.irrigation_zone_2_name", "Drip Front")
    await hass.async_block_till_done()
    assert reg.async_get("switch.irrigation_drip_enabled").name == "Irrigation Drip Front enabled"

    # And an empty name puts the firmware's back.
    hass.states.async_set("text.irrigation_zone_3_name", "")
    await hass.async_block_till_done()
    assert reg.async_get("switch.irrigation_sides").name is None
    assert reg.async_get("number.irrigation_program_a_zone_3_minutes").name is None


async def test_actions(hass: HomeAssistant):
    dev, calls = await setup_controller(hass)
    await add_entry(hass, dev)
    calls.clear()

    await hass.services.async_call(DOMAIN, "run_zone", {"zone": "back bed", "minutes": 4}, blocking=True)
    assert calls == [
        ("number", "set_value", {"entity_id": "number.irrigation_sides_minutes_by_hand", "value": 4}),
        ("switch", "turn_on", {"entity_id": "switch.irrigation_sides"}),
    ]
    calls.clear()

    await hass.services.async_call(DOMAIN, "run_zones", {"zones": ["Drip Front", 1], "minutes": 3}, blocking=True)
    assert calls[0][2]["value"] == "2, 1" and calls[1][2]["value"] == 3 and calls[2][:2] == ("button", "press")
    calls.clear()

    await hass.services.async_call(DOMAIN, "set_program", {
        "program": "b", "enabled": True, "day_mode": "every_n_days", "every_n_days": 3,
        "days": ["fri", "Mon"], "start_times": ["18:30", "6:00"], "minutes": {"Back Bed": 15, "1": 5},
    }, blocking=True)
    got = {(c[0], c[2]["entity_id"]): c[2] for c in calls}
    assert got[("switch", "switch.irrigation_program_b")] == {"entity_id": "switch.irrigation_program_b"}
    assert got[("select", "select.irrigation_program_b_day_mode")]["option"] == "Every N days"
    assert got[("text", "text.irrigation_program_b_days")]["value"] == "mon, fri"
    assert got[("text", "text.irrigation_program_b_start_times")]["value"] == "6:00, 18:30"
    assert got[("number", "number.irrigation_program_b_zone_3_minutes")]["value"] == 15
    assert got[("number", "number.irrigation_program_b_zone_1_minutes")]["value"] == 5
    calls.clear()

    await hass.services.async_call(DOMAIN, "stop", {}, blocking=True)
    assert calls == [("button", "press", {"entity_id": "button.irrigation_stop"})]


async def test_apply_button_and_history_sensors(hass: HomeAssistant):
    dev, _ = await setup_controller(hass)
    await add_entry(hass, dev)
    assert hass.states.get("button.irrigation_apply_zone_names") is not None
    s = hass.states.get("sensor.irrigation_back_bed_watered_last_7_days")
    assert s is not None and s.attributes["zone"] == 3


async def test_zone_map(hass: HomeAssistant):
    dev, _ = await setup_controller(hass)
    await add_entry(hass, dev)
    s = hass.states.get("sensor.irrigation_zones")
    zones = {z["zone"]: z for z in s.attributes["zones"]}
    assert zones[3]["name"] == "Back Bed" and zones[3]["switch"] == "switch.irrigation_sides"
    assert zones[3]["watered"] == "sensor.irrigation_back_bed_watered_last_7_days"
    progs = {p["program"]: p for p in s.attributes["programs"]}
    assert progs["B"]["minutes"]["3"] == "number.irrigation_program_b_zone_3_minutes"
    assert s.attributes["controls"]["stop"] == "button.irrigation_stop"

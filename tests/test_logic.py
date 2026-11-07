from datetime import datetime, timedelta, timezone

import pytest

from custom_components.irrigation_controller import logic
from custom_components.irrigation_controller.logic import Entry

SUFFIXES = ["", " enabled", " minutes by hand", " max minutes", " cycle minutes", " soak minutes", " last run"]
DOMAIN = {"": "switch", " enabled": "switch", " last run": "sensor"}
BASES = ["Left front", "Drip", "Sides", "Back", "Right front", "Zone 6"]


def slug(s):
    return s.lower().replace(" ", "_")


def zone(base, names=None):
    names = names or {}
    return [Entry(f"{DOMAIN.get(s, 'number')}.irrigation_{slug(base + s)}", base + s, names.get(s)) for s in SUFFIXES]


EXTRA = [Entry(f"text.irrigation_zone_{i}_name", f"Zone {i} name") for i in range(1, 7)] + [
    Entry("switch.irrigation_program_a", "Program A"),
    Entry("number.irrigation_program_a_zone_3_minutes", "Program A zone 3 minutes"),
    Entry("number.irrigation_program_b_zone_3_minutes", "Program B zone 3 minutes"),
]
ENTRIES = [e for b in BASES for e in zone(b)] + EXTRA


def test_finds_zones_not_other_entities():
    bases, suffixes = logic.zone_bases(ENTRIES, 6)
    assert bases == BASES
    assert sorted(suffixes) == sorted(SUFFIXES)


def test_renames_using_history_for_zones_renamed_earlier():
    values = dict(enumerate(["Left front", "Drip Front", "Back Bed", "Back", "Left Front", "Zone 6"], 1))
    zone_of = logic.match_zones(values, ENTRIES, BASES, {2: "Drip", 3: "Sides", 5: "Right front"}, "Irrigation")
    assert zone_of == {1: "Left front", 2: "Drip", 3: "Sides", 4: "Back", 5: "Right front", 6: "Zone 6"}
    plan = logic.plan_names(values, ENTRIES, zone_of, SUFFIXES, "Irrigation")
    assert plan["switch.irrigation_sides"] == "Irrigation Back Bed"
    assert plan["number.irrigation_sides_minutes_by_hand"] == "Irrigation Back Bed minutes by hand"
    assert plan["switch.irrigation_right_front_enabled"] == "Irrigation Left Front enabled"
    assert plan["number.irrigation_program_a_zone_3_minutes"] == "Irrigation Program A Back Bed minutes"
    assert "switch.irrigation_back" not in plan
    assert "switch.irrigation_program_a" not in plan


def test_after_a_sync_and_an_empty_name():
    synced = zone("Drip", {"": "Irrigation Drip Front"}) + zone("Sides", {"": "Irrigation Back Bed", " enabled": "Irrigation Back Bed enabled"}) + EXTRA
    values = {2: "Drip Front", 3: ""}
    zone_of = logic.match_zones(values, synced, ["Drip", "Sides"], {}, "Irrigation")
    assert zone_of == {2: "Drip", 3: "Sides"}
    plan = logic.plan_names(values, synced, zone_of, SUFFIXES, "Irrigation")
    assert plan["switch.irrigation_sides"] is None
    assert "number.irrigation_program_a_zone_3_minutes" not in plan  # already the firmware name
    assert plan["switch.irrigation_drip_enabled"] == "Irrigation Drip Front enabled"
    assert "switch.irrigation_drip" not in plan


def test_zone_by_number_or_name():
    values = {1: "Left front", 2: "Drip Front", 5: "Left Front"}
    assert logic.zone_number(2, values) == 2
    assert logic.zone_number("2", values) == 2
    assert logic.zone_number("drip front", values) == 2
    with pytest.raises(ValueError, match="more than one"):
        logic.zone_number("left front", values)
    with pytest.raises(ValueError):
        logic.zone_number(9, values)


def test_days_times_modes():
    assert logic.days_text(["Fri", "monday", "wed", "mon"]) == "mon, wed, fri"
    assert logic.days_text("sat,sun") == "sat, sun"
    with pytest.raises(ValueError):
        logic.days_text(["funday"])
    assert logic.times_text(["18:30", "06:00:00", "6:00"]) == "6:00, 18:30"
    with pytest.raises(ValueError):
        logic.times_text(["25:00"])
    assert logic.day_mode("every_n_days") == "Every N days"
    assert logic.day_mode("Odd dates") == "Odd dates"
    with pytest.raises(ValueError):
        logic.day_mode("weekly")


def test_runs_and_minutes():
    t0 = datetime(2026, 11, 6, 8, 0, tzinfo=timezone.utc)
    m = lambda x: t0 + timedelta(minutes=x)  # noqa: E731
    states = [(m(0), "off"), (m(10), "on"), (m(25), "off"), (m(60), "on"), (m(61), "unavailable"), (m(90), "on")]
    rs = logic.runs(states, m(100))
    assert rs == [(m(10), m(25)), (m(60), m(61)), (m(90), m(100))]
    assert logic.minutes_between(rs, m(0), m(200)) == 26.0
    assert logic.minutes_between(rs, m(20), m(95)) == 11.0


def test_ids_go_by_zone_number():
    zone_of = {1: "Left front", 2: "Drip", 6: "Zone 6"}
    plan = logic.plan_ids(ENTRIES, zone_of, SUFFIXES, "Irrigation", slug, {1: "sensor.irrigation_right_front_watered_last_7_days"})
    assert plan["switch.irrigation_left_front"] == "switch.irrigation_zone_1"
    assert plan["number.irrigation_drip_minutes_by_hand"] == "number.irrigation_zone_2_minutes_by_hand"
    assert plan["sensor.irrigation_left_front_last_run"] == "sensor.irrigation_zone_1_last_run"
    assert plan["sensor.irrigation_right_front_watered_last_7_days"] == "sensor.irrigation_zone_1_watered_last_7_days"
    assert "switch.irrigation_zone_6" not in plan  # already right
    assert not any("program" in k for k in plan)

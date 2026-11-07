"""The parts with no Home Assistant in them, so they can be tested on their own."""

from __future__ import annotations

import re
from collections.abc import Callable
from dataclasses import dataclass
from datetime import datetime, timedelta

BAD = {"", "unknown", "unavailable"}
ZONE_TEXT = re.compile(r"^Zone (\d+) name$")
PROGRAM_ZONE = re.compile(r"^Program ([A-D]) zone (\d+) minutes$")
TIME = re.compile(r"^([01]?\d|2[0-3]):([0-5]\d)$")
WEEKDAYS = ["mon", "tue", "wed", "thu", "fri", "sat", "sun"]
DAY_MODES = {
    "days": "Days of the week",
    "every_n_days": "Every N days",
    "odd": "Odd dates",
    "even": "Even dates",
}


@dataclass
class Entry:
    """One of the controller's entities, as the entity registry has it."""

    entity_id: str
    original_name: str
    name: str | None = None

    @property
    def domain(self) -> str:
        return self.entity_id.split(".", 1)[0]


def full(device: str, name: str) -> str:
    """HA shows a custom name as the whole name, so the device name goes in front."""
    return f"{device} {name}" if device else name


def zone_bases(entries: list[Entry], zones: int) -> tuple[list[str], list[str]]:
    """The zones' firmware names ("Drip", "Sides"...) and the suffixes every zone has.

    A zone is a switch named X with a switch "X enabled" next to it.
    """
    names = {e.original_name for e in entries}
    bases = [
        e.original_name
        for e in entries
        if e.domain == "switch" and f"{e.original_name} enabled" in names
    ]
    if not bases or len(bases) > zones:
        return [], []
    count: dict[str, int] = {}
    for b in bases:
        for n in names:
            if n == b or n.startswith(f"{b} "):
                s = n[len(b):]
                count[s] = count.get(s, 0) + 1
    return bases, [s for s, c in count.items() if c == len(bases)]


def match_zones(
    values: dict[int, str],
    entries: list[Entry],
    bases: list[str],
    first: dict[int, str],
    device: str = "",
) -> dict[int, str]:
    """Zone number -> its firmware name.

    In order: the zone whose switch already carries its name (renamed before), the zone
    never renamed, the zone's first name in history, and then whatever is left, in order.
    """
    out: dict[int, str] = {}
    free = list(bases)

    def main(b: str) -> Entry | None:
        return next((e for e in entries if e.domain == "switch" and e.original_name == b), None)

    def take(zone: int, b: str | None) -> None:
        if b and b in free and zone not in out:
            out[zone] = b
            free.remove(b)

    for z, v in values.items():
        if v not in BAD:
            take(z, next((b for b in bases if (m := main(b)) and m.name == full(device, v.strip())), None))
    for z, v in values.items():
        take(z, next((b for b in bases if b == v), None))
    for z in values:
        take(z, next((b for b in bases if b == first.get(z)), None))
    # Last: the rest in order (the firmware creates its zones in order, so the registry has them so).
    left = sorted(z for z in values if z not in out)
    if len(left) == len(free):
        for z, b in zip(left, list(free)):
            take(z, b)
    return out


def plan_names(
    values: dict[int, str],
    entries: list[Entry],
    zone_of: dict[int, str],
    suffixes: list[str],
    device: str = "",
) -> dict[str, str | None]:
    """entity id -> the name it should have (None: back to the firmware's)."""
    out: dict[str, str | None] = {}
    for z, v in values.items():
        if v in ("unknown", "unavailable"):
            continue
        name = v.strip()
        base = zone_of.get(z)
        for e in entries:
            want: str | None
            o = e.original_name
            p = PROGRAM_ZONE.match(o)
            if p and int(p.group(2)) == z:
                want = full(device, f"Program {p.group(1)} {name} minutes") if name else None
            elif base is not None and (s := next((x for x in suffixes if o == base + x), None)) is not None:
                want = None if name in ("", base) else full(device, name + s)
            else:
                continue
            if e.name != want:
                out[e.entity_id] = want
    return out


def plan_ids(
    entries: list[Entry],
    zone_of: dict[int, str],
    suffixes: list[str],
    device: str,
    slug: Callable[[str], str],
    watered: dict[int, str] | None = None,
) -> dict[str, str]:
    """entity id -> its zone-numbered id ("switch.irrigation_zone_1_enabled").

    Ids go by zone number, never by name, so renaming a zone changes only what HA shows (the
    way a program's "zone 1 minutes" already is). `watered` is zone -> our "watered" sensor.
    """
    out: dict[str, str] = {}
    for z, base in zone_of.items():
        for e in entries:
            s = next((x for x in suffixes if e.original_name == base + x), None)
            if s is not None and (want := f"{e.domain}.{slug(full(device, f'Zone {z}{s}'))}") != e.entity_id:
                out[e.entity_id] = want
        if watered and (eid := watered.get(z)):
            want = f"sensor.{slug(full(device, f'Zone {z} watered last 7 days'))}"
            if want != eid:
                out[eid] = want
    return out


def zone_number(zone: int | str, values: dict[int, str]) -> int:
    """A zone given as its number or its name (any case)."""
    if isinstance(zone, int) or str(zone).strip().isdigit():
        n = int(zone)
        if n in values:
            return n
        raise ValueError(f"no zone {n}")
    want = str(zone).strip().lower()
    hits = [z for z, v in values.items() if v.strip().lower() == want]
    if len(hits) == 1:
        return hits[0]
    raise ValueError(f"no zone called {zone!r}" if not hits else f"more than one zone called {zone!r}")


def days_text(days: list[str] | str) -> str:
    """["Mon", "wednesday"] -> "mon, wed" (the firmware's form)."""
    items = days.split(",") if isinstance(days, str) else days
    out = []
    for d in items:
        k = str(d).strip().lower()[:3]
        if not k:
            continue
        if k not in WEEKDAYS:
            raise ValueError(f"not a day: {d!r}")
        if k not in out:
            out.append(k)
    return ", ".join(sorted(out, key=WEEKDAYS.index))


def times_text(times: list[str] | str) -> str:
    """["6:00", "18:30"] -> "6:00, 18:30", sorted, checked."""
    items = times.split(",") if isinstance(times, str) else times
    out = []
    for t in items:
        t = str(t).strip()
        if not t:
            continue
        if len(t) == 8 and t.count(":") == 2:  # "06:00:00" from a time picker
            t = t[:5]
        m = TIME.match(t)
        if not m:
            raise ValueError(f"not a time: {t!r}")
        out.append((int(m.group(1)), int(m.group(2))))
    return ", ".join(f"{h}:{m:02d}" for h, m in sorted(set(out)))


def day_mode(mode: str) -> str:
    """"every_n_days" or "Every N days" -> the firmware's option."""
    if mode in DAY_MODES.values():
        return mode
    key = mode.strip().lower().replace(" ", "_")
    if key in DAY_MODES:
        return DAY_MODES[key]
    raise ValueError(f"day mode must be one of {', '.join(DAY_MODES)}")


def runs(states: list[tuple[datetime, str]], until: datetime) -> list[tuple[datetime, datetime]]:
    """A zone switch's history -> its watering runs (on .. off)."""
    out = []
    start: datetime | None = None
    for t, s in states:
        if s == "on" and start is None:
            start = t
        elif s != "on" and start is not None:
            out.append((start, t))
            start = None
    if start is not None:
        out.append((start, until))
    return out


def minutes_between(rs: list[tuple[datetime, datetime]], a: datetime, b: datetime) -> float:
    """Minutes of watering inside [a, b)."""
    total = timedelta()
    for s, e in rs:
        lo, hi = max(s, a), min(e, b)
        if hi > lo:
            total += hi - lo
    return round(total.total_seconds() / 60, 1)

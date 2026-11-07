#pragma once
// Wires irrigation_core.h to the board: reads the settings from their Home Assistant entities,
// starts programs at their times, drives the relays once a second and reports what it's doing.
// Everything runs on the board, so watering goes on without Wi-Fi or Home Assistant.

#include <cmath>
#include <cstdio>

#include "irrigation_core.h"

namespace irrigation {

using namespace esphome;

static const char *const TAG = "irrigation";

/** A UTC time as ISO 8601, which HA reads exactly (a float sensor rounds it to ~2 min). */
inline std::string iso_utc(time_t t) {
  struct tm tm;
  gmtime_r(&t, &tm);
  char buf[32];
  strftime(buf, sizeof buf, "%Y-%m-%dT%H:%M:%S+00:00", &tm);
  return buf;
}

struct ZoneEntities {
  switch_::Switch *relay = nullptr;    // the relay itself (internal)
  switch_::Switch *control = nullptr;  // "Zone N" in HA: on runs it, off stops it
  switch_::Switch *enabled = nullptr;
  number::Number *manual = nullptr, *max = nullptr, *cycle = nullptr, *soak = nullptr;
  text_sensor::TextSensor *last_run = nullptr;  // an ISO timestamp
  uint32_t *last_run_store = nullptr;  // survives restarts
};

struct ProgramEntities {
  switch_::Switch *enabled = nullptr;
  select::Select *mode = nullptr;
  text::Text *days = nullptr, *starts = nullptr;
  number::Number *interval = nullptr;
  number::Number *starts_in = nullptr;  // every N days: days until the next watering day
  int *anchor = nullptr;  // survives restarts
  number::Number *minutes[MAX_ZONES] = {};
};

class Controller {
 public:
  ZoneEntities zones[MAX_ZONES];
  ProgramEntities programs[MAX_PROGRAMS];
  time::RealTimeClock *clock = nullptr;
  number::Number *seasonal = nullptr, *gap = nullptr, *rain_delay = nullptr, *guard_max = nullptr;
  text::Text *monthly = nullptr, *guard_days = nullptr, *guard_hours = nullptr;
  select::Select *guard_mode = nullptr, *master = nullptr, *rain_input = nullptr, *rain_type = nullptr;
  switch_::Switch *skip_next = nullptr;
  binary_sensor::BinarySensor *inputs[8] = {};
  binary_sensor::BinarySensor *rain = nullptr;
  text_sensor::TextSensor *status = nullptr, *event = nullptr, *problems = nullptr;
  sensor::Sensor *active_zone = nullptr, *remaining = nullptr;
  text_sensor::TextSensor *next_run = nullptr;  // an ISO timestamp, empty when there's none
  text::Text *manual_zones = nullptr;     // "Zones to run": "1, 3, 5" or "all"
  number::Number *manual_each = nullptr;  // "Minutes each": 0 = each zone's own minutes by hand
  int *rain_until = nullptr;  // a day number; watering resumes that day (survives restarts)

  // ── Actions from Home Assistant ──

  void run_zone(int zone) {
    if (!valid_zone(zone)) return;
    const auto &z = zones[zone - 1];
    const int m = std::min(num(z.manual, 10), num(z.max, 60) > 0 ? num(z.max, 60) : 240);
    start({{zone, static_cast<uint32_t>(m) * 60}}, false, false, "Zone " + std::to_string(zone) + " started by hand");
  }

  void stop_zone(int zone) {
    if (runner_.zone() != zone && !runner_.has_zone(zone)) return;  // not running or waiting
    runner_.stop_zone(zone, now_s());
    tell("Zone " + std::to_string(zone) + " stopped by hand");
    update();
  }

  void run_program(int i) {
    refresh();
    const auto runs = program_runs(cfg_programs_[i], cfg_zones_, percent(), cfg_guard_, master_zone());
    if (runs.empty()) { tell(program_name(i) + " has no zones to water"); return; }
    start_plan(runs, false, false, program_name(i) + " started by hand");
  }

  void run_all() {
    refresh();
    std::vector<ZoneRun> runs;
    for (int z = 0; z < MAX_ZONES; z++) {
      if (z + 1 == master_zone() || !cfg_zones_[z].enabled) continue;
      const int m = capped_minutes(num(zones[z].manual, 10), cfg_zones_[z], cfg_guard_);
      if (m > 0) runs.push_back({z + 1, static_cast<uint32_t>(m) * 60, static_cast<uint32_t>(cfg_zones_[z].cycle_minutes) * 60,
                                 static_cast<uint32_t>(cfg_zones_[z].soak_minutes) * 60});
    }
    if (runs.empty()) { tell("No zones are on"); return; }
    start_plan(runs, false, false, "All zones started by hand");
  }

  /** "Run selected zones": the zones in "Zones to run", in that order. */
  void run_selected() {
    refresh();
    std::vector<int> picked;
    std::string err;
    if (!parse_zone_list(text(manual_zones), picked, err)) { tell("Zones to run: " + err); return; }
    const int each = num(manual_each, 0);
    std::vector<ZoneRun> runs;
    for (int zone : picked) {
      const int z = zone - 1;
      if (zone == master_zone() || !cfg_zones_[z].enabled) continue;
      const int m = capped_minutes(each > 0 ? each : num(zones[z].manual, 10), cfg_zones_[z], cfg_guard_);
      if (m > 0) runs.push_back({zone, static_cast<uint32_t>(m) * 60, static_cast<uint32_t>(cfg_zones_[z].cycle_minutes) * 60,
                                 static_cast<uint32_t>(cfg_zones_[z].soak_minutes) * 60});
    }
    if (runs.empty()) { tell("None of those zones are on"); return; }
    start_plan(runs, false, false, "Zones " + text(manual_zones) + " started by hand");
  }

  /** "Next zone": cut the open zone short and go on to the next. */
  void next_zone() {
    const int zone = runner_.zone();
    if (!zone) return;
    runner_.stop_zone(zone, now_s());
    tell("Zone " + std::to_string(zone) + " cut short");
    second();
  }

  void stop_all() {
    runner_.stop();
    tell("Stopped by hand");
    update();
  }

  /** "Rain delay" set from HA: no scheduled watering for this many days (0 clears it). */
  void set_rain_delay(float days) {
    int today, minute;
    if (!local_now(today, minute)) { tell("Can't set a rain delay until the clock is set"); return; }
    const int n = std::max(0, static_cast<int>(std::lround(days)));
    if (rain_until) *rain_until = n ? today + n : 0;
    tell(n ? "Rain delay: " + std::to_string(n) + " day(s)" : "Rain delay cleared");
    publish_rain_delay(today);
    publish_next(today, minute);
  }

  /** A program's "every N days" changed to n: keep the next watering day where it was (under n). */
  void reset_anchor(int i, float n) {
    int today, minute;
    if (!programs[i].anchor || !local_now(today, minute)) return;
    Program p = cfg_programs_[i];
    p.interval = std::max(1, num(programs[i].interval, 1));
    p.anchor = *programs[i].anchor;
    *programs[i].anchor = anchor_in(today, days_until(p, today), static_cast<int>(std::lround(n)));
  }

  /** "Starts in": the next watering day is this many days away (0 = today), then every N days. */
  void set_starts_in(int i, float days) {
    int today, minute;
    if (!programs[i].anchor) return;
    if (!local_now(today, minute)) { tell("Can't set when a program starts until the clock is set"); return; }
    *programs[i].anchor = anchor_in(today, static_cast<int>(std::lround(days)), num(programs[i].interval, 1));
    changed();
  }

  // ── Every second and every minute ──

  void second() {
    const uint32_t now = now_s();
    const int zone = runner_.tick(now);
    if (rain_active() && runner_.scheduled()) {
      runner_.stop();
      tell("Stopped: the rain sensor says it's wet");
    }
    apply(runner_.zone(), now);
    update();
    (void) zone;
  }

  void minute() {
    refresh();
    int today, minute;
    if (!local_now(today, minute)) { publish_status(); return; }
    if (rain_until && *rain_until && *rain_until <= today) *rain_until = 0;  // over
    for (int i = 0; i < MAX_PROGRAMS; i++) {
      const Program &p = cfg_programs_[i];
      if (!p.enabled || !day_matches(p, today)) continue;
      for (int s = 0; s < p.n_starts; s++)
        if (p.starts[s] == minute) scheduled_start(i, today, minute);
    }
    publish_rain_delay(today);
    publish_starts_in(today);
    publish_next(today, minute);
    publish_status();
  }

  /** Settings changed in HA: check them and recompute the next run. */
  void changed() {
    refresh();
    int today, minute;
    if (local_now(today, minute)) {
      publish_starts_in(today);
      publish_next(today, minute);
    }
  }

  /** Seconds left in the current run (0 when idle): the screen's countdown. */
  uint32_t seconds_left() { return runner_.total_left(now_s()); }

 private:
  // ── Settings ──

  static float numf(number::Number *n, float dflt) { return n && n->has_state() && !std::isnan(n->state) ? n->state : dflt; }
  static int num(number::Number *n, int dflt) { return static_cast<int>(std::lround(numf(n, dflt))); }
  static int index(select::Select *s, int dflt = 0) {
    if (!s) return dflt;
    auto i = s->active_index();
    return i.has_value() ? static_cast<int>(*i) : dflt;
  }
  static std::string text(text::Text *t) { return t ? t->state : std::string(); }
  static std::string program_name(int i) { return std::string("Program ") + static_cast<char>('A' + i); }

  bool valid_zone(int zone) const { return zone >= 1 && zone <= MAX_ZONES && zones[zone - 1].relay; }
  int master_zone() const { return index(master); }  // 0 = none, else the zone whose relay drives it

  /** Read every setting into the core's types, and say what doesn't make sense. */
  void refresh() {
    std::string issues;
    auto issue = [&](const std::string &s) { issues += (issues.empty() ? "" : "; ") + s; };
    for (int z = 0; z < MAX_ZONES; z++) {
      const auto &e = zones[z];
      Zone &c = cfg_zones_[z];
      c.enabled = e.enabled && e.enabled->state;
      c.max_minutes = num(e.max, 60);
      c.cycle_minutes = num(e.cycle, 0);
      c.soak_minutes = num(e.soak, 0);
    }
    for (int i = 0; i < MAX_PROGRAMS; i++) {
      const auto &e = programs[i];
      Program &p = cfg_programs_[i];
      p.enabled = e.enabled && e.enabled->state;
      p.mode = static_cast<DayMode>(index(e.mode));
      p.interval = std::max(1, num(e.interval, 1));
      p.anchor = e.anchor ? *e.anchor : 0;
      std::string err;
      if (!parse_days(text(e.days), p.days, err)) issue(program_name(i) + " days: " + err);
      if (!parse_starts(text(e.starts), p.starts, p.n_starts, err)) issue(program_name(i) + " start times: " + err);
      for (int z = 0; z < MAX_ZONES; z++) p.minutes[z] = num(e.minutes[z], 0);
      if (p.enabled) {
        if (!p.n_starts) issue(program_name(i) + " is on but has no start times");
        if (p.mode == DayMode::WEEKDAYS && !p.days) issue(program_name(i) + " is on but has no days");
        if (program_runs(p, cfg_zones_, 100, Guard{}, master_zone()).empty()) issue(program_name(i) + " is on but has no zone minutes");
      }
    }
    Guard &g = cfg_guard_;
    g.mode = static_cast<GuardMode>(index(guard_mode));
    std::string err;
    const std::string days = text(guard_days);
    if (days.empty()) g.days = 0x7f;
    else if (!parse_days(days, g.days, err)) { issue("Allowed days: " + err); g.days = 0x7f; }
    if (!parse_window(text(guard_hours), g.no_from, g.no_to, err)) issue("No-water hours: " + err);
    g.max_minutes = num(guard_max, 0);
    if (!parse_monthly(text(monthly), monthly_, monthly_set_, err)) issue("Monthly %: " + err);
    const int mz = master_zone();
    if (mz && zones[mz - 1].enabled && zones[mz - 1].enabled->state) issue("Zone " + std::to_string(mz) + " is the master valve; its own watering is skipped");
    const std::string out = issues.empty() ? "OK" : issues;
    if (problems && problems->state != out) problems->publish_state(out);
  }

  int percent() {
    int today, minute, y, m, d;
    if (monthly_set_ && local_now(today, minute)) {
      civil_from_days(today, y, m, d);
      return monthly_[m - 1];
    }
    return num(seasonal, 100);
  }

  bool rain_active() const {
    const int in = index(rain_input);
    if (in < 1 || in > 8 || !inputs[in - 1] || !inputs[in - 1]->has_state()) return false;
    const bool closed = inputs[in - 1]->state;
    return index(rain_type) == 0 ? !closed : closed;  // 0: normally closed, opens when wet
  }

  // ── Starting ──

  void scheduled_start(int i, int today, int minute) {
    const std::string name = program_name(i);
    if (rain_until && *rain_until > today) { tell(name + " skipped: rain delay"); return; }
    if (rain_active()) { tell(name + " skipped: the rain sensor says it's wet"); return; }
    const std::string why = guard_problem(cfg_guard_, today, minute);
    if (!why.empty() && cfg_guard_.mode == GuardMode::BLOCK) { tell(name + " skipped by the watering rules: " + why); return; }
    if (skip_next && skip_next->state) {
      skip_next->turn_off();
      tell(name + " skipped (skip next run)");
      return;
    }
    const auto runs = program_runs(cfg_programs_[i], cfg_zones_, percent(), cfg_guard_, master_zone());
    if (runs.empty()) return;
    std::string what = name + " started";
    if (!why.empty()) what += " (outside the watering rules: " + why + ")";
    start_plan(runs, true, true, what);
  }

  void start_plan(const std::vector<ZoneRun> &runs, bool scheduled, bool append, const std::string &what) {
    start(plan_run(runs, static_cast<uint32_t>(num(gap, 2))), scheduled, append, what);
  }

  void start(const std::vector<Segment> &segs, bool scheduled, bool append, const std::string &what) {
    const uint32_t mins = (total_secs(segs) + 59) / 60;
    runner_.start(segs, now_s(), scheduled, append);
    tell(what + ", " + std::to_string(mins) + " min");
    second();
  }

  // ── The relays ──

  void apply(int zone, uint32_t now) {
    const int mz = master_zone();
    // Off first, then on: never two zones open at once.
    for (int z = 1; z <= MAX_ZONES; z++) {
      const bool want = (z == zone && z != mz) || (z == mz && runner_.busy());
      if (!want) set_relay(z, false, now);
    }
    for (int z = 1; z <= MAX_ZONES; z++) {
      const bool want = (z == zone && z != mz) || (z == mz && runner_.busy());
      if (want) set_relay(z, true, now);
    }
    // Safety net, apart from the sequencer: a zone open longer than its cap (plus 2 min) closes.
    for (int z = 1; z <= MAX_ZONES; z++) {
      auto *r = zones[z - 1].relay;
      if (!r || !r->state || z == mz) continue;
      const int cap = num(zones[z - 1].max, 60) > 0 ? num(zones[z - 1].max, 60) : 240;
      if (now - opened_at_[z - 1] > static_cast<uint32_t>(cap + 2) * 60) {
        ESP_LOGW(TAG, "Zone %d open past its %d min cap: closing everything", z, cap);
        runner_.stop();
        set_relay(z, false, now);
        tell("Safety stop: zone " + std::to_string(z) + " ran past its limit");
      }
    }
  }

  void set_relay(int z, bool on, uint32_t now) {
    auto *r = zones[z - 1].relay;
    if (!r || r->state == on) return;
    if (on) {
      r->turn_on();
      opened_at_[z - 1] = now;
      if (z != master_zone()) mark_last_run(z);
    } else {
      r->turn_off();
    }
  }

  void mark_last_run(int z) {
    auto &e = zones[z - 1];
    const auto t = clock ? clock->now() : ESPTime{};
    if (!t.is_valid()) return;
    if (e.last_run_store) *e.last_run_store = static_cast<uint32_t>(t.timestamp);
    if (e.last_run) e.last_run->publish_state(iso_utc(t.timestamp));
  }

  // ── Reporting ──

  void update() {
    const uint32_t now = now_s();
    const int zone = runner_.zone();
    for (int z = 1; z <= MAX_ZONES; z++) {
      auto *c = zones[z - 1].control;
      if (c && c->state != (zone == z)) c->publish_state(zone == z);
    }
    if (active_zone && (!active_zone->has_state() || active_zone->state != zone)) active_zone->publish_state(zone);
    const float left = std::ceil(runner_.total_left(now) / 60.0f);
    if (remaining && (!remaining->has_state() || remaining->state != left)) remaining->publish_state(left);
    if (rain) {
      const bool wet = rain_active();
      if (!rain->has_state() || rain->state != wet) rain->publish_state(wet);
    }
    publish_status();
  }

  void publish_status() {
    if (!status) return;
    const uint32_t now = now_s();
    std::string s;
    if (runner_.busy()) {
      const int zone = runner_.zone();
      const auto step = (runner_.step_left(now) + 59) / 60;
      if (zone) s = "Zone " + std::to_string(zone) + " running, " + std::to_string(step) + " min left";
      else s = runner_.next_zone() ? "Pausing, zone " + std::to_string(runner_.next_zone()) + " next" : "Pausing";
    } else if (clock && !clock->now().is_valid()) {
      s = "Waiting for the clock";
    } else {
      int today = 0, minute = 0;
      local_now(today, minute);
      if (rain_until && *rain_until > today) s = "Rain delay";
      else if (rain_active()) s = "Wet (rain sensor)";
      else s = "Idle";
    }
    if (status->state != s) status->publish_state(s);
  }

  void publish_rain_delay(int today) {
    if (!rain_delay) return;
    const float left = rain_until && *rain_until > today ? *rain_until - today : 0;
    if (!rain_delay->has_state() || rain_delay->state != left) rain_delay->publish_state(left);
  }

  void publish_starts_in(int today) {
    for (int i = 0; i < MAX_PROGRAMS; i++) {
      auto *n = programs[i].starts_in;
      if (!n) continue;
      const float d = days_until(cfg_programs_[i], today);
      if (!n->has_state() || n->state != d) n->publish_state(d);
    }
  }

  void publish_next(int today, int minute) {
    if (!next_run) return;
    const When w = next_run_(today, minute);
    const auto t = clock->now();
    if (!w.found() || !t.is_valid()) { if (!next_run->state.empty()) next_run->publish_state(""); return; }
    // Local to UTC with today's offset (a daylight-saving change before then is out by an hour).
    const long local_now_s = static_cast<long>(today) * 86400 + minute * 60 + t.second;
    const long offset = static_cast<long>(t.timestamp) - local_now_s;
    const std::string at = iso_utc(static_cast<time_t>(static_cast<long>(w.day) * 86400 + w.minute * 60 + offset));
    if (next_run->state != at) next_run->publish_state(at);
  }

  When next_run_(int today, int minute) {
    return irrigation::next_run(cfg_programs_, cfg_zones_, percent(), cfg_guard_, master_zone(), today, minute,
                                rain_until ? *rain_until : 0);
  }

  void tell(const std::string &s) {
    ESP_LOGI(TAG, "%s", s.c_str());
    if (event) event->publish_state(s);
  }

  // ── Time ──

  bool local_now(int &today, int &minute) const {
    if (!clock) return false;
    const auto t = clock->now();
    if (!t.is_valid()) return false;
    today = days_from_civil(t.year, t.month, t.day_of_month);
    minute = t.hour * 60 + t.minute;
    return true;
  }

  /** Seconds since boot that don't wrap with millis(). */
  uint32_t now_s() {
    const uint32_t ms = millis();
    elapsed_ms_ += static_cast<uint32_t>(ms - last_ms_);
    last_ms_ = ms;
    return static_cast<uint32_t>(elapsed_ms_ / 1000);
  }

  Runner runner_;
  Zone cfg_zones_[MAX_ZONES];
  Program cfg_programs_[MAX_PROGRAMS];
  Guard cfg_guard_;
  int monthly_[12] = {};
  bool monthly_set_ = false;
  uint32_t opened_at_[MAX_ZONES] = {};
  uint64_t elapsed_ms_ = 0;
  uint32_t last_ms_ = 0;
};

inline Controller &ctl() {
  static Controller c;
  return c;
}

}  // namespace irrigation

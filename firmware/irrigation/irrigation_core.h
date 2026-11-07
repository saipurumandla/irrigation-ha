#pragma once
// Irrigation schedule logic, kept free of ESPHome so it can be tested on a PC
// (irrigation/test_core.cpp, run by core.test.ts). irrigation_esphome.h wires it to the board.
//
// Times are the house's local time: a day is a count of days since 1970-01-01 (local), a
// minute is 0..1439 within that day. Durations are seconds.

#include <algorithm>
#include <cctype>
#include <climits>
#include <cstdint>
#include <deque>
#include <string>
#include <vector>

namespace irrigation {

constexpr int MAX_ZONES = 8;
constexpr int MAX_PROGRAMS = 4;
constexpr int MAX_STARTS = 4;

// ── Dates ────────────────────────────────────────────────────────────────

/** Days since 1970-01-01 for a calendar date (Howard Hinnant's days_from_civil). */
inline int days_from_civil(int y, int m, int d) {
  y -= m <= 2;
  const int era = (y >= 0 ? y : y - 399) / 400;
  const int yoe = y - era * 400;
  const int doy = (153 * (m + (m > 2 ? -3 : 9)) + 2) / 5 + d - 1;
  const int doe = yoe * 365 + yoe / 4 - yoe / 100 + doy;
  return era * 146097 + doe - 719468;
}

/** The calendar date of a day number. */
inline void civil_from_days(int z, int &y, int &m, int &d) {
  z += 719468;
  const int era = (z >= 0 ? z : z - 146096) / 146097;
  const int doe = z - era * 146097;
  const int yoe = (doe - doe / 1460 + doe / 36524 - doe / 146096) / 365;
  const int doy = doe - (365 * yoe + yoe / 4 - yoe / 100);
  const int mp = (5 * doy + 2) / 153;
  d = doy - (153 * mp + 2) / 5 + 1;
  m = mp + (mp < 10 ? 3 : -9);
  y = yoe + era * 400 + (m <= 2);
}

/** 0 = Monday ... 6 = Sunday. */
inline int weekday(int day) { return ((day % 7) + 7 + 3) % 7; }  // 1970-01-01 was a Thursday

// ── Settings as typed in Home Assistant ──────────────────────────────────

namespace detail {
inline std::string lower(std::string s) {
  for (auto &c : s) c = static_cast<char>(std::tolower(static_cast<unsigned char>(c)));
  return s;
}
inline std::vector<std::string> split(const std::string &s, const std::string &seps) {
  std::vector<std::string> out;
  std::string cur;
  for (char c : s) {
    if (seps.find(c) != std::string::npos) {
      if (!cur.empty()) out.push_back(cur);
      cur.clear();
    } else {
      cur += c;
    }
  }
  if (!cur.empty()) out.push_back(cur);
  return out;
}
inline std::string trim(const std::string &s) {
  size_t a = 0, b = s.size();
  while (a < b && std::isspace(static_cast<unsigned char>(s[a]))) a++;
  while (b > a && std::isspace(static_cast<unsigned char>(s[b - 1]))) b--;
  return s.substr(a, b - a);
}
}  // namespace detail

/** Weekday names to a mask (bit 0 = Monday): "Mon, Wed Sat", "daily", "weekdays", "weekends". */
inline bool parse_days(const std::string &text, uint8_t &mask, std::string &err) {
  static const char *const names[7][4] = {
      {"mon", "monday", nullptr, nullptr},   {"tue", "tues", "tuesday", nullptr},
      {"wed", "weds", "wednesday", nullptr}, {"thu", "thur", "thurs", "thursday"},
      {"fri", "friday", nullptr, nullptr},   {"sat", "saturday", nullptr, nullptr},
      {"sun", "sunday", nullptr, nullptr}};
  mask = 0;
  for (const auto &raw : detail::split(detail::lower(text), ", ;/")) {
    if (raw == "daily" || raw == "all" || raw == "everyday") { mask = 0x7f; continue; }
    if (raw == "weekdays") { mask |= 0x1f; continue; }
    if (raw == "weekends") { mask |= 0x60; continue; }
    bool found = false;
    for (int d = 0; d < 7 && !found; d++)
      for (const char *n : names[d])
        if (n && raw == n) { mask |= static_cast<uint8_t>(1 << d); found = true; break; }
    if (!found) { err = "'" + raw + "' isn't a day"; return false; }
  }
  return true;
}

/** "5:30", "05:30", "17:45", "5:30 am", "5pm" to a minute of the day. */
inline bool parse_time(const std::string &text, int &minute) {
  std::string s;
  for (char c : detail::lower(text)) if (!std::isspace(static_cast<unsigned char>(c))) s += c;
  int ampm = 0;
  if (s.size() > 2 && (s.compare(s.size() - 2, 2, "am") == 0 || s.compare(s.size() - 2, 2, "pm") == 0)) {
    ampm = s[s.size() - 2] == 'a' ? 1 : 2;
    s.resize(s.size() - 2);
  }
  int h = 0, m = 0;
  size_t i = 0;
  if (i >= s.size() || !std::isdigit(static_cast<unsigned char>(s[i]))) return false;
  while (i < s.size() && std::isdigit(static_cast<unsigned char>(s[i])) && i < 2) h = h * 10 + (s[i++] - '0');
  if (i < s.size()) {
    if (s[i] != ':' || s.size() - i != 3) return false;
    for (size_t j = i + 1; j < s.size(); j++) {
      if (!std::isdigit(static_cast<unsigned char>(s[j]))) return false;
      m = m * 10 + (s[j] - '0');
    }
  } else if (!ampm) {
    return false;  // a bare "5" is ambiguous: write 5:00 or 5am
  }
  if (ampm) {
    if (h < 1 || h > 12) return false;
    h = h % 12 + (ampm == 2 ? 12 : 0);
  }
  if (h > 23 || m > 59) return false;
  minute = h * 60 + m;
  return true;
}

/** Up to four start times, "5:00, 18:30", sorted and without repeats. Empty is no starts. */
inline bool parse_starts(const std::string &text, int (&starts)[MAX_STARTS], int &n, std::string &err) {
  n = 0;
  std::vector<int> found;
  for (const auto &raw : detail::split(text, ",;")) {
    const std::string t = detail::trim(raw);
    if (t.empty()) continue;
    int m;
    if (!parse_time(t, m)) { err = "'" + t + "' isn't a time (like 5:30 or 6pm)"; return false; }
    if (std::find(found.begin(), found.end(), m) == found.end()) found.push_back(m);
  }
  if (found.size() > static_cast<size_t>(MAX_STARTS)) { err = "at most 4 start times"; return false; }
  std::sort(found.begin(), found.end());
  for (int m : found) starts[n++] = m;
  return true;
}

/** "10:00-16:00" or "10am-4pm" (may wrap past midnight). Empty is no window (from = -1). */
inline bool parse_window(const std::string &text, int &from, int &to, std::string &err) {
  from = to = -1;
  const std::string t = detail::trim(text);
  if (t.empty()) return true;
  const auto parts = detail::split(t, "-");
  if (parts.size() != 2 || !parse_time(detail::trim(parts[0]), from) || !parse_time(detail::trim(parts[1]), to)) {
    from = to = -1;
    err = "'" + t + "' isn't a time range (like 10:00-16:00)";
    return false;
  }
  if (from == to) { from = to = -1; err = "the no-water hours start and end at the same time"; return false; }
  return true;
}

/** Twelve monthly percentages, "60,60,80,...". Empty is none (the single seasonal % is used). */
inline bool parse_monthly(const std::string &text, int (&pct)[12], bool &set, std::string &err) {
  set = false;
  const auto parts = detail::split(text, ", ;");
  if (parts.empty()) return true;
  if (parts.size() != 12) { err = "monthly % needs 12 numbers, Jan to Dec"; return false; }
  for (int i = 0; i < 12; i++) {
    const std::string &p = parts[i];
    if (p.empty() || p.size() > 3 || !std::all_of(p.begin(), p.end(), [](char c) { return std::isdigit(static_cast<unsigned char>(c)); })) {
      err = "'" + p + "' isn't a percentage";
      return false;
    }
    pct[i] = std::stoi(p);
    if (pct[i] > 300) { err = "monthly % goes up to 300"; return false; }
  }
  set = true;
  return true;
}

/** Zones to run by hand, in order: "1, 3, 5", "3-5" or "all"; repeats dropped. */
inline bool parse_zone_list(const std::string &text, std::vector<int> &zones, std::string &err) {
  zones.clear();
  for (const auto &raw : detail::split(detail::lower(text), ", ;")) {
    if (raw == "all") {
      for (int z = 1; z <= MAX_ZONES; z++) if (std::find(zones.begin(), zones.end(), z) == zones.end()) zones.push_back(z);
      continue;
    }
    const auto range = detail::split(raw, "-");
    int a = 0, b = 0;
    auto number = [](const std::string &s, int &out) {
      if (s.empty() || s.size() > 1 || !std::isdigit(static_cast<unsigned char>(s[0]))) return false;
      out = s[0] - '0';
      return out >= 1 && out <= MAX_ZONES;
    };
    if (range.size() == 1 && number(range[0], a)) b = a;
    else if (!(range.size() == 2 && number(range[0], a) && number(range[1], b) && a <= b)) {
      err = "'" + raw + "' isn't a zone (1-8)";
      return false;
    }
    for (int z = a; z <= b; z++) if (std::find(zones.begin(), zones.end(), z) == zones.end()) zones.push_back(z);
  }
  if (zones.empty()) { err = "no zones given"; return false; }
  return true;
}

// ── Programs, zones and the restriction guard ────────────────────────────

enum class DayMode { WEEKDAYS = 0, INTERVAL = 1, ODD = 2, EVEN = 3 };

struct Program {
  bool enabled = false;
  DayMode mode = DayMode::WEEKDAYS;
  uint8_t days = 0;   // WEEKDAYS: bit 0 = Monday
  int interval = 1;   // INTERVAL: every N days...
  int anchor = 0;     // ...counting from this day
  int starts[MAX_STARTS] = {0, 0, 0, 0};
  int n_starts = 0;
  int minutes[MAX_ZONES] = {0, 0, 0, 0, 0, 0, 0, 0};
};

struct Zone {
  bool enabled = true;
  int max_minutes = 60;   // a hard cap for one run
  int cycle_minutes = 0;  // cycle and soak: run this long at a time...
  int soak_minutes = 0;   // ...then let it soak in this long
};

enum class GuardMode { OFF = 0, WARN = 1, BLOCK = 2 };

struct Guard {
  GuardMode mode = GuardMode::OFF;
  uint8_t days = 0x7f;  // allowed weekdays
  int no_from = -1, no_to = -1;  // no-water hours (minutes), -1 = none
  int max_minutes = 0;  // per zone per run, 0 = no limit
};

/** Odd dates skip the 31st and Feb 29th and even dates are even, so neither waters two days running. */
inline bool day_matches(const Program &p, int day) {
  int y, m, d;
  civil_from_days(day, y, m, d);
  switch (p.mode) {
    case DayMode::WEEKDAYS: return (p.days >> weekday(day)) & 1;
    case DayMode::INTERVAL: {
      const int n = std::max(1, p.interval);
      return day >= p.anchor && (day - p.anchor) % n == 0;
    }
    case DayMode::ODD: return d % 2 == 1 && d != 31 && !(m == 2 && d == 29);
    case DayMode::EVEN: return d % 2 == 0;
  }
  return false;
}

/** Every N days: how many days until the next watering day (0 = today). */
inline int days_until(const Program &p, int today) {
  const int n = std::max(1, p.interval);
  if (p.anchor >= today) return p.anchor - today;
  return (n - (today - p.anchor) % n) % n;
}

/** The anchor that makes the next watering day `days` from today (kept under N). */
inline int anchor_in(int today, int days, int interval) {
  return today + std::max(0, std::min(days, std::max(1, interval) - 1));
}

inline bool in_window(int from, int to, int minute) {
  if (from < 0) return false;
  return from < to ? (minute >= from && minute < to) : (minute >= from || minute < to);
}

/** Why the guard objects to watering at this day and minute, or empty if it doesn't. */
inline std::string guard_problem(const Guard &g, int day, int minute) {
  if (g.mode == GuardMode::OFF) return "";
  if (!((g.days >> weekday(day)) & 1)) return "not an allowed watering day";
  if (in_window(g.no_from, g.no_to, minute)) return "inside the no-water hours";
  return "";
}

/** A zone's minutes after the seasonal %, rounded; 0 when the base is 0. */
inline int adjusted_minutes(int base, int pct) {
  if (base <= 0 || pct <= 0) return 0;
  return std::max(1, (base * pct + 50) / 100);
}

/** The cap on one zone's run: its own max, and the guard's when it blocks. */
inline int capped_minutes(int minutes, const Zone &z, const Guard &g) {
  int cap = z.max_minutes > 0 ? z.max_minutes : minutes;
  if (g.mode == GuardMode::BLOCK && g.max_minutes > 0) cap = std::min(cap, g.max_minutes);
  return std::min(minutes, cap);
}

// ── Turning a run into valve steps ───────────────────────────────────────

/** One step: a zone open for secs, or zone 0 = all closed for secs (a gap or a soak). */
struct Segment {
  int zone;
  uint32_t secs;
  bool operator==(const Segment &o) const { return zone == o.zone && secs == o.secs; }
};

struct ZoneRun {
  int zone;
  uint32_t secs;
  uint32_t cycle_secs = 0;  // 0 = all at once
  uint32_t soak_secs = 0;
};

/**
 * Zones in order, each split into cycles when it has cycle and soak set; while one zone soaks the
 * next ones run, and only when every zone left is still soaking does everything wait. A gap
 * (valves all closed) separates one zone from the next.
 */
inline std::vector<Segment> plan_run(std::vector<ZoneRun> runs, uint32_t gap_secs) {
  std::vector<Segment> out;
  std::vector<long> last_end(runs.size(), -1);
  long t = 0;
  bool first = true;
  auto push = [&](int zone, uint32_t secs) {
    if (!secs) return;
    if (!out.empty() && out.back().zone == zone) out.back().secs += secs;
    else out.push_back({zone, secs});
  };
  for (auto &r : runs)
    if (!r.cycle_secs || !r.soak_secs) r.cycle_secs = 0;  // cycles without a soak are one run
  for (;;) {
    bool any = false, ran = false;
    long min_ready = LONG_MAX;
    for (size_t i = 0; i < runs.size(); i++) {
      auto &r = runs[i];
      if (!r.secs) continue;
      any = true;
      const long ready = last_end[i] < 0 ? 0 : last_end[i] + static_cast<long>(r.soak_secs);
      if (ready > t) { min_ready = std::min(min_ready, ready); continue; }
      if (!first && gap_secs) { push(0, gap_secs); t += gap_secs; }
      const uint32_t chunk = r.cycle_secs ? std::min(r.cycle_secs, r.secs) : r.secs;
      push(r.zone, chunk);
      t += chunk;
      r.secs -= chunk;
      last_end[i] = t;
      first = false;
      ran = true;
    }
    if (!any) break;
    if (!ran) { push(0, static_cast<uint32_t>(min_ready - t)); t = min_ready; }
  }
  return out;
}

inline uint32_t total_secs(const std::vector<Segment> &segs) {
  uint32_t t = 0;
  for (const auto &s : segs) t += s.secs;
  return t;
}

// ── What runs, and when next ─────────────────────────────────────────────

/** A program's run at a start time, before the guard: zones with minutes, enabled, adjusted and capped. */
inline std::vector<ZoneRun> program_runs(const Program &p, const Zone (&zones)[MAX_ZONES], int pct,
                                         const Guard &g, int master_zone) {
  std::vector<ZoneRun> out;
  for (int z = 0; z < MAX_ZONES; z++) {
    if (z + 1 == master_zone || !zones[z].enabled) continue;
    const int m = capped_minutes(adjusted_minutes(p.minutes[z], pct), zones[z], g);
    if (m <= 0) continue;
    out.push_back({z + 1, static_cast<uint32_t>(m) * 60, static_cast<uint32_t>(zones[z].cycle_minutes) * 60,
                   static_cast<uint32_t>(zones[z].soak_minutes) * 60});
  }
  return out;
}

struct When {
  int day = -1;
  int minute = 0;
  int program = -1;
  bool found() const { return day >= 0; }
};

/**
 * The next start (strictly after now) that would water something: an enabled program on a day it
 * runs, not inside a rain delay (watering resumes on rain_until), and allowed when the guard blocks.
 */
inline When next_run(const Program (&programs)[MAX_PROGRAMS], const Zone (&zones)[MAX_ZONES], int pct,
                     const Guard &g, int master_zone, int today, int now_minute, int rain_until, int horizon_days = 60) {
  When best;
  for (int day = std::max(today, rain_until); day < today + horizon_days; day++) {
    for (int i = 0; i < MAX_PROGRAMS; i++) {
      const Program &p = programs[i];
      if (!p.enabled || !day_matches(p, day) || program_runs(p, zones, pct, g, master_zone).empty()) continue;
      for (int s = 0; s < p.n_starts; s++) {
        const int m = p.starts[s];
        if (day == today && m <= now_minute) continue;
        if (g.mode == GuardMode::BLOCK && !guard_problem(g, day, m).empty()) continue;
        if (!best.found() || m < best.minute) { best.day = day; best.minute = m; best.program = i; }
        break;  // starts are sorted
      }
    }
    if (best.found()) return best;
  }
  return best;
}

// ── The valve sequencer ──────────────────────────────────────────────────

/** Steps through segments one at a time; only one zone is ever open. */
class Runner {
 public:
  /** Start these steps now (replacing what's running), or after it (append). */
  void start(const std::vector<Segment> &segs, uint32_t now, bool scheduled, bool append) {
    if (!append) stop();
    if (segs.empty()) return;
    for (const auto &s : segs) queue_.push_back(s);
    if (!append || !active_) scheduled_ = scheduled;
    else scheduled_ = scheduled_ && scheduled;
    if (!active_) advance(now);
  }

  void stop() {
    queue_.clear();
    active_ = false;
    current_ = {0, 0};
    scheduled_ = false;
  }

  /** Stop one zone: now if it's open, and its later steps. */
  void stop_zone(int zone, uint32_t now) {
    queue_.erase(std::remove_if(queue_.begin(), queue_.end(), [zone](const Segment &s) { return s.zone == zone; }),
                 queue_.end());
    if (active_ && current_.zone == zone) advance(now);
    trim();
  }

  /** Move on when the current step is over. Returns the zone that should be open (0 = none). */
  int tick(uint32_t now) {
    while (active_ && now >= ends_) advance(ends_ > now ? now : ends_);
    return zone();
  }

  int zone() const { return active_ ? current_.zone : 0; }
  bool busy() const { return active_; }
  bool scheduled() const { return active_ && scheduled_; }
  /** Seconds left of the current step, and of everything. */
  uint32_t step_left(uint32_t now) const { return active_ && ends_ > now ? ends_ - now : 0; }
  uint32_t total_left(uint32_t now) const {
    uint32_t t = step_left(now);
    for (const auto &s : queue_) t += s.secs;
    return t;
  }
  /** Whether a zone is waiting its turn. */
  bool has_zone(int zone) const {
    return std::any_of(queue_.begin(), queue_.end(), [zone](const Segment &s) { return s.zone == zone; });
  }
  /** The next zone to open after the current step (0 = none). */
  int next_zone() const {
    for (const auto &s : queue_) if (s.zone) return s.zone;
    return 0;
  }

 private:
  void advance(uint32_t now) {
    if (queue_.empty()) { active_ = false; current_ = {0, 0}; scheduled_ = false; return; }
    current_ = queue_.front();
    queue_.pop_front();
    ends_ = now + current_.secs;
    active_ = true;
    trim();
  }
  /** Pauses side by side (a zone dropped from between them) are one pause, the longer; a pause
   *  with no zone after it is pointless: end there. */
  void trim() {
    for (size_t i = 1; i < queue_.size();) {
      if (queue_[i].zone == 0 && queue_[i - 1].zone == 0) {
        queue_[i - 1].secs = std::max(queue_[i - 1].secs, queue_[i].secs);
        queue_.erase(queue_.begin() + static_cast<long>(i));
      } else {
        i++;
      }
    }
    if (active_ && current_.zone == 0 && !queue_.empty() && queue_.front().zone == 0) queue_.pop_front();
    while (!queue_.empty() && queue_.back().zone == 0) queue_.pop_back();
    if (active_ && current_.zone == 0 && queue_.empty()) { active_ = false; current_ = {0, 0}; scheduled_ = false; }
  }

  std::deque<Segment> queue_;
  Segment current_{0, 0};
  uint32_t ends_ = 0;
  bool active_ = false;
  bool scheduled_ = false;
};

}  // namespace irrigation

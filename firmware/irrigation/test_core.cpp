// Tests for irrigation_core.h, built and run on a PC by core.test.ts (g++ -std=c++17).
// Each CHECK prints "ok <name>" or "FAIL <name> (file:line)"; the exit code is the failure count.

#include "irrigation_core.h"

#include <cstdio>

using namespace irrigation;

static int failures = 0;
#define CHECK(name, cond)                                                       \
  do {                                                                          \
    if (cond) std::printf("ok %s\n", name);                                     \
    else { std::printf("FAIL %s (%s:%d)\n", name, __FILE__, __LINE__); failures++; } \
  } while (0)

static int day(int y, int m, int d) { return days_from_civil(y, m, d); }

static void dates() {
  CHECK("epoch is day 0", day(1970, 1, 1) == 0);
  CHECK("2026-10-29 is a Thursday", weekday(day(2026, 10, 29)) == 3);
  CHECK("1970-01-05 is a Monday", weekday(day(1970, 1, 5)) == 0);
  int y, m, d;
  civil_from_days(day(2028, 2, 29), y, m, d);
  CHECK("leap day round-trips", y == 2028 && m == 2 && d == 29);
}

static void parsing() {
  uint8_t mask;
  std::string err;
  CHECK("days: names and commas", parse_days("Mon, Wed sat", mask, err) && mask == 0x25);
  CHECK("days: long names, any case", parse_days("Tuesday THURSDAY", mask, err) && mask == 0x0a);
  CHECK("days: daily", parse_days("daily", mask, err) && mask == 0x7f);
  CHECK("days: weekdays + sun", parse_days("weekdays, sun", mask, err) && mask == 0x5f);
  CHECK("days: empty is none", parse_days("", mask, err) && mask == 0);
  CHECK("days: rejects a typo", !parse_days("Mon, Wendsday", mask, err) && err == "'wendsday' isn't a day");

  int m;
  CHECK("time: 5:30", parse_time("5:30", m) && m == 330);
  CHECK("time: 05:30", parse_time("05:30", m) && m == 330);
  CHECK("time: 17:45", parse_time("17:45", m) && m == 1065);
  CHECK("time: 6pm", parse_time("6pm", m) && m == 1080);
  CHECK("time: 6:15 PM", parse_time("6:15 PM", m) && m == 1095);
  CHECK("time: 12am is midnight", parse_time("12am", m) && m == 0);
  CHECK("time: 12pm is noon", parse_time("12pm", m) && m == 720);
  CHECK("time: bare 5 is rejected", !parse_time("5", m));
  CHECK("time: 24:00 is rejected", !parse_time("24:00", m));
  CHECK("time: 5:7 is rejected", !parse_time("5:7", m));
  CHECK("time: 13pm is rejected", !parse_time("13pm", m));

  int starts[MAX_STARTS], n;
  CHECK("starts: sorted, repeats dropped", parse_starts("18:30, 5:00, 5am", starts, n, err) && n == 2 &&
                                               starts[0] == 300 && starts[1] == 1110);
  CHECK("starts: empty is none", parse_starts(" ", starts, n, err) && n == 0);
  CHECK("starts: at most 4", !parse_starts("1:00,2:00,3:00,4:00,5:00", starts, n, err));
  CHECK("starts: bad time named", !parse_starts("5:00, 25:00", starts, n, err) &&
                                      err == "'25:00' isn't a time (like 5:30 or 6pm)");

  int from, to;
  CHECK("window: 10:00-16:00", parse_window("10:00-16:00", from, to, err) && from == 600 && to == 960);
  CHECK("window: 10am - 4pm", parse_window("10am - 4pm", from, to, err) && from == 600 && to == 960);
  CHECK("window: empty is none", parse_window("", from, to, err) && from == -1);
  CHECK("window: one time is rejected", !parse_window("10:00", from, to, err) && from == -1);

  std::vector<int> zl;
  CHECK("zone list: in the order typed", parse_zone_list("3, 1 5", zl, err) && zl == (std::vector<int>{3, 1, 5}));
  CHECK("zone list: a range", parse_zone_list("2-4", zl, err) && zl == (std::vector<int>{2, 3, 4}));
  CHECK("zone list: all", parse_zone_list("ALL", zl, err) && zl.size() == 8 && zl[0] == 1);
  CHECK("zone list: repeats dropped", parse_zone_list("1,1,2", zl, err) && zl == (std::vector<int>{1, 2}));
  CHECK("zone list: 9 is rejected", !parse_zone_list("1, 9", zl, err) && err == "'9' isn't a zone (1-8)");
  CHECK("zone list: empty is rejected", !parse_zone_list("", zl, err));

  int pct[12];
  bool set;
  CHECK("monthly: empty is none", parse_monthly("", pct, set, err) && !set);
  CHECK("monthly: 12 values", parse_monthly("60,60,80,100,120,120,120,120,100,80,60,60", pct, set, err) && set &&
                                  pct[0] == 60 && pct[6] == 120);
  CHECK("monthly: 11 values rejected", !parse_monthly("1,2,3,4,5,6,7,8,9,10,11", pct, set, err));
  CHECK("monthly: over 300 rejected", !parse_monthly("301,1,1,1,1,1,1,1,1,1,1,1", pct, set, err));
}

static void days_and_guard() {
  Program p;
  p.mode = DayMode::WEEKDAYS;
  p.days = 0x24;  // Wed, Sat
  CHECK("weekdays: Wed 2026-10-28 runs", day_matches(p, day(2026, 10, 28)));
  CHECK("weekdays: Thu 2026-10-29 doesn't", !day_matches(p, day(2026, 10, 29)));

  p.mode = DayMode::INTERVAL;
  p.interval = 3;
  p.anchor = day(2026, 10, 29);
  CHECK("interval: the anchor day runs", day_matches(p, day(2026, 10, 29)));
  CHECK("interval: +1 doesn't", !day_matches(p, day(2026, 10, 30)));
  CHECK("interval: +3 runs", day_matches(p, day(2026, 11, 1)));
  CHECK("interval: before the anchor doesn't", !day_matches(p, day(2026, 10, 26)));

  p.mode = DayMode::ODD;
  CHECK("odd: the 29th runs", day_matches(p, day(2026, 10, 29)));
  CHECK("odd: the 31st doesn't", !day_matches(p, day(2026, 10, 31)));
  CHECK("odd: Feb 29 doesn't", !day_matches(p, day(2028, 2, 29)));
  p.mode = DayMode::EVEN;
  CHECK("even: the 30th runs", day_matches(p, day(2026, 10, 30)));

  Guard g;
  g.mode = GuardMode::BLOCK;
  g.days = 0x60;  // Sat, Sun
  g.no_from = 600;
  g.no_to = 960;
  CHECK("guard: weekday not allowed", guard_problem(g, day(2026, 10, 29), 300) == "not an allowed watering day");
  CHECK("guard: Saturday early is fine", guard_problem(g, day(2026, 10, 31), 300).empty());
  CHECK("guard: Saturday noon is in the window", guard_problem(g, day(2026, 10, 31), 720) == "inside the no-water hours");
  CHECK("guard: window end is open", guard_problem(g, day(2026, 10, 31), 960).empty());
  g.mode = GuardMode::OFF;
  CHECK("guard off objects to nothing", guard_problem(g, day(2026, 10, 29), 720).empty());
  CHECK("window wrapping midnight", in_window(1320, 360, 30) && in_window(1320, 360, 1330) && !in_window(1320, 360, 720));
}

static void minutes() {
  CHECK("seasonal 100%", adjusted_minutes(20, 100) == 20);
  CHECK("seasonal 70% rounds", adjusted_minutes(15, 70) == 11);  // 10.5
  CHECK("seasonal never rounds a run to 0", adjusted_minutes(1, 10) == 1);
  CHECK("seasonal: 0 stays 0", adjusted_minutes(0, 150) == 0);
  Zone z;
  z.max_minutes = 30;
  Guard g;
  CHECK("cap: the zone's max", capped_minutes(45, z, g) == 30);
  g.mode = GuardMode::BLOCK;
  g.max_minutes = 20;
  CHECK("cap: the guard's max when it blocks", capped_minutes(45, z, g) == 20);
  g.mode = GuardMode::WARN;
  CHECK("cap: a warning guard doesn't cap", capped_minutes(45, z, g) == 30);
}

static void planning() {
  auto plan = plan_run({{1, 600}, {2, 300}}, 0);
  CHECK("plan: zones in order", plan == (std::vector<Segment>{{1, 600}, {2, 300}}));
  plan = plan_run({{1, 600}, {2, 300}}, 5);
  CHECK("plan: a gap between zones", plan == (std::vector<Segment>{{1, 600}, {0, 5}, {2, 300}}));
  // Zone 1: 20 min in 10 min cycles with a 15 min soak; zone 2: 10 min straight. Zone 2 runs
  // while zone 1 soaks, then the rest of the soak is waited out.
  plan = plan_run({{1, 1200, 600, 900}, {2, 600}}, 0);
  CHECK("plan: cycle and soak overlap other zones",
        plan == (std::vector<Segment>{{1, 600}, {2, 600}, {0, 300}, {1, 600}}));
  plan = plan_run({{1, 1200, 600, 0}}, 0);
  CHECK("plan: cycles without a soak are one run", plan == (std::vector<Segment>{{1, 1200}}));
  CHECK("plan: total time", total_secs(plan_run({{1, 1200, 600, 900}, {2, 600}}, 0)) == 2100);
  CHECK("plan: nothing to run", plan_run({}, 5).empty());
}

static void next_runs() {
  Program progs[MAX_PROGRAMS];
  Zone zones[MAX_ZONES];
  Guard g;
  progs[0].enabled = true;
  progs[0].mode = DayMode::WEEKDAYS;
  progs[0].days = 0x24;  // Wed, Sat
  progs[0].starts[0] = 300;
  progs[0].n_starts = 1;
  progs[0].minutes[0] = 10;
  const int thu = day(2026, 10, 29);
  When w = next_run(progs, zones, 100, g, 0, thu, 600, 0);
  CHECK("next: Saturday 5:00", w.day == day(2026, 10, 31) && w.minute == 300 && w.program == 0);
  w = next_run(progs, zones, 100, g, 0, day(2026, 10, 31), 200, 0);
  CHECK("next: later today", w.day == day(2026, 10, 31) && w.minute == 300);
  w = next_run(progs, zones, 100, g, 0, thu, 600, day(2026, 11, 2));
  CHECK("next: after a rain delay", w.day == day(2026, 11, 4) && w.minute == 300);
  zones[0].enabled = false;
  w = next_run(progs, zones, 100, g, 0, thu, 600, 0);
  CHECK("next: nothing when its only zone is off", !w.found());
  zones[0].enabled = true;
  w = next_run(progs, zones, 100, g, 1, thu, 600, 0);
  CHECK("next: nothing when its only zone is the master valve", !w.found());
  g.mode = GuardMode::BLOCK;
  g.days = 0x40;  // Sundays only
  w = next_run(progs, zones, 100, g, 0, thu, 600, 0);
  CHECK("next: nothing when the guard blocks every run", !w.found());
  g.mode = GuardMode::WARN;
  w = next_run(progs, zones, 100, g, 0, thu, 600, 0);
  CHECK("next: a warning guard still runs", w.day == day(2026, 10, 31));
  g.mode = GuardMode::OFF;
  progs[1] = progs[0];
  progs[1].days = 0x7f;
  progs[1].starts[0] = 1200;
  w = next_run(progs, zones, 100, g, 0, thu, 600, 0);
  CHECK("next: the earliest of two programs", w.day == thu && w.minute == 1200 && w.program == 1);
}

static void runner() {
  Runner r;
  r.start({{1, 60}, {0, 5}, {2, 30}}, 1000, true, false);
  CHECK("runner: first zone opens", r.tick(1000) == 1 && r.scheduled());
  CHECK("runner: still zone 1 at 59 s", r.tick(1059) == 1 && r.step_left(1059) == 1);
  CHECK("runner: gap after zone 1", r.tick(1060) == 0 && r.busy());
  CHECK("runner: zone 2 after the gap", r.tick(1065) == 2 && r.total_left(1065) == 30);
  CHECK("runner: done", r.tick(1095) == 0 && !r.busy());

  r.start({{1, 60}, {0, 5}, {2, 30}}, 0, true, false);
  CHECK("runner: catches up after a late tick", r.tick(70) == 2 && r.step_left(70) == 25);

  r.start({{1, 60}, {0, 5}, {2, 30}, {0, 5}, {3, 30}}, 0, false, false);
  CHECK("runner: knows a zone is waiting", r.has_zone(2) && r.has_zone(3) && !r.has_zone(4));
  r.stop_zone(2, 10);
  CHECK("runner: a stopped zone is dropped", r.tick(10) == 1 && r.total_left(10) == 85 && r.next_zone() == 3);
  r.stop_zone(1, 20);
  CHECK("runner: stopping the open zone moves on", r.tick(20) == 0 && r.busy());
  CHECK("runner: ...to the next one", r.tick(25) == 3);
  r.stop_zone(3, 30);
  CHECK("runner: stopping the last zone ends it", r.tick(30) == 0 && !r.busy());

  r.start({{1, 60}}, 0, true, false);
  r.start({{2, 60}}, 10, true, true);
  CHECK("runner: a second scheduled run waits its turn", r.tick(10) == 1 && r.tick(60) == 2);
  r.start({{3, 60}}, 70, false, false);
  CHECK("runner: a manual run replaces it", r.tick(70) == 3 && !r.scheduled());
  r.stop();
  CHECK("runner: stop closes everything", r.tick(80) == 0 && !r.busy());
  r.start({{0, 30}}, 0, false, false);
  CHECK("runner: only a pause is nothing", r.tick(0) == 0 && !r.busy());
}

int main() {
  dates();
  parsing();
  days_and_guard();
  minutes();
  planning();
  next_runs();
  runner();
  std::printf("%d failure(s)\n", failures);
  return failures;
}

#pragma once
// Small helpers the screen's LVGL lambdas use to read the A8's mirrored zones.
#include "a8_link_client.h"
#include <cmath>
#include <ctime>
#include <algorithm>
#include <vector>
#include <string>

namespace ui {

inline a8link::Client &link() { return a8link::client(); }

// "switch.left_front" -> "left_front": the stem the zone's other entities share.
inline std::string zone_stem(int n) {
  const std::string &k = link().zone_key(n);
  auto dot = k.find('.');
  return dot == std::string::npos ? std::string() : k.substr(dot + 1);
}
inline std::string zone_name(int n) {
  std::string nm = link().get("text.zone_" + std::to_string(n) + "_name");  // renamed on the screen / in HA
  if (nm.empty()) nm = link().name(link().zone_key(n));
  return nm.empty() ? "Zone " + std::to_string(n) : nm;
}
inline std::string zkey(int n, const char *domain, const char *suffix) {
  return std::string(domain) + "." + zone_stem(n) + suffix;
}
inline bool zone_running(int n) { return link().get(link().zone_key(n)) == "1"; }
inline bool zone_enabled(int n) { return link().get(zkey(n, "switch", "_enabled")) != "0"; }
inline int zone_number(int n, const char *suffix) {
  const float v = link().get_float(zkey(n, "number", suffix));
  return std::isnan(v) ? 0 : (int) lroundf(v);
}
inline bool any_running() {
  for (int n = 1; n <= 8; n++)
    if (zone_running(n))
      return true;
  return false;
}

// "2026-10-31T22:21:59+00:00" -> seconds since 1970 (0 if it doesn't parse).
inline long parse_iso(const std::string &s) {
  int y, mo, d, h, mi, se = 0, oh = 0, om = 0;
  char sign = '+';
  if (sscanf(s.c_str(), "%d-%d-%dT%d:%d:%d%c%d:%d", &y, &mo, &d, &h, &mi, &se, &sign, &oh, &om) < 5)
    return 0;
  // days from civil (Howard Hinnant)
  y -= mo <= 2;
  const long era = (y >= 0 ? y : y - 399) / 400;
  const long yoe = y - era * 400;
  const long doy = (153 * (mo + (mo > 2 ? -3 : 9)) + 2) / 5 + d - 1;
  const long days = era * 146097 + yoe * 365 + yoe / 4 - yoe / 100 + doy - 719468;
  long t = days * 86400 + h * 3600 + mi * 60 + se;
  const long off = (oh * 60 + om) * 60;
  return sign == '-' ? t + off : t - off;
}

// "4:07" from seconds.
inline std::string mmss(long s) {
  char b[16];
  snprintf(b, sizeof(b), "%ld:%02ld", s / 60, s % 60);
  return b;
}

// The second line of a zone tile.
inline std::string zone_info(int n, long now) {
  if (zone_running(n)) {
    const long left = link().seconds_left();
    return left > 0 ? "Running " + mmss(left) : std::string("Running");
  }
  if (!zone_enabled(n))
    return "Off";
  const long t = parse_iso(link().get(zkey(n, "text_sensor", "_last_run")));
  if (t == 0 || now <= 0)
    return "Never run";
  const long ago = now - t;
  if (ago < 3600)
    return "Ran " + std::to_string(std::max(1L, ago / 60)) + " min ago";
  if (ago < 86400)
    return "Ran " + std::to_string(ago / 3600) + " h ago";
  return "Ran " + std::to_string(ago / 86400) + (ago < 2 * 86400 ? " day ago" : " days ago");
}

}  // namespace ui

// ── Programs A-D (the A8's "program_a" ... entities) ──
namespace ui {

inline std::string pkey(int p, const char *domain, const char *suffix) {
  return std::string(domain) + ".program_" + (char) ('a' + p) + suffix;  // p = 0..3
}
inline bool prog_on(int p) { return link().get(pkey(p, "switch", "")) == "1"; }
inline std::string prog_mode(int p) { return link().get(pkey(p, "select", "_day_mode")); }
inline int prog_every(int p) {
  const float v = link().get_float(pkey(p, "number", "_every_n_days"));
  return std::isnan(v) ? 2 : (int) lroundf(v);
}
inline int prog_starts_in(int p) {  // every N days: days to the next watering day
  const float v = link().get_float(pkey(p, "number", "_starts_in"));
  return std::isnan(v) ? 0 : (int) lroundf(v);
}
inline int prog_minutes(int p, int zone) {
  const float v = link().get_float(pkey(p, "number", ("_zone_" + std::to_string(zone) + "_minutes").c_str()));
  return std::isnan(v) ? 0 : (int) lroundf(v);
}
inline void set_prog_minutes(int p, int zone, int m) {
  link().set(pkey(p, "number", ("_zone_" + std::to_string(zone) + "_minutes").c_str()), std::to_string(std::max(0, m)));
}

// Days text <-> mask (bit 0 = Mon ... bit 6 = Sun), in the A8's words ("mon, wed, fri", "daily").
inline uint8_t days_mask(const std::string &text) {
  static const char *const n3[7] = {"mon", "tue", "wed", "thu", "fri", "sat", "sun"};
  std::string t;
  for (char c : text) t += (char) tolower((unsigned char) c);
  if (t.find("daily") != std::string::npos || t.find("all") != std::string::npos || t.find("every") != std::string::npos)
    return 0x7f;
  uint8_t m = 0;
  if (t.find("weekdays") != std::string::npos) m |= 0x1f;
  if (t.find("weekends") != std::string::npos) m |= 0x60;
  for (int d = 0; d < 7; d++)
    if (t.find(n3[d]) != std::string::npos) m |= 1 << d;
  return m;
}
inline std::string days_text(uint8_t m) {
  static const char *const n3[7] = {"mon", "tue", "wed", "thu", "fri", "sat", "sun"};
  if ((m & 0x7f) == 0x7f) return "daily";
  std::string s;
  for (int d = 0; d < 7; d++)
    if (m & (1 << d)) s += std::string(s.empty() ? "" : ", ") + n3[d];
  return s;
}
inline uint8_t prog_days(int p) { return days_mask(link().get(pkey(p, "text", "_days"))); }

// Start times: the A8's text ("6:00, 18:30", "6am") <-> minutes of the day, sorted.
inline std::vector<int> starts(int p) {
  std::vector<int> out;
  std::string t = link().get(pkey(p, "text", "_start_times"));
  size_t i = 0;
  while (i < t.size()) {
    size_t j = t.find_first_of(",;", i);
    std::string part = t.substr(i, j == std::string::npos ? std::string::npos : j - i);
    i = j == std::string::npos ? t.size() : j + 1;
    std::string s;
    for (char c : part) if (!isspace((unsigned char) c)) s += (char) tolower((unsigned char) c);
    if (s.empty()) continue;
    int ampm = 0;
    if (s.size() > 2 && (s.substr(s.size() - 2) == "am" || s.substr(s.size() - 2) == "pm")) {
      ampm = s[s.size() - 2] == 'a' ? 1 : 2;
      s.resize(s.size() - 2);
    }
    int h = 0, m = 0;
    if (sscanf(s.c_str(), "%d:%d", &h, &m) < 1) continue;
    if (ampm) h = h % 12 + (ampm == 2 ? 12 : 0);
    if (h >= 0 && h < 24 && m >= 0 && m < 60) out.push_back(h * 60 + m);
  }
  std::sort(out.begin(), out.end());
  out.erase(std::unique(out.begin(), out.end()), out.end());
  return out;
}
inline void set_starts(int p, std::vector<int> v) {
  std::sort(v.begin(), v.end());
  v.erase(std::unique(v.begin(), v.end()), v.end());
  if (v.size() > 4) v.resize(4);
  std::string s;
  for (int m : v) {
    char b[8];
    snprintf(b, sizeof(b), "%d:%02d", m / 60, m % 60);
    s += std::string(s.empty() ? "" : ", ") + b;
  }
  link().set(pkey(p, "text", "_start_times"), s);
}
inline std::string clock12(int minute) {
  const int h = (minute / 60) % 24, m = minute % 60, h12 = h % 12 == 0 ? 12 : h % 12;
  char b[12];
  snprintf(b, sizeof(b), "%d:%02d %s", h12, m, h < 12 ? "AM" : "PM");
  return b;
}

inline bool prog_used(int p) {
  if (prog_on(p) || !starts(p).empty()) return true;
  for (int z = 1; z <= 8; z++) if (prog_minutes(p, z) > 0) return true;
  return false;
}

// "Mon Wed Fri · 6:00 AM" and "5 zones · 42 min" for a program card.
inline std::string prog_when(int p) {
  static const char *const nm[7] = {"Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"};
  std::string mode = prog_mode(p), d;
  if (mode == "Every N days") d = "Every " + std::to_string(prog_every(p)) + " days";
  else if (mode == "Odd dates") d = "Odd dates";
  else if (mode == "Even dates") d = "Even dates";
  else {
    const uint8_t m = prog_days(p);
    if (m == 0x7f) d = "Every day";
    else if (m == 0) d = "No days";
    else for (int i = 0; i < 7; i++) if (m & (1 << i)) d += std::string(d.empty() ? "" : " ") + nm[i];
  }
  auto st = starts(p);
  std::string t = st.empty() ? "no start time" : clock12(st[0]);
  if (st.size() > 1) t += " +" + std::to_string(st.size() - 1);
  return d + "  -  " + t;
}
inline std::string prog_what(int p) {
  int zones = 0, total = 0;
  for (int z = 1; z <= 8; z++) {
    const int m = prog_minutes(p, z);
    if (m > 0 && zone_enabled(z)) { zones++; total += m; }
  }
  if (zones == 0) return "No zones yet";
  return std::to_string(zones) + (zones == 1 ? " zone" : " zones") + "  -  " + std::to_string(total) + " min";
}

}  // namespace ui

// Show / hide / colour LVGL objects from lambdas (LVGL 9). Accepts plain lv_obj_t* or ESPHome's
// widget wrappers (which carry ->obj).
#include "lvgl.h"
namespace ui {
inline lv_obj_t *as_obj(lv_obj_t *o) { return o; }
template<class T> inline lv_obj_t *as_obj(T *w) { return w->obj; }
template<class T> inline void vis(T *w, bool show) {
  lv_obj_t *o = as_obj(w);
  if (show) lv_obj_remove_flag(o, LV_OBJ_FLAG_HIDDEN);
  else lv_obj_add_flag(o, LV_OBJ_FLAG_HIDDEN);
}
template<class T> inline void bg(T *w, uint32_t rgb) {
  lv_obj_set_style_bg_color(as_obj(w), lv_color_hex(rgb), LV_PART_MAIN);
}
template<class T> inline void fg(T *w, uint32_t rgb) {
  lv_obj_set_style_text_color(as_obj(w), lv_color_hex(rgb), LV_PART_MAIN);
}
template<class T> inline void text(T *w, const std::string &s) { lv_label_set_text(as_obj(w), s.c_str()); }
template<class T> inline void checked(T *w, bool on) {
  if (on) lv_obj_add_state(as_obj(w), LV_STATE_CHECKED);
  else lv_obj_remove_state(as_obj(w), LV_STATE_CHECKED);
}
template<class T> inline int roller_index(T *w) { return (int) lv_roller_get_selected(as_obj(w)); }
}  // namespace ui

#include "esphome/core/time.h"
namespace ui {
// An A8 timestamp ("2026-11-06T08:00:00+00:00") as local, friendly text:
// "Today 3:00 AM", "Tomorrow 3:00 AM", or "Sat, Nov 8  3:00 AM".
inline std::string nice_when(const std::string &iso, long now) {
  const long t = parse_iso(iso);
  if (t == 0) return iso;
  static const char *const days[] = {"Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"};
  static const char *const months[] = {"Jan", "Feb", "Mar", "Apr", "May", "Jun",
                                       "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"};
  const auto when = esphome::ESPTime::from_epoch_local((time_t) t);
  const std::string clock = clock12(when.hour * 60 + when.minute);
  if (now > 0) {
    const auto today = esphome::ESPTime::from_epoch_local((time_t) now);
    const auto tomorrow = esphome::ESPTime::from_epoch_local((time_t) now + 86400);
    if (when.day_of_year == today.day_of_year && when.year == today.year) return "Today " + clock;
    if (when.day_of_year == tomorrow.day_of_year && when.year == tomorrow.year) return "Tomorrow " + clock;
  }
  char b[24];
  snprintf(b, sizeof(b), "%s, %s %d  ", days[(when.day_of_week + 6) % 7], months[(when.month + 11) % 12], when.day_of_month);
  return b + clock;
}
}  // namespace ui

namespace ui {
// The two halves of nice_when(): "Today" / "Tomorrow" / "Sat, Nov 8", and "3:00 AM".
inline std::string when_day(const std::string &iso, long now) {
  const long t = parse_iso(iso);
  if (t == 0) return "";
  static const char *const days[] = {"Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"};
  static const char *const months[] = {"Jan", "Feb", "Mar", "Apr", "May", "Jun",
                                       "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"};
  const auto when = esphome::ESPTime::from_epoch_local((time_t) t);
  if (now > 0) {
    const auto today = esphome::ESPTime::from_epoch_local((time_t) now);
    const auto tomorrow = esphome::ESPTime::from_epoch_local((time_t) now + 86400);
    if (when.day_of_year == today.day_of_year && when.year == today.year) return "Today";
    if (when.day_of_year == tomorrow.day_of_year && when.year == tomorrow.year) return "Tomorrow";
  }
  char b[32];
  snprintf(b, sizeof(b), "%s, %s %d", days[(when.day_of_week + 6) % 7], months[(when.month + 11) % 12], when.day_of_month);
  return b;
}
inline std::string when_time(const std::string &iso) {
  const long t = parse_iso(iso);
  if (t == 0) return "";
  const auto when = esphome::ESPTime::from_epoch_local((time_t) t);
  return clock12(when.hour * 60 + when.minute);
}
// The zone that's watering now, by name (empty if none).
inline std::string running_zone() {
  for (int n = 1; n <= 8; n++)
    if (zone_running(n)) return zone_name(n);
  return "";
}
}  // namespace ui

namespace ui {
template<class T> inline std::string ta_text(T *w) { return lv_textarea_get_text(as_obj(w)); }
template<class T> inline void ta_set(T *w, const std::string &s) { lv_textarea_set_text(as_obj(w), s.c_str()); }
}  // namespace ui

namespace ui {
// An A8 entity's key by its display name ("Rain sensor input" -> "select.rain_sensor_input").
inline std::string key_of(const char *domain, const std::string &name) {
  const std::string pre = std::string(domain) + ".";
  for (const auto &kv : link().names())
    if (kv.second == name && kv.first.compare(0, pre.size(), pre) == 0) return kv.first;
  return "";
}
inline std::string get_by_name(const char *domain, const std::string &name) {
  const std::string k = key_of(domain, name);
  return k.empty() ? std::string() : link().get(k);
}
inline void set_by_name(const char *domain, const std::string &name, const std::string &v) {
  const std::string k = key_of(domain, name);
  if (!k.empty()) link().set(k, v);
}
inline int num_by_name(const std::string &name, int dflt = 0) {
  const std::string v = get_by_name("number", name);
  return v.empty() ? dflt : (int) lroundf(strtof(v.c_str(), nullptr));
}
template<class T> inline void dd_select(T *w, int idx) { if (idx >= 0) lv_dropdown_set_selected(as_obj(w), idx); }
}  // namespace ui

#include "esphome/components/wifi/wifi_component.h"
namespace ui {
// Networks the screen has seen, strongest first, one entry per name (max 8).
inline std::vector<std::pair<std::string, int>> wifi_networks() {
  std::vector<std::pair<std::string, int>> out;
  auto *w = esphome::wifi::global_wifi_component;
  if (w == nullptr) return out;
  for (const auto &r : w->get_scan_result()) {
    if (r.get_is_hidden() || r.get_ssid().size() == 0) continue;
    std::string s(r.get_ssid().c_str(), r.get_ssid().size());
    bool seen = false;
    for (auto &e : out) if (e.first == s) { e.second = std::max(e.second, (int) r.get_rssi()); seen = true; }
    if (!seen) out.emplace_back(s, r.get_rssi());
  }
  std::sort(out.begin(), out.end(), [](auto &a, auto &b) { return a.second > b.second; });
  if (out.size() > 8) out.resize(8);
  return out;
}
// Set from the YAML's wifi_info "ssid" sensor (the driver call returned nothing here).
inline std::string &wifi_ssid_cache() { static std::string s; return s; }
inline std::string wifi_current() {
  auto *w = esphome::wifi::global_wifi_component;
  if (w == nullptr || !w->is_connected()) return "";
  return wifi_ssid_cache();
}
// Printable ASCII only (the fonts have no emoji): for showing network names.
inline std::string ascii(const std::string &s) {
  std::string o;
  for (unsigned char c : s) if (c >= 0x20 && c < 0x7f) o += (char) c;
  while (!o.empty() && o[0] == ' ') o.erase(0, 1);
  while (!o.empty() && o.back() == ' ') o.pop_back();
  return o;
}
}  // namespace ui

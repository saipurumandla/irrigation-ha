#pragma once
// Watering history, recorded by the screen from the A8's live zone states and kept in the
// screen's flash: seconds watered per zone for the last 7 days, and the last 24 runs (zone,
// start, length). Runs while the screen is off or unlinked aren't seen (HA keeps its own history).
#include "esphome/core/preferences.h"
#include "esphome/core/time.h"
#include "esphome/core/hal.h"
#include "ui.h"

namespace hist {

struct Run {
  uint32_t start;  // UTC seconds
  uint16_t secs;
  uint8_t zone;    // 1-8
  uint8_t pad;
};

struct Data {
  uint32_t version;
  int32_t day[7];          // local day number of each slot (-1 = empty)
  uint32_t secs[7][8];     // seconds watered, per slot and zone
  Run runs[24];            // newest at runs[(next + 23) % 24]
  uint32_t next;
};

static const uint32_t VERSION = 1;

// Local calendar day number (days since 1970-01-01 in local time).
inline int32_t local_day(long t) {
  const auto lt = esphome::ESPTime::from_epoch_local((time_t) t);
  int y = lt.year, m = lt.month, d = lt.day_of_month;
  y -= m <= 2;
  const long era = (y >= 0 ? y : y - 399) / 400;
  const long yoe = y - era * 400;
  const long doy = (153 * (m + (m > 2 ? -3 : 9)) + 2) / 5 + d - 1;
  return (int32_t) (era * 146097 + yoe * 365 + yoe / 4 - yoe / 100 + doy - 719468);
}

class History {
 public:
  void begin() {
    this->pref_ = esphome::global_preferences->make_preference<Data>(0x48495354u /* "HIST" */);
    if (!this->pref_.load(&this->d_) || this->d_.version != VERSION) {
      this->d_ = Data{};
      this->d_.version = VERSION;
      for (auto &x : this->d_.day) x = -1;
    }
  }

  // Once a second: notice zones starting and stopping.
  void tick(long now) {
    if (now < 1600000000L || !ui::link().up())
      return;
    for (int z = 1; z <= 8; z++) {
      const bool on = ui::zone_running(z);
      long &st = this->started_[z - 1];
      if (on && st == 0) {
        st = now;
      } else if (!on && st != 0) {
        this->add_run_(z, st, now);
        st = 0;
      }
    }
  }

  // Seconds watered by `zone` on local day `day` (zone 0 = all zones).
  uint32_t secs(int32_t day, int zone) const {
    for (int i = 0; i < 7; i++)
      if (this->d_.day[i] == day) {
        if (zone > 0) return this->d_.secs[i][zone - 1] + this->live_(day, zone);
        uint32_t t = 0;
        for (int z = 1; z <= 8; z++) t += this->d_.secs[i][z - 1] + this->live_(day, z);
        return t;
      }
    uint32_t t = 0;
    for (int z = 1; z <= 8; z++)
      if (zone == 0 || zone == z) t += this->live_(day, z);
    return t;
  }

  // Start times ("6:00 AM") of `zone`'s runs on `day`, from the run log.
  std::string starts(int32_t day, int zone) const {
    std::string s;
    for (int k = 0; k < 24; k++) {
      const Run &r = this->d_.runs[(this->d_.next + k) % 24];
      if (r.secs == 0 || r.zone != zone || local_day(r.start) != day) continue;
      const auto lt = esphome::ESPTime::from_epoch_local((time_t) r.start);
      s += std::string(s.empty() ? "" : ", ") + ui::clock12(lt.hour * 60 + lt.minute);
    }
    return s;
  }

 protected:
  // A run still going counts towards today.
  uint32_t live_(int32_t day, int zone) const {
    const long st = this->started_[zone - 1];
    if (st == 0 || this->now_() == 0 || local_day(this->now_()) != day) return 0;
    return (uint32_t) (this->now_() - st);
  }
  long now_() const { return this->last_now_; }

  void add_run_(int zone, long start, long end) {
    const uint32_t len = end > start ? (uint32_t) (end - start) : 0;
    if (len < 5) return;  // a blip, not a run
    const int32_t day = local_day(start);
    int slot = -1, oldest = 0;
    for (int i = 0; i < 7; i++) {
      if (this->d_.day[i] == day) slot = i;
      if (this->d_.day[i] < this->d_.day[oldest]) oldest = i;
    }
    if (slot < 0) {  // reuse the oldest slot for a new day
      slot = oldest;
      this->d_.day[slot] = day;
      for (auto &x : this->d_.secs[slot]) x = 0;
    }
    this->d_.secs[slot][zone - 1] += len;
    this->d_.runs[this->d_.next % 24] = Run{(uint32_t) start, (uint16_t) std::min<uint32_t>(len, 65535), (uint8_t) zone, 0};
    this->d_.next = (this->d_.next + 1) % 24;
    this->pref_.save(&this->d_);
    this->changed = true;
  }

 public:
  void set_now(long now) { this->last_now_ = now; }
  bool changed{false};

 protected:
  esphome::ESPPreferenceObject pref_;
  Data d_{};
  long started_[8]{};
  long last_now_{0};
};

inline History &history() {
  static History h;
  return h;
}

}  // namespace hist

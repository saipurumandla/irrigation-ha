#pragma once
// Screen side of the wired link to the A8 (see ../irrigation/a8_link.h for the protocol).
// Keeps a copy of every A8 entity's state; the UI reads it and sends SET / PRESS back. The A8
// stays the source of truth: nothing here is a setting of its own.
#include "esphome/core/hal.h"
#include "esphome/core/log.h"
#include "esphome/components/uart/uart_component.h"
#include <map>
#include <string>

namespace a8link {
using namespace esphome;

static const char *const LINK_TAG = "a8link";

inline uint8_t checksum(const std::string &s) {
  uint8_t c = 0;
  for (char ch : s) c ^= (uint8_t) ch;
  return c;
}

class Client {
 public:
  void begin(uart::UARTComponent *uart) { this->uart_ = uart; }

  // Call often: reads lines from the A8.
  void poll() {
    if (this->uart_ == nullptr)
      return;
    uint8_t c;
    while (this->uart_->available() && this->uart_->read_byte(&c)) {
      if (c == '\n') {
        this->line_(this->rx_);
        this->rx_.clear();
      } else if (c != '\r' && this->rx_.size() < 512) {
        this->rx_ += (char) c;
      }
    }
  }

  // Call once a second: asks for a full copy whenever the link (re)appears.
  void tick() {
    if (!this->up()) {
      this->synced_ = false;
      return;
    }
    if (!this->synced_) {
      this->send_("SYNC");
      this->synced_ = true;
    }
  }

  // Seconds left in the current run, counting down smoothly between heartbeats (0 = idle).
  long seconds_left() const {
    if (this->left_s_ <= 0 || !this->up())
      return 0;
    return std::max(0L, this->left_s_ - (long) ((millis() - this->last_hb_) / 1000));
  }
  bool up() const { return this->last_hb_ != 0 && millis() - this->last_hb_ < 3500; }
  // True once after anything changed (or the link went up or down), for the UI to refresh.
  bool take_changed() {
    const bool up = this->up();
    const bool c = this->changed_ || up != this->was_up_;
    this->changed_ = false;
    this->was_up_ = up;
    return c;
  }
  std::string get(const std::string &key) const {
    auto it = this->state_.find(key);
    return it == this->state_.end() ? std::string() : it->second;
  }
  float get_float(const std::string &key) const {
    const std::string v = this->get(key);
    return v.empty() ? NAN : strtof(v.c_str(), nullptr);
  }
  std::string name(const std::string &key) const {
    auto it = this->names_.find(key);
    return it == this->names_.end() ? std::string() : it->second;
  }
  const std::map<std::string, std::string> &names() const { return this->names_; }
  // Zone n's switch key ("switch.left_front"), from the A8's "Z" lines; empty until synced.
  const std::string &zone_key(int n) const { return this->zones_[(n - 1) & 7]; }
  void set(const std::string &key, const std::string &value) { this->send_("SET " + key + " " + value); }
  void press(const std::string &key) { this->send_("PRESS " + key); }
  // Hand the A8 new Wi-Fi settings (it joins with wifi.configure and falls back if they fail).
  void send_wifi(const std::string &ssid, const std::string &password) { this->send_("WIFI " + ssid + "\t" + password); }

 protected:
  void send_(const std::string &payload) {
    if (this->uart_ == nullptr)
      return;
    char tail[8];
    snprintf(tail, sizeof(tail), "*%02X\n", checksum(payload));
    this->uart_->write_str((payload + tail).c_str());
  }

  void line_(const std::string &raw) {
    auto star = raw.rfind('*');
    if (star == std::string::npos || star + 3 != raw.size())
      return;
    const std::string payload = raw.substr(0, star);
    if (strtoul(raw.c_str() + star + 1, nullptr, 16) != checksum(payload)) {
      ESP_LOGW(LINK_TAG, "Bad checksum, line dropped");
      return;
    }
    if (payload.size() < 2 || payload[1] != ' ')
      return;
    if (payload[0] == 'H') {
      this->last_hb_ = millis();
      const auto sp = payload.find(' ', 2);  // "H <uptime> <seconds left>"
      const long left = sp == std::string::npos ? 0 : atol(payload.c_str() + sp + 1);
      if ((left > 0) != (this->left_s_ > 0))
        this->changed_ = true;
      this->left_s_ = left;
      // Self-heal: the A8 says nothing is running but a zone still shows on here (a lost "off"
      // line): after 3 heartbeats in a row like that, ask for a fresh copy of everything.
      bool shown = false;
      for (const auto &k : this->zones_)
        if (!k.empty() && this->get(k) == "1")
          shown = true;
      if (left <= 0 && shown) {
        if (++this->stale_ >= 3) {
          ESP_LOGW(LINK_TAG, "A zone shows running but the A8 is idle: resyncing");
          this->send_("SYNC");
          this->stale_ = 0;
        }
      } else {
        this->stale_ = 0;
      }
      return;
    }
    const auto sp = payload.find(' ', 2);
    const std::string key = payload.substr(2, sp == std::string::npos ? std::string::npos : sp - 2);
    const std::string val = sp == std::string::npos ? "" : payload.substr(sp + 1);
    if (payload[0] == 'S') {
      auto &slot = this->state_[key];
      if (slot != val) {
        slot = val;
        this->changed_ = true;
      }
    } else if (payload[0] == 'Z') {
      const int n = atoi(key.c_str());  // "Z <n> <switch key>"
      if (n >= 1 && n <= 8 && this->zones_[n - 1] != val) {
        this->zones_[n - 1] = val;
        this->changed_ = true;
      }
    } else if (payload[0] == 'N') {
      if (this->names_[key] != val)
        ESP_LOGD(LINK_TAG, "%s = \"%s\"", key.c_str(), val.c_str());
      this->names_[key] = val;
    }
  }

  uart::UARTComponent *uart_{nullptr};
  std::map<std::string, std::string> state_, names_;
  std::string rx_;
  std::string zones_[8];
  uint32_t last_hb_{0};
  int stale_{0};
  long left_s_{0};
  bool synced_{false}, changed_{false}, was_up_{false};
};

inline Client &client() {
  static Client c;
  return c;
}

}  // namespace a8link

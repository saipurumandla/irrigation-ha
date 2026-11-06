#pragma once
// A8 side of the wired link to the irrigation screen (UART on the A8's S1 = TX / S2 = RX).
//
// The screen mirrors the A8's entities instead of having its own settings, so the A8 stays the one
// source of truth and HA, the screen and the A8 never disagree:
//   A8 -> screen   "N <key> <name>"   an entity's display name (sent with every full dump)
//                  "S <key> <value>"  an entity's state: all of them on SYNC, then every change
//                  "H <uptime s> <left s>"  heartbeat, once a second (the link icon), with the
//                                     seconds left in the current run (the screen's countdown)
//                  "Z <n> <key>"      zone n's switch (1-8), so the screen needn't guess from names
//   screen -> A8   "SYNC"             send everything
//                  "SET <key> <v>"    set a switch (1/0), number, select or text, through the
//                                     same calls HA uses (so caps and checks still apply)
//                  "PRESS <key>"      press a button
//                  "WIFI <ssid>\t<password>"  join this network (wifi.configure: saved, and it falls
//                                     back to the old network if the new one doesn't connect)
// Keys are "<domain>.<object_id>", e.g. "switch.left_front", "number.rain_delay". Every line ends
// "*XX\n", XX = the XOR of the payload's bytes in hex; lines that don't match are dropped.
#include "esphome/core/application.h"
#include "esphome/core/hal.h"
#include "esphome/components/uart/uart_component.h"
#include <functional>
#include <map>
#include <string>
#include <vector>

namespace a8link {
using namespace esphome;

inline uint8_t checksum(const std::string &s) {
  uint8_t c = 0;
  for (char ch : s) c ^= (uint8_t) ch;
  return c;
}

class Server {
 public:
  void begin(uart::UARTComponent *uart) {
    this->uart_ = uart;
#ifdef USE_SWITCH
    for (auto *e : App.get_switches()) {
      auto k = this->add_(e, "switch", 's');
      e->add_on_state_callback([this, k, e](bool) { this->state_(k, e); });
    }
#endif
#ifdef USE_NUMBER
    for (auto *e : App.get_numbers()) {
      auto k = this->add_(e, "number", 'n');
      e->add_on_state_callback([this, k, e](float) { this->state_(k, e); });
    }
#endif
#ifdef USE_SELECT
    for (auto *e : App.get_selects()) {
      auto k = this->add_(e, "select", 'l');
      e->add_on_state_callback([this, k, e](size_t) { this->state_(k, e); });
    }
#endif
#ifdef USE_TEXT
    for (auto *e : App.get_texts()) {
      auto k = this->add_(e, "text", 't');
      e->add_on_state_callback([this, k, e](const std::string &) { this->state_(k, e); });
    }
#endif
#ifdef USE_SENSOR
    for (auto *e : App.get_sensors()) {
      auto k = this->add_(e, "sensor", 'e');
      e->add_on_state_callback([this, k, e](float) { this->state_(k, e); });
    }
#endif
#ifdef USE_TEXT_SENSOR
    for (auto *e : App.get_text_sensors()) {
      auto k = this->add_(e, "text_sensor", 'x');
      e->add_on_state_callback([this, k, e](const std::string &) { this->state_(k, e); });
    }
#endif
#ifdef USE_BINARY_SENSOR
    for (auto *e : App.get_binary_sensors()) {
      auto k = this->add_(e, "binary_sensor", 'b');
      e->add_on_state_callback([this, k, e](bool) { this->state_(k, e); });
    }
#endif
#ifdef USE_BUTTON
    for (auto *e : App.get_buttons()) this->add_(e, "button", 'p');
#endif
  }

  // Called with (ssid, password) when the screen sends Wi-Fi settings.
  void on_wifi(std::function<void(const std::string &, const std::string &)> cb) { this->wifi_cb_ = std::move(cb); }

  // Zone switches in order (zone 1 first), announced with every dump.
  void set_zones(std::vector<EntityBase *> zones) { this->zones_ = std::move(zones); }

  // Call often (every loop): reads commands and trickles out a pending full dump.
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
    // A dump is ~2 lines per entity; send a few per call so the loop never stalls.
    for (int n = 0; n < 6 && this->dump_pos_ < this->order_.size(); n++, this->dump_pos_++) {
      const auto &k = this->order_[this->dump_pos_];
      auto &ent = this->ents_[k];
      this->send_("N " + k + " " + clean_(std::string(ent.base->get_name().c_str())));
      if (ent.kind != 'p')
        this->send_("S " + k + " " + this->value_(ent));
    }
  }

  void heartbeat(uint32_t seconds_left) {
    this->send_("H " + std::to_string(millis() / 1000) + " " + std::to_string(seconds_left));
  }

 protected:
  struct Ent {
    char kind;  // s switch, n number, l select, t text, e sensor, x text sensor, b binary, p button
    EntityBase *base;
  };

  std::string add_(EntityBase *e, const char *domain, char kind) {
    char buf[OBJECT_ID_MAX_LEN];
    e->write_object_id_to(buf, sizeof(buf));
    std::string k = std::string(domain) + "." + buf;
    this->ents_[k] = Ent{kind, e};
    this->order_.push_back(k);
    return k;
  }

  static std::string clean_(std::string v) {
    for (auto &ch : v)
      if (ch == '\n' || ch == '\r' || ch == '*')
        ch = ' ';
    return v;
  }

  static std::string num_(float f) {
    if (std::isnan(f))
      return "";
    char b[24];
    snprintf(b, sizeof(b), "%g", f);
    return b;
  }

  std::string value_(const Ent &ent) {
    switch (ent.kind) {
#ifdef USE_SWITCH
      case 's': return static_cast<switch_::Switch *>(ent.base)->state ? "1" : "0";
#endif
#ifdef USE_NUMBER
      case 'n': {
        auto *n = static_cast<number::Number *>(ent.base);
        return n->has_state() ? num_(n->state) : "";
      }
#endif
#ifdef USE_SELECT
      case 'l': {
        auto r = static_cast<select::Select *>(ent.base)->current_option();
        return std::string(r.c_str(), r.size());
      }
#endif
#ifdef USE_TEXT
      case 't': return clean_(static_cast<text::Text *>(ent.base)->state);
#endif
#ifdef USE_SENSOR
      case 'e': {
        auto *s = static_cast<sensor::Sensor *>(ent.base);
        return s->has_state() ? num_(s->state) : "";
      }
#endif
#ifdef USE_TEXT_SENSOR
      case 'x': return clean_(static_cast<text_sensor::TextSensor *>(ent.base)->state);
#endif
#ifdef USE_BINARY_SENSOR
      case 'b': return static_cast<binary_sensor::BinarySensor *>(ent.base)->state ? "1" : "0";
#endif
      default: return "";
    }
  }

  void state_(const std::string &k, EntityBase *) {
    auto it = this->ents_.find(k);
    if (it != this->ents_.end())
      this->send_("S " + k + " " + this->value_(it->second));
  }

  void send_(const std::string &payload) {
    if (this->uart_ == nullptr)  // the heartbeat can tick before begin() at boot
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
    if (strtoul(raw.c_str() + star + 1, nullptr, 16) != checksum(payload))
      return;
    if (payload == "SYNC") {
      for (size_t i = 0; i < this->zones_.size(); i++) {
        char buf[OBJECT_ID_MAX_LEN];
        this->zones_[i]->write_object_id_to(buf, sizeof(buf));
        this->send_("Z " + std::to_string(i + 1) + " switch." + buf);
      }
      this->dump_pos_ = 0;
      return;
    }
    if (payload.compare(0, 5, "WIFI ") == 0) {
      const auto tab = payload.find('\t', 5);
      if (tab != std::string::npos && this->wifi_cb_)
        this->wifi_cb_(payload.substr(5, tab - 5), payload.substr(tab + 1));
      return;
    }
    const auto sp1 = payload.find(' ');
    const std::string cmd = payload.substr(0, sp1);
    if (sp1 == std::string::npos)
      return;
    const auto sp2 = payload.find(' ', sp1 + 1);
    const std::string key = payload.substr(sp1 + 1, sp2 == std::string::npos ? std::string::npos : sp2 - sp1 - 1);
    const std::string val = sp2 == std::string::npos ? "" : payload.substr(sp2 + 1);
    auto it = this->ents_.find(key);
    if (it == this->ents_.end())
      return;
    Ent &ent = it->second;
    if (cmd == "PRESS") {
#ifdef USE_BUTTON
      if (ent.kind == 'p')
        static_cast<button::Button *>(ent.base)->press();
#endif
      return;
    }
    if (cmd != "SET")
      return;
    switch (ent.kind) {
#ifdef USE_SWITCH
      case 's':
        if (val == "1")
          static_cast<switch_::Switch *>(ent.base)->turn_on();
        else
          static_cast<switch_::Switch *>(ent.base)->turn_off();
        break;
#endif
#ifdef USE_NUMBER
      case 'n': {
        auto call = static_cast<number::Number *>(ent.base)->make_call();
        call.set_value(strtof(val.c_str(), nullptr));
        call.perform();
        break;
      }
#endif
#ifdef USE_SELECT
      case 'l': static_cast<select::Select *>(ent.base)->make_call().set_option(val).perform(); break;
#endif
#ifdef USE_TEXT
      case 't': {
        auto call = static_cast<text::Text *>(ent.base)->make_call();
        call.set_value(val);
        call.perform();
        break;
      }
#endif
      default: break;
    }
  }

  uart::UARTComponent *uart_{nullptr};
  std::map<std::string, Ent> ents_;
  std::vector<std::string> order_;
  std::vector<EntityBase *> zones_;
  std::function<void(const std::string &, const std::string &)> wifi_cb_;
  size_t dump_pos_{SIZE_MAX};
  std::string rx_;
};

inline Server &server() {
  static Server s;
  return s;
}

}  // namespace a8link

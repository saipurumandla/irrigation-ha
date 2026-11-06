#pragma once
#ifdef USE_ESP32_VARIANT_ESP32S3
#include "esphome/components/display/display.h"
#include "esphome/core/component.h"
#include "esp_lcd_panel_io.h"
#include "esp_lcd_panel_ops.h"
#include "freertos/FreeRTOS.h"
#include "freertos/semphr.h"

namespace esphome::st77922_qspi {

// A full RGB565 frame lives in PSRAM (big-endian, the panel's byte order). Drawing updates it, then
// the touched rows are sent with column edges widened to multiples of 4: the ST77922 needs its
// column start/end aligned, and the frame copy supplies the extra pixels.
class ST77922QSPI : public display::Display {
 public:
  void setup() override;
  void update() override;
  void loop() override;
  void dump_config() override;
  float get_setup_priority() const override { return setup_priority::HARDWARE; }

  void set_dimensions(uint16_t w, uint16_t h) {
    this->width_ = w;
    this->height_ = h;
  }
  void set_pins(int cs, int clk, int d0, int d1, int d2, int d3) {
    this->cs_ = cs;
    this->clk_ = clk;
    this->d_[0] = d0;
    this->d_[1] = d1;
    this->d_[2] = d2;
    this->d_[3] = d3;
  }
  void set_reset_pin(int pin) { this->reset_ = pin; }
  void set_te_pin(int pin) { this->te_ = pin; }
  void set_pclk(uint32_t hz) { this->pclk_ = hz; }
  void set_invert_colors(bool v) { this->invert_ = v; }

  display::DisplayType get_display_type() override { return display::DISPLAY_TYPE_COLOR; }
  void draw_pixel_at(int x, int y, Color color) override;
  void draw_pixels_at(int x_start, int y_start, int w, int h, const uint8_t *ptr, display::ColorOrder order,
                      display::ColorBitness bitness, bool big_endian, int x_offset, int y_offset,
                      int x_pad) override;
  void fill(Color color) override;

 protected:
  int get_width_internal() override { return this->width_; }
  int get_height_internal() override { return this->height_; }
  void flush_(int x0, int y0, int x1, int y1);  // inclusive, panel coordinates
  static bool on_trans_done_(esp_lcd_panel_io_handle_t io, esp_lcd_panel_io_event_data_t *edata, void *ctx);

  uint16_t width_{320}, height_{480};
  int reset_{-1};
  int te_{-1};
  bool pending_{false};
  int cs_{-1}, clk_{-1}, d_[4]{-1, -1, -1, -1};
  uint32_t pclk_{40000000};
  bool invert_{false};
  esp_lcd_panel_io_handle_t io_{nullptr};
  esp_lcd_panel_handle_t panel_{nullptr};
  uint16_t *frame_{nullptr};  // PSRAM, width_ * height_
  uint16_t *dma_{nullptr};    // internal DMA RAM, width_ * kDmaRows
  SemaphoreHandle_t done_{nullptr};
  // Pixels set one at a time (writer lambdas, the test card) are flushed together in update().
  int dirty_x0_{INT16_MAX}, dirty_y0_{INT16_MAX}, dirty_x1_{-1}, dirty_y1_{-1};
  static constexpr int kDmaRows = 24;
};

}  // namespace esphome::st77922_qspi
#endif

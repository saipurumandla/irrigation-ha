#ifdef USE_ESP32_VARIANT_ESP32S3
#include "st77922_qspi.h"
#include "esphome/core/log.h"
#include "driver/spi_master.h"
#include "driver/gpio.h"
#include "esphome/core/hal.h"
#include "esp_heap_caps.h"
#include "esp_lcd_st77922.h"
#include "es3c35p_init.h"
#include <algorithm>
#include <cstring>

namespace esphome::st77922_qspi {

static const char *const TAG = "st77922_qspi";

bool ST77922QSPI::on_trans_done_(esp_lcd_panel_io_handle_t, esp_lcd_panel_io_event_data_t *, void *ctx) {
  auto *self = static_cast<ST77922QSPI *>(ctx);
  BaseType_t woken = pdFALSE;
  xSemaphoreGiveFromISR(self->done_, &woken);
  return woken == pdTRUE;
}

void ST77922QSPI::setup() {
  const size_t pixels = (size_t) this->width_ * this->height_;
  this->frame_ = static_cast<uint16_t *>(heap_caps_calloc(pixels, 2, MALLOC_CAP_SPIRAM));
  this->dma_ = static_cast<uint16_t *>(heap_caps_malloc(this->width_ * kDmaRows * 2, MALLOC_CAP_DMA | MALLOC_CAP_INTERNAL));
  this->done_ = xSemaphoreCreateBinary();
  if (this->frame_ == nullptr || this->dma_ == nullptr || this->done_ == nullptr) {
    this->mark_failed(LOG_STR("Out of memory"));
    return;
  }

  spi_bus_config_t bus = {};
  bus.sclk_io_num = this->clk_;
  bus.data0_io_num = this->d_[0];
  bus.data1_io_num = this->d_[1];
  bus.data2_io_num = this->d_[2];
  bus.data3_io_num = this->d_[3];
  bus.data4_io_num = -1;
  bus.data5_io_num = -1;
  bus.data6_io_num = -1;
  bus.data7_io_num = -1;
  bus.max_transfer_sz = this->width_ * kDmaRows * 2;
  esp_err_t err = spi_bus_initialize(SPI2_HOST, &bus, SPI_DMA_CH_AUTO);
  if (err != ESP_OK) {
    ESP_LOGE(TAG, "spi_bus_initialize: %s", esp_err_to_name(err));
    this->mark_failed();
    return;
  }

  esp_lcd_panel_io_spi_config_t io = {};
  io.cs_gpio_num = this->cs_;
  io.dc_gpio_num = -1;
  io.spi_mode = 0;
  io.pclk_hz = this->pclk_;
  io.trans_queue_depth = 10;
  io.on_color_trans_done = &ST77922QSPI::on_trans_done_;
  io.user_ctx = this;
  io.lcd_cmd_bits = 32;
  io.lcd_param_bits = 8;
  io.flags.quad_mode = true;
  err = esp_lcd_new_panel_io_spi((esp_lcd_spi_bus_handle_t) SPI2_HOST, &io, &this->io_);
  if (err != ESP_OK) {
    ESP_LOGE(TAG, "esp_lcd_new_panel_io_spi: %s", esp_err_to_name(err));
    this->mark_failed();
    return;
  }

  st77922_vendor_config_t vendor = {};
  vendor.init_cmds = ES3C35P_INIT;
  vendor.init_cmds_size = sizeof(ES3C35P_INIT) / sizeof(ES3C35P_INIT[0]);
  vendor.flags.use_qspi_interface = 1;
  esp_lcd_panel_dev_config_t dev = {};
  dev.reset_gpio_num = this->reset_;  // ES3C35P: GPIO48 resets the whole chip (else -1: software reset)
  dev.rgb_ele_order = LCD_RGB_ELEMENT_ORDER_RGB;
  dev.bits_per_pixel = 16;
  dev.vendor_config = &vendor;
  err = esp_lcd_new_panel_st77922(this->io_, &dev, &this->panel_);
  if (err == ESP_OK)
    err = esp_lcd_panel_reset(this->panel_);
  if (err == ESP_OK)
    err = esp_lcd_panel_init(this->panel_);
  if (err == ESP_OK && this->invert_)
    err = esp_lcd_panel_invert_color(this->panel_, true);
  if (err == ESP_OK)
    err = esp_lcd_panel_disp_on_off(this->panel_, true);
  if (err != ESP_OK) {
    ESP_LOGE(TAG, "panel init: %s", esp_err_to_name(err));
    this->mark_failed();
    return;
  }
  if (this->te_ >= 0) {
    gpio_reset_pin((gpio_num_t) this->te_);
    gpio_set_direction((gpio_num_t) this->te_, GPIO_MODE_INPUT);
  }
  this->flush_(0, 0, this->width_ - 1, this->height_ - 1);  // clear to black
}

void ST77922QSPI::flush_(int x0, int y0, int x1, int y1) {
  // The ST77922 keeps the frame compressed (its RAM is about half a 320x480 frame), so a write that
  // covers part of a compressed block leaves streaks in its neighbours.
  x0 = 0;
  x1 = this->width_ - 1;
  // Partial row bands still left faint streaks: always send the whole frame (~15 ms at 40 MHz).
  y0 = 0;
  y1 = this->height_ - 1;
  if (x1 < x0 || y1 < y0 || this->panel_ == nullptr)
    return;
  if (this->te_ >= 0) {
    // Wait for TE to go high (blanking) so the write doesn't race the panel's own refresh.
    const uint32_t start = millis();
    while (gpio_get_level((gpio_num_t) this->te_) == 1 && millis() - start < 20) {
    }
    while (gpio_get_level((gpio_num_t) this->te_) == 0 && millis() - start < 40) {
    }
  }
  // One window for the whole frame, then RAMWR (2Ch) for the first band and RAMWRC (3Ch, "memory
  // write continue") for the rest: one continuous stream from the top-left, as this chip needs.
  auto qcmd = [](uint32_t op, uint8_t cmd) { return (int) ((op << 24) | ((uint32_t) cmd << 8)); };
  const uint8_t caset[] = {0, 0, (uint8_t) ((this->width_ - 1) >> 8), (uint8_t) (this->width_ - 1)};
  const uint8_t raset[] = {0, 0, (uint8_t) ((this->height_ - 1) >> 8), (uint8_t) (this->height_ - 1)};
  esp_lcd_panel_io_tx_param(this->io_, qcmd(0x02, 0x2A), caset, 4);
  esp_lcd_panel_io_tx_param(this->io_, qcmd(0x02, 0x2B), raset, 4);
  for (int y = 0; y < this->height_; y += kDmaRows) {
    const int rows = std::min<int>(kDmaRows, this->height_ - y);
    memcpy(this->dma_, this->frame_ + (size_t) y * this->width_, (size_t) rows * this->width_ * 2);
    xSemaphoreTake(this->done_, 0);
    esp_err_t err = esp_lcd_panel_io_tx_color(this->io_, qcmd(0x32, y == 0 ? 0x2C : 0x3C), this->dma_,
                                              (size_t) rows * this->width_ * 2);
    if (err != ESP_OK) {
      ESP_LOGE(TAG, "tx_color: %s", esp_err_to_name(err));
      return;
    }
    xSemaphoreTake(this->done_, pdMS_TO_TICKS(200));  // the buffer is reused next round
  }
}

void ST77922QSPI::draw_pixels_at(int x_start, int y_start, int w, int h, const uint8_t *ptr,
                                 display::ColorOrder order, display::ColorBitness bitness, bool big_endian,
                                 int x_offset, int y_offset, int x_pad) {
  if (w <= 0 || h <= 0 || this->frame_ == nullptr)
    return;
  if (bitness != display::COLOR_BITNESS_565) {
    display::Display::draw_pixels_at(x_start, y_start, w, h, ptr, order, bitness, big_endian, x_offset, y_offset,
                                     x_pad);
    return;
  }
  const int stride = x_offset + w + x_pad;
  for (int y = 0; y != h; y++) {
    const int py = y_start + y;
    if (py < 0 || py >= this->height_)
      continue;
    const uint16_t *src = reinterpret_cast<const uint16_t *>(ptr) + (size_t) (y + y_offset) * stride + x_offset;
    uint16_t *dst = this->frame_ + (size_t) py * this->width_;
    for (int x = 0; x != w; x++) {
      const int px = x_start + x;
      if (px < 0 || px >= this->width_)
        continue;
      uint16_t v = src[x];
      dst[px] = big_endian ? v : (uint16_t) ((v >> 8) | (v << 8));
    }
  }
  this->pending_ = true;  // sent once per redraw, from loop()
}

void ST77922QSPI::draw_pixel_at(int x, int y, Color color) {
  if (this->is_point_clipped(x, y))
    return;
  switch (this->rotation_) {
    case display::DISPLAY_ROTATION_0_DEGREES:
      break;
    case display::DISPLAY_ROTATION_90_DEGREES:
      std::swap(x, y);
      x = this->width_ - x - 1;
      break;
    case display::DISPLAY_ROTATION_180_DEGREES:
      x = this->width_ - x - 1;
      y = this->height_ - y - 1;
      break;
    case display::DISPLAY_ROTATION_270_DEGREES:
      std::swap(x, y);
      y = this->height_ - y - 1;
      break;
  }
  if (x < 0 || y < 0 || x >= this->width_ || y >= this->height_ || this->frame_ == nullptr)
    return;
  const uint16_t v = display::ColorUtil::color_to_565(color);
  this->frame_[(size_t) y * this->width_ + x] = (uint16_t) ((v >> 8) | (v << 8));
  this->dirty_x0_ = std::min(this->dirty_x0_, x);
  this->dirty_y0_ = std::min(this->dirty_y0_, y);
  this->dirty_x1_ = std::max(this->dirty_x1_, x);
  this->dirty_y1_ = std::max(this->dirty_y1_, y);
}

void ST77922QSPI::fill(Color color) {
  if (this->frame_ == nullptr)
    return;
  uint16_t v = display::ColorUtil::color_to_565(color);
  v = (uint16_t) ((v >> 8) | (v << 8));
  std::fill(this->frame_, this->frame_ + (size_t) this->width_ * this->height_, v);
  this->dirty_x0_ = 0;
  this->dirty_y0_ = 0;
  this->dirty_x1_ = this->width_ - 1;
  this->dirty_y1_ = this->height_ - 1;
}

void ST77922QSPI::loop() {
  if (!this->pending_)
    return;
  this->pending_ = false;
  this->flush_(0, 0, this->width_ - 1, this->height_ - 1);
}

void ST77922QSPI::update() {
  this->do_update_();
  if (this->dirty_x1_ >= 0) {
    this->flush_(this->dirty_x0_, this->dirty_y0_, this->dirty_x1_, this->dirty_y1_);
    this->dirty_x0_ = this->dirty_y0_ = INT16_MAX;
    this->dirty_x1_ = this->dirty_y1_ = -1;
  }
}

void ST77922QSPI::dump_config() {
  ESP_LOGCONFIG(TAG,
                "ST77922 QSPI (esp_lcd_st77922):\n"
                "  Size: %u x %u\n"
                "  Reset %d, TE %d, CS %d, CLK %d, D0-D3 %d/%d/%d/%d, %u Hz",
                this->width_, this->height_, this->reset_, this->te_, this->cs_, this->clk_, this->d_[0], this->d_[1], this->d_[2],
                this->d_[3], (unsigned) this->pclk_);
}

}  // namespace esphome::st77922_qspi
#endif

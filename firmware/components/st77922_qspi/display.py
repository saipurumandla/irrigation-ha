import esphome.codegen as cg
from esphome import pins
from esphome.components import display
from esphome.components.esp32 import VARIANT_ESP32S3, add_idf_component, only_on_variant
import esphome.config_validation as cv
from esphome.const import (
    CONF_CS_PIN,
    CONF_CLK_PIN,
    CONF_DATA_PINS,
    CONF_DIMENSIONS,
    CONF_HEIGHT,
    CONF_ID,
    CONF_INVERT_COLORS,
    CONF_LAMBDA,
    CONF_RESET_PIN,
    CONF_WIDTH,
)

DEPENDENCIES = ["esp32", "psram"]

CONF_PCLK_FREQUENCY = "pclk_frequency"
CONF_TE_PIN = "te_pin"

ns = cg.esphome_ns.namespace("st77922_qspi")
ST77922 = ns.class_("ST77922QSPI", display.Display)

CONFIG_SCHEMA = cv.All(
    display.FULL_DISPLAY_SCHEMA.extend(
        {
            cv.GenerateID(): cv.declare_id(ST77922),
            cv.Required(CONF_DIMENSIONS): cv.Schema(
                {cv.Required(CONF_WIDTH): cv.int_, cv.Required(CONF_HEIGHT): cv.int_}
            ),
            # ES3C35P: GPIO48 (TP_RESXP) resets the whole ST77922 (display and touch), not only touch.
            cv.Optional(CONF_RESET_PIN): pins.internal_gpio_output_pin_number,
            cv.Optional(CONF_TE_PIN): pins.internal_gpio_input_pin_number,
            cv.Required(CONF_CS_PIN): pins.internal_gpio_output_pin_number,
            cv.Required(CONF_CLK_PIN): pins.internal_gpio_output_pin_number,
            cv.Required(CONF_DATA_PINS): cv.All(
                [pins.internal_gpio_output_pin_number], cv.Length(min=4, max=4)
            ),
            cv.Optional(CONF_PCLK_FREQUENCY, default="40MHz"): cv.All(
                cv.frequency, cv.Range(min=1e6, max=80e6)
            ),
            # The default init sequence already sends INVON; this flips it again if needed.
            cv.Optional(CONF_INVERT_COLORS, default=False): cv.boolean,
        }
    ).extend(cv.polling_component_schema("never")),
    only_on_variant(supported=[VARIANT_ESP32S3]),
)


async def to_code(config):
    add_idf_component(name="espressif/esp_lcd_st77922", ref="2.1.1")
    var = cg.new_Pvariable(config[CONF_ID])
    await display.register_display(var, config)
    dims = config[CONF_DIMENSIONS]
    cg.add(var.set_dimensions(dims[CONF_WIDTH], dims[CONF_HEIGHT]))
    d = config[CONF_DATA_PINS]
    cg.add(var.set_pins(config[CONF_CS_PIN], config[CONF_CLK_PIN], d[0], d[1], d[2], d[3]))
    if CONF_RESET_PIN in config:
        cg.add(var.set_reset_pin(config[CONF_RESET_PIN]))
    if CONF_TE_PIN in config:
        cg.add(var.set_te_pin(config[CONF_TE_PIN]))
    cg.add(var.set_pclk(int(config[CONF_PCLK_FREQUENCY])))
    cg.add(var.set_invert_colors(config[CONF_INVERT_COLORS]))
    if lamb := config.get(CONF_LAMBDA):
        lambda_ = await cg.process_lambda(lamb, [(display.DisplayRef, "it")], return_type=cg.void)
        cg.add(var.set_writer(lambda_))

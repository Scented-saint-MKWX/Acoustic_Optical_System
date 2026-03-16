/* ==========================================================================
 * SPI Master Firmware Driver
 * Target: Custom RISC-V SoC on Nexys A7-100T
 *
 * The spi_master Verilog peripheral is NOT directly Wishbone-mapped in this
 * SoC; it is instantiated inside laser_vibrometer.v and driven automatically
 * by the hardware acquisition state machine.  This header provides a
 * bit-banged software SPI implementation for use on any spare GPIO pins when
 * a second SPI bus is required (e.g. for external DAC or configuration EEPROM).
 *
 * For the main ADC on Pmod JB, use laser_ctrl.h instead.
 * ========================================================================== */
#ifndef SPI_H
#define SPI_H

#include <stdint.h>
#include "gpio.h"

/* --------------------------------------------------------------------------
 * Bit-banged SPI using GPIO output bits.
 * Assign three GPIO output bits for SCLK, MOSI, CS_N and one input bit for
 * MISO before calling these functions.
 *
 * Example (using LED[13:10] repurposed as SPI — only for testing):
 *   #define BB_SCLK_BIT   10
 *   #define BB_MOSI_BIT   11
 *   #define BB_MISO_BIT   12   // GPIO_DATA_IN bit
 *   #define BB_CS_N_BIT   13
 * -------------------------------------------------------------------------- */

/* Bit-banged SPI configuration (caller defines these macros before including) */
#ifndef BB_SCLK_BIT
# define BB_SCLK_BIT   10
#endif
#ifndef BB_MOSI_BIT
# define BB_MOSI_BIT   11
#endif
#ifndef BB_MISO_BIT
# define BB_MISO_BIT   12
#endif
#ifndef BB_CS_N_BIT
# define BB_CS_N_BIT   13
#endif

/* ---- SPI helper macros ---- */
#define SPI_SCK_LO()   gpio_clear_bits((uint16_t)(1U << BB_SCLK_BIT))
#define SPI_SCK_HI()   gpio_set_bits((uint16_t)(1U << BB_SCLK_BIT))
#define SPI_MOSI_LO()  gpio_clear_bits((uint16_t)(1U << BB_MOSI_BIT))
#define SPI_MOSI_HI()  gpio_set_bits((uint16_t)(1U << BB_MOSI_BIT))
#define SPI_CS_LO()    gpio_clear_bits((uint16_t)(1U << BB_CS_N_BIT))
#define SPI_CS_HI()    gpio_set_bits((uint16_t)(1U << BB_CS_N_BIT))
#define SPI_MISO()     gpio_read_bit(BB_MISO_BIT)

/*
 * spi_init — configure GPIO direction bits for SPI.
 * Call once at startup after gpio_init().
 */
static inline void spi_init(void)
{
    /* SCLK, MOSI, CS_N are outputs; MISO is input (set by GPIO dir mask) */
    GPIO_DIR = GPIO_DIR
             | (uint32_t)(1U << BB_SCLK_BIT)
             | (uint32_t)(1U << BB_MOSI_BIT)
             | (uint32_t)(1U << BB_CS_N_BIT);
    /* CS_N idle high, SCLK idle low (Mode 0) */
    SPI_CS_HI();
    SPI_SCK_LO();
}

/*
 * spi_transfer_byte — transfer 8 bits MSB-first (Mode 0: CPOL=0, CPHA=0).
 * Returns the received byte.
 */
static inline uint8_t spi_transfer_byte(uint8_t tx)
{
    uint8_t rx = 0;
    int i;
    for (i = 7; i >= 0; i--) {
        /* Set MOSI before rising edge */
        if (tx & (uint8_t)(1U << i))
            SPI_MOSI_HI();
        else
            SPI_MOSI_LO();
        SPI_SCK_HI();
        /* Sample MISO on rising edge */
        if (SPI_MISO())
            rx |= (uint8_t)(1U << i);
        SPI_SCK_LO();
    }
    return rx;
}

/*
 * spi_transfer_word — 16-bit MSB-first transfer (Mode 0).
 * Asserts CS_N for the duration.
 */
static inline uint16_t spi_transfer_word(uint16_t tx)
{
    uint16_t rx;
    SPI_CS_LO();
    rx  = (uint16_t)spi_transfer_byte((uint8_t)((tx >> 8) & 0xFF)) << 8;
    rx |= (uint16_t)spi_transfer_byte((uint8_t)(tx & 0xFF));
    SPI_CS_HI();
    return rx;
}

/*
 * spi_read_adc — read a 12-bit sample from an MCP3202-style ADC.
 * Sends the start bit + channel select (ch=0 or 1), returns 12-bit result.
 */
static inline uint16_t spi_read_adc_mcp3202(uint8_t ch)
{
    uint16_t tx = (uint16_t)(0x0600 | ((ch & 1U) << 9)); /* start=1, SGL=1, ch */
    uint16_t rx = spi_transfer_word(tx);
    return (uint16_t)(rx & 0x0FFFU);
}

#endif /* SPI_H */

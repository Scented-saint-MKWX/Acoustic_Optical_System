/* ==========================================================================
 * Acoustic-Optical SoC — Main Firmware
 *
 * This firmware runs on the custom RISC-V core and orchestrates:
 *   1. PDM microphone beamforming (steering angle from switches)
 *   2. FFT spectral analysis of the beamformed signal
 *   3. Laser vibrometry readout
 *   4. UART telemetry output to host PC
 * ========================================================================== */

#include "include/soc_regs.h"
#include "include/uart.h"
#include "include/beamform.h"
#include "include/fft_ctrl.h"
#include "include/laser_ctrl.h"

/* ---- Simple delay (busy-wait) ---- */
static void delay(volatile uint32_t count)
{
    while (count--)
        ;
}

/* ---- Print a signed 16-bit integer as decimal over UART ---- */
static void uart_put_int16(int16_t val)
{
    char buf[7];
    int idx = 0;
    uint16_t uval;

    if (val < 0) {
        uart_putc('-');
        uval = (uint16_t)(-val);
    } else {
        uval = (uint16_t)val;
    }

    /* Convert digits (reverse order) */
    if (uval == 0) {
        uart_putc('0');
        return;
    }
    while (uval > 0) {
        buf[idx++] = '0' + (uval % 10);
        uval /= 10;
    }
    /* Print in correct order */
    while (idx > 0)
        uart_putc(buf[--idx]);
}

/* ---- Print unsigned 32-bit as decimal ---- */
static void uart_put_u32(uint32_t val)
{
    char buf[11];
    int idx = 0;

    if (val == 0) {
        uart_putc('0');
        return;
    }
    while (val > 0) {
        buf[idx++] = '0' + (val % 10);
        val /= 10;
    }
    while (idx > 0)
        uart_putc(buf[--idx]);
}

/* ==========================================================================
 * Main Entry Point
 * ========================================================================== */
void main(void)
{
    /* ---- Initialize ---- */
    GPIO_DIR = 0xFFFF;        /* All LEDs as outputs */
    GPIO_DATA_OUT = 0x0001;   /* LED[0] = power indicator */

    uart_puts("\r\n=== Acoustic-Optical SoC v1.0 ===\r\n");
    uart_puts("Platform: Nexys A7-100T (Artix-7)\r\n");
    uart_puts("Core:     RISC-V RV32I\r\n\r\n");

    /* ---- Enable laser vibrometer ---- */
    laser_enable();
    uart_puts("[LASER] Vibrometer enabled.\r\n");

    /* ---- Main processing loop ---- */
    uint32_t frame = 0;

    while (1) {
        frame++;
        GPIO_DATA_OUT = (frame & 0xFF);  /* Heartbeat on LEDs */

        /* ---- 1. Read steering angle from switches ---- */
        uint32_t sw = GPIO_DATA_IN;
        /* SW[7:0]: angle in degrees × 10  (0–900 = 0°–90°) */
        /* SW[8]:   sign (1 = negative angle) */
        int angle = (int)(sw & 0xFF) * 10;
        if (sw & 0x100) angle = -angle;

        beamform_steer(angle);

        /* ---- 2. Start FFT on beamformed audio ---- */
        fft_start();

        /* Wait for FFT to complete */
        while (!fft_is_done())
            ;

        /* Find dominant frequency */
        int peak_bin = fft_peak_bin();
        /* Frequency = bin * sample_rate / FFT_N */
        uint32_t peak_freq_hz = (uint32_t)peak_bin * 48828 / FFT_N;
        uint32_t peak_mag = fft_magnitude_sq(peak_bin);

        /* ---- 3. Read laser vibrometry ---- */
        int16_t velocity = laser_read_velocity();
        int16_t laser_i, laser_q;
        laser_read_iq(&laser_i, &laser_q);

        /* ---- 4. UART telemetry ---- */
        uart_puts("F:");
        uart_put_u32(frame);
        uart_puts(" ANG:");
        uart_put_int16((int16_t)(angle / 10));
        uart_puts("deg PEAK:");
        uart_put_u32(peak_freq_hz);
        uart_puts("Hz MAG:");
        uart_put_u32(peak_mag);
        uart_puts(" VEL:");
        uart_put_int16(velocity);
        uart_puts(" I:");
        uart_put_int16(laser_i);
        uart_puts(" Q:");
        uart_put_int16(laser_q);
        uart_puts("\r\n");

        /* Re-arm FFT for next frame */
        fft_rearm();

        /* Frame rate limiter */
        delay(100000);
    }
}

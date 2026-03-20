/* ==========================================================================
 * Acoustic-Optical SoC — Main Firmware
 *
 * This firmware runs on the custom RISC-V core and orchestrates:
 *   1. I2S microphone beamforming (steering angle from switches)
 *   2. FFT spectral analysis of the beamformed signal
 *   3. Laser vibrometer simulator readout
 *   4. AXI register polling: hardware AoA angle + simulated frequency
 *   5. UART telemetry output to host PC
 *      — When the simulated frequency matches TARGET_FREQ_HZ the estimated
 *        AoA angle is emitted as an alert line.
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
    uart_puts("Core:     RISC-V RV32I\r\n");
    uart_puts("Audio:    4x INMP441 I2S microphones\r\n");
    uart_puts("Optical:  Laser vibrometer simulator (NCO/DDS)\r\n\r\n");

    /* ---- Enable laser simulator ---- */
    laser_enable();
    uart_puts("[LASER] Simulator enabled (440 Hz NCO/DDS).\r\n");

    /* ---- Main processing loop ---- */
    uint32_t frame = 0;

    /* Target frequency for the AoA alert (Hz) */
#define TARGET_FREQ_HZ  440u

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

        /* ---- 3. Read laser simulator outputs ---- */
        int16_t velocity = laser_read_velocity();    /* Current sine-wave sample */
        int16_t laser_i, laser_q;
        laser_read_iq(&laser_i, &laser_q);           /* I = sim_freq_hz, Q = wave */

        /* ---- 4. Poll AXI DSP output registers ---- */
        /* AXI_AOA_ANGLE: hardware-computed AoA from cross-correlation TDOA  */
        /* AXI_SIM_FREQ:  frequency register from laser simulator (440 Hz)   */
        int32_t  hw_angle  = (int32_t)AXI_AOA_ANGLE;   /* Signed, degrees × 10 */
        uint32_t sim_freq  = AXI_SIM_FREQ;              /* Hz                   */

        /* ---- 5. UART telemetry ---- */
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
        uart_puts(" HW_AOA:");
        /* Integer division of a negative value truncates toward zero in C, so
         * we replicate that behaviour explicitly to avoid confusion: display
         * the magnitude divided then re-apply the sign.                      */
        if (hw_angle < 0) {
            uart_putc('-');
            uart_put_u32((uint32_t)((-hw_angle) / 10));
        } else {
            uart_put_u32((uint32_t)(hw_angle / 10));
        }
        uart_puts("deg SIM_FREQ:");
        uart_put_u32(sim_freq);
        uart_puts("Hz\r\n");

        /* ---- 6. Frequency-triggered AoA alert ---- */
        /* When the simulated laser frequency matches the target, emit an    */
        /* alert line containing the hardware-estimated angle of arrival.    */
        if (sim_freq == TARGET_FREQ_HZ) {
            uart_puts("!MATCH freq=");
            uart_put_u32(sim_freq);
            uart_puts("Hz HW_AoA=");
            if (hw_angle < 0) {
                uart_putc('-');
                uart_put_u32((uint32_t)((-hw_angle) / 10));
            } else {
                uart_put_u32((uint32_t)(hw_angle / 10));
            }
            uart_puts("deg\r\n");
        }

        /* Re-arm FFT for next frame */
        fft_rearm();

        /* Frame rate limiter */
        delay(100000);
    }
}

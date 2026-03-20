/* ==========================================================================
 * Acoustic-Optical SoC — Memory-Mapped Register Definitions
 * Target: Custom RISC-V SoC on Nexys A7-100T
 * ========================================================================== */
#ifndef SOC_REGS_H
#define SOC_REGS_H

#include <stdint.h>

/* Helper macros for MMIO access */
#define REG32(addr)  (*(volatile uint32_t *)(addr))

/* ---- Memory Map ---- */
#define RAM_BASE         0x00000000
#define RAM_SIZE         0x00002000   /* 8 KB */

#define GPIO_BASE        0x80000000
#define UART_TX_BASE     0x80001000
#define UART_RX_BASE     0x80002000
#define BEAMFORMER_BASE  0x80003000
#define FFT_BASE         0x80004000
#define LASER_BASE       0x80005000
#define AXI_MAP_BASE     0x80006000

/* ---- GPIO Registers ---- */
#define GPIO_DATA_OUT    REG32(GPIO_BASE + 0x00)
#define GPIO_DIR         REG32(GPIO_BASE + 0x04)
#define GPIO_DATA_IN     REG32(GPIO_BASE + 0x08)

/* ---- UART TX Registers ---- */
#define UART_TX_DATA     REG32(UART_TX_BASE + 0x00)
#define UART_TX_STATUS   REG32(UART_TX_BASE + 0x04)
#define UART_TX_BUSY     (UART_TX_STATUS & 0x01)

/* ---- UART RX Registers ---- */
#define UART_RX_DATA     REG32(UART_RX_BASE + 0x00)
#define UART_RX_STATUS   REG32(UART_RX_BASE + 0x04)
#define UART_RX_AVAIL    (UART_RX_STATUS & 0x01)

/* ---- Beamformer Registers ---- */
#define BEAM_DELAY(ch)   REG32(BEAMFORMER_BASE + ((ch) << 2))

/* ---- FFT Registers ---- */
#define FFT_CTRL         REG32(FFT_BASE + 0x000)
#define FFT_STATUS       REG32(FFT_BASE + 0x004)
#define FFT_BUSY         (FFT_STATUS & 0x01)
#define FFT_DONE         (FFT_STATUS & 0x02)
#define FFT_REAL(k)      REG32(FFT_BASE + 0x100 + ((k) << 2))
#define FFT_IMAG(k)      REG32(FFT_BASE + 0x300 + ((k) << 2))

/* ---- Laser Simulator Registers (replaces physical laser vibrometer) ---- */
#define LASER_CTRL       REG32(LASER_BASE + 0x00)   /* bit0 = enable         */
#define LASER_STATUS     REG32(LASER_BASE + 0x04)   /* bit0 = running        */
#define LASER_SIM_FREQ   REG32(LASER_BASE + 0x08)   /* R/W: frequency in Hz  */
#define LASER_WAVE_OUT   REG32(LASER_BASE + 0x0C)   /* RO:  current sine sample */
/* Alias kept for firmware backward compatibility */
#define LASER_I_SAMPLE   LASER_SIM_FREQ
#define LASER_Q_SAMPLE   LASER_WAVE_OUT
#define LASER_VELOCITY   LASER_WAVE_OUT

/* ---- AXI DSP Output Registers (0x8000_6000) ---- */
/* These registers are written by hardware (AoA estimator and laser simulator) */
/* and are read-only from the RISC-V perspective.                               */
#define AXI_BASE         0x80006000
#define AXI_AOA_ANGLE    REG32(AXI_BASE + 0x00)   /* Signed: degrees × 10  */
#define AXI_SIM_FREQ     REG32(AXI_BASE + 0x04)   /* Unsigned: Hz          */
#define AXI_DSP_STATUS   REG32(AXI_BASE + 0x08)   /* bit0=angle_valid, bit1=freq_valid */

#endif /* SOC_REGS_H */

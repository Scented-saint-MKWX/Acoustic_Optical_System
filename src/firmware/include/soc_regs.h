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

/* ---- Laser Vibrometer Registers ---- */
#define LASER_CTRL       REG32(LASER_BASE + 0x00)
#define LASER_STATUS     REG32(LASER_BASE + 0x04)
#define LASER_I_SAMPLE   REG32(LASER_BASE + 0x08)
#define LASER_Q_SAMPLE   REG32(LASER_BASE + 0x0C)
#define LASER_VELOCITY   REG32(LASER_BASE + 0x10)

#endif /* SOC_REGS_H */

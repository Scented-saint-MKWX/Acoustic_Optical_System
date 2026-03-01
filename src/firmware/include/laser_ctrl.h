/* ==========================================================================
 * Laser Vibrometer Control
 * ========================================================================== */
#ifndef LASER_CTRL_H
#define LASER_CTRL_H

#include "soc_regs.h"

/* Enable the laser vibrometer ADC acquisition */
static inline void laser_enable(void)
{
    LASER_CTRL = 0x01;
}

/* Disable the laser vibrometer */
static inline void laser_disable(void)
{
    LASER_CTRL = 0x00;
}

/* Read the last velocity sample (signed 16-bit) */
static inline int16_t laser_read_velocity(void)
{
    return (int16_t)(LASER_VELOCITY & 0xFFFF);
}

/* Read raw I/Q samples */
static inline void laser_read_iq(int16_t *i_out, int16_t *q_out)
{
    *i_out = (int16_t)(LASER_I_SAMPLE & 0xFFFF);
    *q_out = (int16_t)(LASER_Q_SAMPLE & 0xFFFF);
}

#endif /* LASER_CTRL_H */

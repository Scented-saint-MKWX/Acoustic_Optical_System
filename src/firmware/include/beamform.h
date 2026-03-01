/* ==========================================================================
 * Beamforming Control
 * ========================================================================== */
#ifndef BEAMFORM_H
#define BEAMFORM_H

#include "soc_regs.h"

#define NUM_MICS        4
#define SPEED_OF_SOUND  343     /* m/s at 20°C */
#define MIC_SPACING_UM  10000   /* 10 mm mic spacing in micrometers */
#define SAMPLE_RATE_HZ  48828   /* PDM_CLK/64 ≈ 3.125MHz/64 */

/*
 * Set beamformer delays for a given steering angle (degrees).
 * Uses delay-and-sum: Δn = d * sin(θ) / c * fs
 *
 * angle_deg: steering angle in degrees × 10  (e.g., 300 = 30.0°)
 */
static inline void beamform_steer(int angle_deg_x10)
{
    /* sin() approximation for small angles using Taylor:
     * sin(x) ≈ x - x³/6, where x in radians
     * For simplicity we use a lookup or linear approx.
     * angle_rad ≈ angle_deg_x10 * PI / 1800
     */
    /* Fixed-point: scale by 1000 */
    int sin_val;
    int angle = angle_deg_x10;

    /* Simple linear approximation for ±90° */
    /* sin(θ) ≈ θ * 17 / 1000 for θ in tenths-of-degrees */
    if (angle > 900) angle = 900;
    if (angle < -900) angle = -900;
    sin_val = angle * 17 / 1000;  /* Q0.3 approximately */

    for (int ch = 0; ch < NUM_MICS; ch++) {
        /* Delay in samples: d_n = n * d * sin(θ) * fs / c */
        int delay = ch * MIC_SPACING_UM * sin_val * SAMPLE_RATE_HZ
                    / (SPEED_OF_SOUND * 1000000);
        if (delay < 0) delay = -delay;
        if (delay > 31) delay = 31;
        BEAM_DELAY(ch) = (uint32_t)delay;
    }
}

#endif /* BEAMFORM_H */

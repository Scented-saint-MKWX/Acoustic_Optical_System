/* ==========================================================================
 * FFT Control
 * ========================================================================== */
#ifndef FFT_CTRL_H
#define FFT_CTRL_H

#include "soc_regs.h"

#define FFT_N  256

/* Start FFT acquisition (loads samples then computes) */
static inline void fft_start(void)
{
    FFT_CTRL = 0x01;  /* Start loading samples */
}

/* Re-arm the FFT engine for a new acquisition */
static inline void fft_rearm(void)
{
    FFT_CTRL = 0x02;  /* Reset to idle */
}

/* Check if FFT computation is complete */
static inline int fft_is_done(void)
{
    return (FFT_STATUS & 0x02) ? 1 : 0;
}

/* Read magnitude² of bin k (avoids sqrt): |X[k]|² = Re² + Im² */
static inline uint32_t fft_magnitude_sq(int k)
{
    int32_t re = (int32_t)FFT_REAL(k);
    int32_t im = (int32_t)FFT_IMAG(k);
    return (uint32_t)(re * re + im * im);
}

/* Find the dominant frequency bin (simple peak detector) */
static inline int fft_peak_bin(void)
{
    uint32_t max_mag = 0;
    int peak = 0;

    /* Only search positive frequencies (bins 1..N/2-1) */
    for (int k = 1; k < FFT_N / 2; k++) {
        uint32_t mag = fft_magnitude_sq(k);
        if (mag > max_mag) {
            max_mag = mag;
            peak = k;
        }
    }
    return peak;
}

#endif /* FFT_CTRL_H */

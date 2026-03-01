# Mathematical Models

## 1. PDM-to-PCM: CIC Decimation Filter

A CIC (Cascaded Integrator-Comb) filter of order $N$ with decimation ratio $R$ has the transfer function:

$$
H(z) = \left( \frac{1 - z^{-R}}{1 - z^{-1}} \right)^N
$$

### Parameters Used

| Parameter       | Value | Description                          |
|----------------|-------|--------------------------------------|
| $N$ (order)    | 4     | Number of cascaded stages            |
| $R$ (decimation) | 64  | PDM rate / PCM rate                  |
| Input rate     | 3.125 MHz | PDM clock frequency              |
| Output rate    | 48.828 kHz | PCM sample rate                 |

### CIC Gain

The DC gain of the CIC filter is:

$$
G = R^N = 64^4 = 16{,}777{,}216
$$

The output bit-growth is $N \cdot \log_2(R) = 4 \times 6 = 24$ bits. With a 1-bit input, the full-precision output is 25 bits, truncated to 16 bits for the downstream pipeline.

---

## 2. Delay-and-Sum Beamforming

For a uniform linear array (ULA) of $M$ microphones with inter-element spacing $d$, steered to angle $\theta$:

$$
y[n] = \sum_{m=0}^{M-1} x_m[n - \Delta_m]
$$

where the delay for channel $m$ is:

$$
\Delta_m = \frac{m \cdot d \cdot \sin(\theta)}{c} \cdot f_s
$$

### Parameters

| Symbol | Value | Description |
|--------|-------|-------------|
| $M$    | 4     | Number of microphones |
| $d$    | 10 mm | Element spacing |
| $c$    | 343 m/s | Speed of sound at 20°C |
| $f_s$  | 48,828 Hz | Sample rate |

### Maximum Delay

For end-fire steering ($\theta = 90°$):

$$
\Delta_{max} = \frac{(M-1) \cdot d}{c} \cdot f_s = \frac{3 \times 0.01}{343} \times 48828 \approx 4.27 \text{ samples}
$$

The design supports up to 31 sample delays per channel for flexibility with different array geometries.

### Array Response (Beam Pattern)

The far-field beam pattern is:

$$
B(\phi) = \frac{1}{M} \left| \sum_{m=0}^{M-1} e^{j 2\pi m d (sin\phi - sin\theta) / \lambda} \right|
$$

Half-power beamwidth (HPBW) for a 4-element ULA at 1 kHz ($\lambda = 0.343$ m):

$$
\text{HPBW} \approx \frac{0.886 \lambda}{M d} \approx \frac{0.886 \times 0.343}{4 \times 0.01} \approx 7.6°
$$

---

## 3. FFT Spectral Analysis

The 256-point DIT (Decimation-In-Time) Radix-2 FFT computes:

$$
X[k] = \sum_{n=0}^{N-1} x[n] \cdot W_N^{nk}, \quad W_N = e^{-j2\pi/N}
$$

### Butterfly Operation

Each butterfly computes:

$$
\begin{aligned}
X_{\text{top}} &= A + W_N^k \cdot B \\
X_{\text{bot}} &= A - W_N^k \cdot B
\end{aligned}
$$

### Frequency Resolution

$$
\Delta f = \frac{f_s}{N} = \frac{48828}{256} \approx 190.7 \text{ Hz}
$$

Maximum detectable frequency (Nyquist): $f_s / 2 \approx 24.4$ kHz.

### Fixed-Point Twiddle Factors

Twiddle factors are stored in Q1.15 format:
$$
W_r[k] = \text{round}\left(\cos\left(\frac{-2\pi k}{N}\right) \times 32767\right)
$$
$$
W_i[k] = \text{round}\left(\sin\left(\frac{-2\pi k}{N}\right) \times 32767\right)
$$

---

## 4. Laser Vibrometry — Quadrature Demodulation

The laser vibrometer produces I/Q signals proportional to the optical phase:

$$
I(t) = A \cos(\phi(t)), \quad Q(t) = A \sin(\phi(t))
$$

The instantaneous phase change (proportional to surface velocity) is extracted via the cross-product differentiation:

$$
\Delta\phi[n] \approx I[n-1] \cdot Q[n] - Q[n-1] \cdot I[n]
$$

This avoids an explicit $\arctan$ and division. The surface velocity is:

$$
v(t) = \frac{\lambda_{\text{laser}}}{4\pi} \cdot \frac{d\phi}{dt}
$$

For a typical helium-neon laser ($\lambda = 632.8$ nm), the velocity sensitivity is approximately:

$$
\frac{\lambda}{4\pi} \approx 50.3 \text{ nm/rad}
$$

# System Architecture

## Block Diagram

```
 ┌─────────────────────────────────────────────────────────────────┐
 │                     NEXYS A7-100T FPGA                         │
 │                                                                 │
 │  ┌──────────┐    ┌────────────────────────────────────────┐    │
 │  │ RISC-V   │    │        Wishbone Interconnect           │    │
 │  │ RV32I    │◄──►│  (1 Master, 7 Slaves)                  │    │
 │  │ Core     │    └──┬──────┬──────┬──────┬──────┬─────┬───┘    │
 │  └──────────┘       │      │      │      │      │     │        │
 │       │  ▲          │      │      │      │      │     │        │
 │       ▼  │          ▼      ▼      ▼      ▼      ▼     ▼        │
 │  ┌──────────┐  ┌──────┐┌─────┐┌─────┐┌─────┐┌─────┐┌──────┐  │
 │  │ Block    │  │ GPIO ││UART ││UART ││Beam-││ FFT ││Laser │  │
 │  │ RAM      │  │      ││ TX  ││ RX  ││forme││Engin││Vibro-│  │
 │  │ 8KB      │  │16-bit││     ││     ││r    ││e    ││meter │  │
 │  │ (I+D)    │  │      ││     ││     ││     ││256pt││      │  │
 │  └──────────┘  └──┬───┘└──┬──┘└──┬──┘└──┬──┘└──┬──┘└──┬───┘  │
 │                    │       │      │      │      │      │       │
 └────────────────────┼───────┼──────┼──────┼──────┼──────┼───────┘
                      │       │      │      │             │
                      ▼       ▼      ▼      ▼             ▼
                 ┌────────┐┌─────┐┌─────┐  ┌───────────┐┌──────────┐
                 │ LEDs   ││USB  ││USB  │  │ PDM Mic   ││ ADC      │
                 │Switches││UART ││UART │  │ Array     ││ (SPI)    │
                 └────────┘│(TX) ││(RX) │  │ (4-ch)    │└──────────┘
                           └─────┘└─────┘  └───────────┘     │
                                                │             ▼
                                           ┌─────────┐  ┌──────────┐
                                           │ CIC     │  │ Laser    │
                                           │ Filters │  │ Head     │
                                           │ (x4)    │  │ (ext.)   │
                                           └─────────┘  └──────────┘
```

## Memory Map

| Address Range              | Peripheral         | Description                     |
|---------------------------|--------------------|---------------------------------|
| `0x0000_0000 – 0x0000_1FFF` | Block RAM          | 8 KB instruction + data memory  |
| `0x8000_0000 – 0x8000_000F` | GPIO               | LEDs (out), switches (in)       |
| `0x8000_1000 – 0x8000_1007` | UART TX            | Transmit data + status          |
| `0x8000_2000 – 0x8000_2007` | UART RX            | Receive data + status           |
| `0x8000_3000 – 0x8000_300F` | Beamformer         | Delay tap config (4 channels)   |
| `0x8000_4000 – 0x8000_4FFF` | FFT Engine         | Control, status, result readout |
| `0x8000_5000 – 0x8000_5014` | Laser Vibrometer   | Control, I/Q + velocity readout |

## Signal Processing Pipeline

```
PDM Mics ──► PDM Interface ──► CIC Filter (×4) ──► Beamformer ──► FFT Engine
   (1-bit       (3.125 MHz        (48.8 kHz          (delay &      (256-pt
    @3.1MHz)     sampling)          16-bit PCM)        sum)          spectral)
                                                                       │
                                                                       ▼
                                                                  RISC-V Core
                                                                  (analysis +
                                                                   telemetry)
                                                                       ▲
                                                                       │
Laser Head ──► ADC (SPI) ──► Quadrature Demod ──► Velocity ───────────┘
  (optical)     (16-bit       (phase diff)         (fixed-pt)
```

## Data Flow Summary

1. **Acoustic path**: 4 PDM MEMS microphones → CIC decimation (64:1) → PCM 16-bit @ ~48.8 kHz → delay-and-sum beamformer (CPU-steered) → 256-pt FFT → spectrum available on Wishbone bus.

2. **Optical path**: Laser vibrometer sensor → SPI ADC reads I/Q quadrature → digital phase differentiation → instantaneous velocity → available on Wishbone bus.

3. **Control**: RISC-V RV32I core reads switch positions for beam steering angle, triggers FFT, reads spectral peaks, reads laser velocity, and outputs combined telemetry over 115200-baud UART to a host PC for logging/display.

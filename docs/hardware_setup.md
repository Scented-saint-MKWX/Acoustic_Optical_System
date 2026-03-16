# Hardware Setup Guide

## Required Hardware

### 1. FPGA Development Board
- **Digilent Nexys A7-100T** (or Nexys A7-50T with reduced features)
  - Xilinx Artix-7 XC7A100T-1CSG324C
  - 100 MHz on-board oscillator
  - USB-UART bridge (Silicon Labs CP2102)
  - 16 LEDs, 16 slide switches, 5 push buttons
  - 4× Pmod connectors (12-pin each)
  - USB-JTAG for programming


### 2. PDM Microphone Array (Pmod JA)
Connect 4 MEMS PDM microphones to **Pmod Header JA**:

| Component | Recommended Part | Qty | Notes |
|-----------|-----------------|-----|-------|
| PDM Mic   | Knowles SPH0645LM4H | 4 | I²S/PDM output, SNR 65 dB |
| *Alternative* | Digilent Pmod MIC3 | 2 | Each has 1 MEMS mic + ADC |
| Breakout board | Custom PCB or breadboard | 1 | Mount mics in linear array |

**Wiring (Pmod JA):**
```
JA Pin 1 (C17) → PDM_CLK     (output to all mics, directly)
JA Pin 2 (D18) → PDM_DATA[0] (Mic 0 data)
JA Pin 3 (E18) → PDM_DATA[1] (Mic 1 data)
JA Pin 4 (G17) → PDM_DATA[2] (Mic 2 data)
JA Pin 7 (D17) → PDM_DATA[3] (Mic 3 data)
JA Pin 5 (GND) → Ground
JA Pin 6 (VCC) → 3.3V supply
```

**Physical Array Layout:**
- Mount microphones in a **linear array** with **10 mm spacing**
- Align on a rigid substrate (PCB or aluminum bar)
- Keep array perpendicular to the target direction

### 3. Laser Vibrometer + ADC (Pmod JB)
Connect an external ADC reading the laser vibrometer's analog I/Q outputs:

| Component | Recommended Part | Qty | Notes |
|-----------|-----------------|-----|-------|
| ADC       | Analog Devices AD7606 (8-ch, 16-bit, SPI) | 1 | Bipolar input ±5V/±10V |
| *Alternative* | Digilent Pmod AD1 (AD7476A, 12-bit) | 1 | Simpler, single-ended |
| Laser vibrometer head | Polytec OFV-505 or equivalent | 1 | Analog velocity/displacement output |
| *Budget alternative* | DIY laser interferometer | 1 | HeNe laser + beam splitter + photodiode |

**Wiring (Pmod JB):**
```
JB Pin 1 (D14) → ADC_CS_N   (chip select, active low)
JB Pin 2 (F16) → ADC_MOSI   (data to ADC)
JB Pin 3 (G16) → ADC_MISO   (data from ADC)
JB Pin 4 (H14) → ADC_SCLK   (SPI clock)
JB Pin 5 (GND) → Ground
JB Pin 6 (VCC) → 3.3V
```

### 4. Host PC Connection
- **USB Micro-B cable** for FPGA programming (JTAG) and UART communication
- **Terminal software**: PuTTY, Tera Term, or `screen` — 115200 baud, 8N1
- **Vivado ML Edition** (free for Artix-7): for synthesis, implementation, and programming

### 5. Power
- The Nexys A7 is powered via USB (5V, ~500 mA typical)
- External sensors (laser, ADC) may need separate power supplies — check datasheets

---

## Assembly Instructions

### Step 1: Prepare the Microphone Array
1. Solder 4× SPH0645LM4H mics onto a breakout PCB
2. Wire all `CLK` pins together (from JA Pin 1)
3. Wire each `DATA` pin to separate JA data pins
4. Connect `VDD` to 3.3V and `GND` to ground
5. Add 100 nF decoupling capacitors near each mic

### Step 2: Prepare the ADC + Laser Interface
1. Mount AD7606 on an evaluation board or Pmod breakout
2. Connect ADC Channel 0 → Laser I output (via voltage divider if needed)
3. Connect ADC Channel 1 → Laser Q output
4. Wire SPI signals to Pmod JB as shown above

### Step 3: Connect to FPGA
1. Plug microphone array into **Pmod JA** (top row)
2. Plug ADC module into **Pmod JB** (top row)
3. Connect USB cable to Nexys A7 for programming + UART

### Step 4: Build and Program
```bash
# 1. Build firmware
cd src/firmware
make clean && make all

# 2. Build FPGA bitstream (requires Vivado in PATH)
cd ../..
vivado -mode batch -source scripts/build_vivado.tcl

# 3. Program FPGA
vivado -mode batch -source scripts/program_fpga.tcl
```

### Step 5: Verify Operation
1. Open a serial terminal at **115200 baud**
2. Press CPU_RESETN button on the board
3. You should see the boot banner:
   ```
   === Acoustic-Optical SoC v1.0 ===
   Platform: Nexys A7-100T (Artix-7)
   Core:     RISC-V RV32I
   ```
4. Telemetry frames (angle, frequency, velocity) stream continuously
5. Use slide switches SW[7:0] to adjust steering angle (0–90°)
6. Use SW[8] to toggle negative angles

---

## Bill of Materials Summary

| # | Item | Est. Cost |
|---|------|-----------|
| 1 | Digilent Nexys A7-100T | $263 (academic) |
| 2 | Knowles SPH0645LM4H × 4 | $4 × 4 = $16 |
| 3 | Custom mic array PCB | ~$10 (JLCPCB) |
| 4 | Analog Devices AD7606-BSTZ eval board | ~$50 |
| 5 | Laser vibrometer / interferometer | $200–$5000+ |
| 6 | USB Micro-B cable | $5 |
| 7 | Jumper wires, connectors | $10 |
|   | **Total (budget, no laser)** | **~$350** |
|   | **Total (with entry-level laser)** | **~$600** |

---

## India-Specific Hardware Guide

> **Target:** minimum-cost, easily sourced build using components available on
> Indian online marketplaces (Robu.in, Mouser India, Amazon.in, Rajasthan
> Electronics, Stack Electronics Mumbai, LCSC India-warehouse).

### PDM Microphone Array — India Options

The **INMP441** is the most widely available MEMS microphone in India and is
almost identical in use to the SPH0645. It outputs I²S/PDM and operates at
3.3 V.

| Component | Where to Buy | Approx. Cost (INR) |
|-----------|-------------|-------------------|
| INMP441 MEMS mic module (breakout) | Robu.in, Amazon.in | ₹80–₹120 each |
| INMP441 bare IC | Mouser India (min order 5) | ₹60 each |
| MSM261S4030H0 PDM mic (SOP-8 breakout) | Robu.in | ₹90 each |
| Generic 3.3 V MEMS PDM breakout board | Amazon.in | ₹100–₹150 each |

**Wiring INMP441 to Pmod JA:**
```
INMP441 pin  →  Pmod JA pin
L/R          →  GND (selects left/rising-edge channel)
SCK          →  JA Pin 1 (PDM_CLK)
WS           →  GND (PDM mode: tie low)
SD           →  JA Pin 2/3/4/7 (one per microphone)
VDD          →  JA Pin 6 (3.3 V)
GND          →  JA Pin 5 (GND)
```
Buy 4 × INMP441 breakout boards and mount them on a ruler or PCB strip with
**10 mm centre-to-centre spacing**.

---

### ADC for Laser Vibrometer — India Options

A **12-bit SPI ADC** is sufficient to demonstrate the principle.  MCP3202 is
widely available and costs < ₹100.

| Component | Where to Buy | Approx. Cost (INR) |
|-----------|-------------|-------------------|
| MCP3202 (12-bit, 2-ch, SPI) | Rajasthan Electronics, Amazon.in | ₹60–₹90 |
| MCP3204 (12-bit, 4-ch, SPI) | Robu.in | ₹120 |
| ADS1115 (16-bit, I²C) — bit-bang SPI via GPIO | Amazon.in | ₹120–₹180 |
| Digilent Pmod AD1 (AD7476A, 12-bit, SPI) | Element14 India | ₹800 |

**Wiring MCP3202 to Pmod JB:**
```
MCP3202 pin  →  Pmod JB pin
CS  (pin 1)  →  JB Pin 1 (ADC_CS_N)
DIN (pin 5)  →  JB Pin 2 (ADC_MOSI)
DOUT(pin 6)  →  JB Pin 3 (ADC_MISO)
CLK (pin 7)  →  JB Pin 4 (ADC_SCLK)
VDD (pin 8)  →  3.3 V (also serves as VREF)
VSS (pin 4)  →  GND
CH0 (pin 2)  →  Laser I output signal
CH1 (pin 3)  →  Laser Q output signal
```
The MCP3202 input range is 0 – VREF (0–3.3 V single-ended).  Do NOT
connect signals above 3.3 V directly to MCP3202 inputs.

---

### Budget Laser / Vibration Source — India Options

A professional laser vibrometer (Polytec OFV-505) is not available in India at
reasonable cost. Use one of these alternatives:

#### Option A — 650 nm Red Laser Pointer Module (simplest)
```
Component         : 5 mW 650 nm red laser diode module
Where to buy      : Amazon.in, Robu.in
Cost              : ₹50–₹150
```
This generates a spot on the vibrating surface. Mount a photodiode to detect
the scattered light intensity — intensity varies with vibration.

**Limitation:** This is a simple intensity-modulation sensor, NOT a true
quadrature interferometer.  The I/Q demodulation hardware is still exercised,
but velocity sensitivity is lower.

#### Option B — Laser + Beam Splitter Interferometer (recommended)
```
Component             Where to buy             Cost (INR)
─────────────────────────────────────────────────────────
5 mW 650 nm laser     Amazon.in / Robu.in      ₹150
Beam splitter cube    OptoSigma / Holmarc       ₹800–₹2000
Reference mirror      Surplus optics online     ₹200–₹500
BPW34 photodiode      Mouser India              ₹40 each (× 2)
LM358 op-amp (TIA)    Rajasthan Electronics     ₹10
```

Build a Michelson interferometer on a breadboard.  The two photodiodes detect
interference fringes in phase quadrature (use a λ/4 wave plate or 90° beam
splitter to generate I and Q).

**Full build cost: ~₹3500–₹5000 (academic lab quality)**

#### Option C — Piezo Speaker as Vibrating Target (lowest cost)
```
Component             Where to buy        Cost (INR)
────────────────────────────────────────────────────
Piezo buzzer (as speaker) Amazon.in        ₹20
Function generator (phone app "PhyPhox")  Free
Tape the laser spot to the piezo membrane
```
Drive the piezo with a 100–1000 Hz signal and observe the vibration-modulated
photodiode output on an oscilloscope.

---

### Minimal Component List for First Bring-Up (India)

The following is the absolute minimum to compile, synthesise and run the
Acoustic-Optical SoC on a Nexys A7 without a real laser:

| # | Item | Source | Cost (INR) |
|---|------|--------|-----------|
| 1 | Nexys A7-100T | Mouser India / Element14 India | ₹22 000–₹25 000 |
| 2 | INMP441 mic breakout × 4 | Robu.in / Amazon.in | ₹400 |
| 3 | MCP3202 ADC DIP-8 × 1 | Rajasthan Electronics | ₹80 |
| 4 | Breadboard (half-size) | Any electronics shop | ₹100 |
| 5 | Male-male jumper wires (40-pc) | Robu.in | ₹60 |
| 6 | 100 nF decoupling caps × 10 | Any electronics shop | ₹20 |
| 7 | 10 kΩ resistors × 5 | Any electronics shop | ₹5 |
| 8 | USB A-to-Micro-B cable | Amazon.in | ₹150 |
| 9 | 650 nm 5 mW laser module | Amazon.in | ₹100 |
| 10 | BPW34 photodiode × 2 | Mouser India | ₹80 |
|    | **Total** | | **~₹23 000** |

> The dominant cost is the FPGA board.  Academic pricing may be lower; check
> Digilent's academic program or second-hand markets.

---

### Wiring Diagram Summary

```
Nexys A7-100T
┌─────────────────────────────────────────┐
│  Pmod JA (top row)                      │
│  ┌────┬──────────────┬─────────────┐   │
│  │Pin │ FPGA signal  │ Connect to  │   │
│  │ 1  │ PDM_CLK (out)│ All 4 mic CLK│  │
│  │ 2  │ PDM_DATA[0]  │ INMP441 #0  │  │
│  │ 3  │ PDM_DATA[1]  │ INMP441 #1  │  │
│  │ 4  │ PDM_DATA[2]  │ INMP441 #2  │  │
│  │ 5  │ GND          │ Mic GND     │  │
│  │ 6  │ 3.3 V        │ Mic VDD     │  │
│  │ 7  │ PDM_DATA[3]  │ INMP441 #3  │  │
│  └────┴──────────────┴─────────────┘   │
│                                         │
│  Pmod JB (top row)                      │
│  ┌────┬──────────────┬─────────────┐   │
│  │Pin │ FPGA signal  │ Connect to  │   │
│  │ 1  │ ADC_CS_N(out)│ MCP3202 CS  │  │
│  │ 2  │ ADC_MOSI(out)│ MCP3202 DIN │  │
│  │ 3  │ ADC_MISO(in) │ MCP3202 DOUT│  │
│  │ 4  │ ADC_SCLK(out)│ MCP3202 CLK │  │
│  │ 5  │ GND          │ ADC GND     │  │
│  │ 6  │ 3.3 V        │ ADC VDD/VREF│  │
│  └────┴──────────────┴─────────────┘   │
│                                         │
│  USB Micro-B ─────────────────► PC      │
│  (JTAG + UART, 115200 baud)            │
└─────────────────────────────────────────┘
```

### Safety Notes for India Lab Environment

1. **Power**: Use the supplied 5 V adapter or USB from a laptop — do NOT use
   an unregulated supply; FPGA I/O damage is permanent.
2. **Laser**: A 5 mW 650 nm laser is Class 3R. Do NOT look into the beam.
   Use a white card as the reflection target and keep the beam below eye level.
3. **Grounding**: Benches in many Indian labs are ungrounded. Use a wrist strap
   when handling the FPGA board, or at minimum touch a grounded metal object
   (water pipe, grounded rack) before picking up the board.
4. **Voltage levels**: Nexys A7 Pmod pins operate at 3.3 V. Do NOT connect
   5 V Arduino signals directly — use a logic level converter (₹30 on Robu.in).

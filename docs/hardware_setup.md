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
  - **Purchase**: ~$300 USD (academic pricing available)

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

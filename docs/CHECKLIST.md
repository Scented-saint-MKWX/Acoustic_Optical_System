# Acoustic-Optical SoC — Step-by-Step Build Checklist

Follow these steps in order.  Each step has a **verification criterion** so
you know when it is safe to proceed to the next.

---

## Phase 0 — Environment Setup

- [ ] **0.1** Install Vivado ML Edition 2022.x or later (free download from AMD/Xilinx).
  - Choose the "Artix-7" device support during installation.
- [ ] **0.2** Clone the repository:
  ```bash
  git clone https://github.com/<your-org>/Acoustic_Optical_System.git
  cd Acoustic_Optical_System
  ```
- [ ] **0.3** Install RISC-V toolchain for firmware compilation:
  ```bash
  # Ubuntu / Debian — installs riscv64-unknown-elf-gcc (supports -march=rv32i)
  sudo apt install gcc-riscv64-unknown-elf

  # If the package installs as riscv64-unknown-elf-gcc, override PREFIX in the Makefile:
  #   make PREFIX=riscv64-unknown-elf-
  # Or install a dedicated rv32 toolchain from:
  #   https://github.com/riscv-collab/riscv-gnu-toolchain/releases
  # which provides riscv32-unknown-elf-gcc (the Makefile default).
  ```
- [ ] **0.4** Install a serial terminal (`screen`, PuTTY, or Tera Term) for UART output.

**✓ Verify:** Run `vivado -version` and either `riscv32-unknown-elf-gcc --version`
or `riscv64-unknown-elf-gcc --version` without errors.  The Makefile
`PREFIX` variable controls which is used (default: `riscv32-unknown-elf-`).

---

## Phase 1 — Firmware Compilation

- [ ] **1.1** Build the firmware hex file:
  ```bash
  cd src/firmware
  make clean && make all
  ```
- [ ] **1.2** Confirm output files exist:
  ```
  src/firmware/firmware.hex   (hex format for $readmemh in block_ram.v)
  src/firmware/firmware.dis   (disassembly — check for correct instruction encoding)
  ```
- [ ] **1.3** Inspect the disassembly to confirm `_start` is at address `0x0`:
  ```bash
  head -20 src/firmware/firmware.dis
  ```
  You should see `00000000 <_start>:`.
- [ ] **1.4** Check that `firmware.hex` is less than 8 KB (32768 hex digits / 2 = 2048 words):
  ```bash
  wc -l src/firmware/firmware.hex   # should be < 2050 lines
  ```

**✓ Verify:** `make all` exits with code 0 and `firmware.hex` exists.

---

## Phase 2 — Behavioral Simulation

Run simulations before spending time on synthesis. This catches most RTL bugs.

- [ ] **2.1** Create the Vivado project (if not already done):
  ```bash
  vivado -mode batch -source scripts/build_vivado.tcl -notrace 2>&1 | head -50
  # Stop after project creation — full synthesis comes later
  ```
  Or create manually in Vivado GUI: File → New Project → RTL Project →
  add all `src/hdl/**/*.v` files and `src/constraints/nexys_a7_100t.xdc`.

- [ ] **2.2** Run the CIC filter testbench:
  ```bash
  vivado -mode batch -source scripts/run_sim.tcl -tclargs tb_cic_filter
  ```
  **Expected:** No X/Z output after reset; decimated output shows non-zero
  values for a square-wave PDM input.

- [ ] **2.3** Run the FFT butterfly testbench:
  ```bash
  vivado -mode batch -source scripts/run_sim.tcl -tclargs tb_fft_butterfly
  ```
  **Expected:** Butterfly output matches expected values for known inputs.

- [ ] **2.4** Run the PDM interface testbench:
  ```bash
  vivado -mode batch -source scripts/run_sim.tcl -tclargs tb_pdm_interface
  ```
  **Expected:** PDM clock generated at ~3.125 MHz; data captured correctly.

- [ ] **2.5** Run the laser vibrometer testbench:
  ```bash
  vivado -mode batch -source scripts/run_sim.tcl -tclargs tb_laser_vibrometer
  ```
  **Expected:** SPI transactions visible; velocity output non-zero after sample.

- [ ] **2.6** Run the RISC-V core testbench:
  ```bash
  vivado -mode batch -source scripts/run_sim.tcl -tclargs tb_riscv_core
  ```
  **Expected:** Core fetches instructions, executes without stalls on BRAM ACK.

- [ ] **2.7** Run the top-level testbench:
  ```bash
  vivado -mode batch -source scripts/run_sim.tcl -tclargs tb_soc_top
  ```
  **Expected:** UART TX line shows serial activity; no undefined (X) states
  on critical signals after reset deassertion.

**✓ Verify:** All 6 testbenches complete without fatal errors or X-propagation
on output ports.

---

## Phase 3 — RTL Synthesis

- [ ] **3.1** Build the complete project and run synthesis:
  ```bash
  vivado -mode batch -source scripts/build_vivado.tcl
  # This also runs implementation and bitstream generation.
  # To run synthesis only, open the project in Vivado GUI → Run Synthesis.
  ```
- [ ] **3.2** Review synthesis utilisation report:
  ```
  vivado_project/utilization_synth.rpt
  ```
  Expected resource usage (approximate):
  | Resource | Expected |
  |----------|---------|
  | LUT | < 8 000 (8% of XC7A100T) |
  | FF | < 4 000 |
  | BRAM | 1–2 (block_ram.v) |
  | DSP48E1 | 2–4 (FFT butterflies) |

- [ ] **3.3** Review synthesis timing report:
  ```
  vivado_project/timing_synth.rpt
  ```
  Check the WNS (Worst Negative Slack) — it must be ≥ 0 ns at 100 MHz.
  If WNS < 0, reduce clock to 80 MHz (add a Clocking Wizard IP or change
  the `create_clock -period` to 12.5 in the XDC).

- [ ] **3.4** Fix any synthesis critical warnings:
  - "Multiple drivers on net" → check `soc_top.v` connections.
  - "Unresolved black box" → missing Verilog module file.
  - "Latch inferred" → add `default:` to all `case` statements.

**✓ Verify:** Synthesis completes with 0 errors; WNS ≥ 0 ns.

---

## Phase 4 — Implementation (Place and Route)

- [ ] **4.1** Run implementation (place and route) — this is included in `build_vivado.tcl`.
  In Vivado GUI: Flow → Run Implementation.

- [ ] **4.2** Review post-implementation timing:
  ```
  vivado_project/timing_impl.rpt
  ```
  Both Setup WNS and Hold WNS must be ≥ 0 ns.

- [ ] **4.3** Review power report:
  ```
  vivado_project/power_impl.rpt
  ```
  Total on-chip power should be < 0.5 W (USB bus can supply ~2.5 W).

- [ ] **4.4** Check I/O assignments in Vivado GUI:
  Open implemented design → I/O Ports pane; verify all top-level ports are
  assigned and show no "Unspecified" bank voltage warnings.

**✓ Verify:** Implementation completes; no timing violations.

---

## Phase 5 — Bitstream Generation

- [ ] **5.1** Generate bitstream — included in `build_vivado.tcl`.
  In Vivado GUI: Flow → Generate Bitstream.

- [ ] **5.2** Confirm bitstream file exists:
  ```
  vivado_project/acoustic_optical_soc.runs/impl_1/soc_top.bit
  ```

**✓ Verify:** Bitstream file size is ~1–3 MB (typical for Artix-7 A100).

---

## Phase 6 — FPGA Programming

- [ ] **6.1** Connect the Nexys A7-100T to your PC via USB Micro-B.
- [ ] **6.2** Power on the board (slide the power switch on the top edge).
- [ ] **6.3** Open Vivado Hardware Manager, or use the TCL script:
  ```bash
  vivado -mode batch -source scripts/program_fpga.tcl
  ```
- [ ] **6.4** Confirm the board is programmed (the `DONE` LED on the board
  turns on after successful programming).

**✓ Verify:** `DONE` LED illuminated; no programming errors.

---

## Phase 7 — Deployment and Verification

- [ ] **7.1** Connect hardware:
  - Plug microphone array into **Pmod JA** (see `docs/hardware_setup.md`).
  - Plug ADC module into **Pmod JB**.
  - Connect USB cable (also provides UART).

- [ ] **7.2** Open a serial terminal:
  ```bash
  screen /dev/ttyUSB1 115200   # Linux; adjust device name
  # On Windows: PuTTY → Serial → COM5 → 115200 baud
  ```

- [ ] **7.3** Press the `CPU_RESETN` button (centre pushbutton) on the board.

- [ ] **7.4** Confirm boot banner:
  ```
  === Acoustic-Optical SoC v1.0 ===
  Platform: Nexys A7-100T (Artix-7)
  Core:     RISC-V RV32I
  ```

- [ ] **7.5** Confirm telemetry frames stream at ~1 Hz:
  ```
  F:1 ANG:0deg PEAK:1000Hz MAG:12345 VEL:0 I:0 Q:0
  ```
  - `F:` — frame counter (increments each loop).
  - `ANG:` — steering angle set by switches SW[7:0].
  - `PEAK:` — dominant audio frequency (Hz) from FFT.
  - `VEL:` — laser vibrometer velocity output.

- [ ] **7.6** Test beamformer steering:
  - Flip switches SW[0]–SW[7] to set angle (each switch = 10°, binary).
  - Speak or clap in front of the microphone array.
  - Observe `PEAK:` frequency changing.

- [ ] **7.7** Test laser vibrometer:
  - Shine laser on a vibrating surface (speaker, piezo, etc.).
  - Observe `VEL:` and `I:` / `Q:` values changing.

**✓ Verify:** Boot banner visible; telemetry frames stream without corrupted
characters; steering angle updates when switches are toggled.

---

## Troubleshooting Quick Reference

| Symptom | Likely Cause | Fix |
|---------|-------------|-----|
| No boot banner | UART baud mismatch | Set terminal to 115200 8N1 |
| `DONE` LED off | Bitstream not generated or wrong device | Confirm part `xc7a100t-csg324-1` in `build_vivado.tcl` |
| All zeros in telemetry | Firmware did not link correctly | Check `firmware.hex` address 0x0 |
| `VEL:` always 0 | SPI ADC not responding | Check Pmod JB wiring; scope SCLK pin |
| Synthesis timing fail | Critical path too slow | Lower clock to 80 MHz |
| X-propagation in sim | Uninitialised memory | `block_ram.v` fills with NOP; check `INIT_FILE` path |

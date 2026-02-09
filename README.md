# Acoustic-Optical Tracking & Laser Vibrometry System
**Platform:** Xilinx Artix-7 (Nexys A7-100T)  
**Core:** Custom RISC-V SoC  

## Abstract
This project implements a high-precision acoustic-optical sensing system. By integrating a PDM microphone array for beamforming and a Laser Vibrometry subsystem, the system can "see" and "hear" specific vibrations at a distance. The hardware utilizes an Artix-7 FPGA to handle high-speed DSP tasks, coordinated by a RISC-V soft-core processor.

## Project Structure
* `src/hdl/`: Verilog source for the PDM interface, CIC filters, and FFT.
* `src/firmware/`: C code for the RISC-V control logic.
* `sim/`: Testbenches for hardware verification.
* `docs/`: Technical diagrams and mathematical models.

## Tools
* Vivado ML Edition
* VS Code (Heralded for HDL editing)
* Git/GitHub (Version Control)
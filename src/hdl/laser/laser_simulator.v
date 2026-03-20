// =============================================================================
// Laser Vibrometer Simulator (NCO / DDS)
// Target: Xilinx Artix-7, Nexys A7-100T (100 MHz system clock)
//
// Description:
//   Simulates a laser Doppler vibrometer for demonstration purposes.
//   The module contains a Numerically Controlled Oscillator (NCO / DDS) that
//   generates a calibrated sine-wave output at a software-configurable
//   frequency.  The default frequency is DEFAULT_FREQ Hz (440 Hz).
//
//   A 32-bit phase accumulator is incremented each clock cycle by a
//   phase-increment word derived from the target frequency:
//
//     phase_inc = round(freq_hz × 2^PHASE_WIDTH / CLK_FREQ)
//
//   The top SINE_LUT_BITS bits of the accumulator address a sine look-up
//   table, producing a band-limited OUTPUT_WIDTH-bit signed sine wave.
//
//   Clock arithmetic (defaults):
//     CLK_FREQ   = 100 000 000 Hz
//     PHASE_WIDTH = 32 bits → frequency resolution = 100e6 / 2^32 ≈ 0.023 Hz
//     For 440 Hz: phase_inc = 440 × 2^32 / 100 000 000 = 18 905 (integer)
//
//   The module also exposes the current frequency via a Wishbone slave
//   register interface so the RISC-V core can configure and read it back.
//
// Register map (Wishbone, byte-addressed):
//   0x00  SIM_CTRL      — bit 0 = enable, write-only
//   0x04  SIM_STATUS    — bit 0 = enabled, read-only
//   0x08  SIM_FREQ_HZ   — R/W, target frequency in Hz (default = DEFAULT_FREQ)
//   0x0C  SIM_WAVE_OUT  — read-only, current 16-bit signed sine-wave sample
//   0x10  SIM_FREQ_HZ   — alias of 0x08 (for firmware backward compatibility)
// =============================================================================
`timescale 1ns / 1ps
`default_nettype none

module laser_simulator #(
    parameter CLK_FREQ       = 100_000_000,  // System clock frequency (Hz)
    parameter DEFAULT_FREQ   = 440,          // Initial simulated frequency (Hz)
    parameter PHASE_WIDTH    = 32,           // NCO phase-accumulator width (bits)
    parameter SINE_LUT_BITS  = 8,            // Sine LUT address width → 256 entries
    parameter OUTPUT_WIDTH   = 16            // Output sine-wave sample width (bits)
)(
    input  wire                          clk,
    input  wire                          rst_n,

    // Wishbone Slave (for RISC-V configuration / readback)
    input  wire [31:0]                   wb_adr_i,
    input  wire [31:0]                   wb_dat_i,
    output reg  [31:0]                   wb_dat_o,
    input  wire                          wb_we_i,
    input  wire                          wb_cyc_i,
    input  wire                          wb_stb_i,
    output reg                           wb_ack_o,

    // Outputs
    output wire [31:0]                   sim_freq_hz,   // Current frequency register
    output wire signed [OUTPUT_WIDTH-1:0] wave_out,     // Sine-wave sample
    output wire                          sample_valid   // 1-cycle pulse per new sample
);

    // =========================================================================
    // Sine look-up table (256-entry, 16-bit signed, Q1.15)
    // Values represent sin(2π·k/256) × 32767 for k = 0..255
    // Generated for the first quadrant and mirrored.
    // =========================================================================
    reg signed [OUTPUT_WIDTH-1:0] sine_lut [0:255];

    integer k;
    real twopi;
    initial begin
        twopi = 2.0 * 3.14159265358979;
        for (k = 0; k < 256; k = k + 1)
            sine_lut[k] = $signed($rtoi($sin(twopi * k / 256.0) * 32767.0));
    end

    // =========================================================================
    // Configurable frequency register
    // =========================================================================
    reg [31:0] freq_reg;    // Frequency in Hz
    reg        enabled;

    // Phase-increment calculation:
    //   phase_inc = freq_hz × 2^PHASE_WIDTH / CLK_FREQ
    // Done in fixed-point: use 64-bit arithmetic to avoid overflow.
    // Pre-compute as Verilog constant expression for synthesis:
    //   phase_inc_calc = freq_reg × 2^32 / 100_000_000
    // We implement the multiply-shift using a register updated whenever
    // freq_reg changes.
    reg [PHASE_WIDTH-1:0] phase_inc;

    // Phase-increment update (recomputed in one cycle via a multiply-shift).
    // This is a 32×32 multiply kept in 64 bits; Vivado infers a DSP slice.
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            freq_reg  <= DEFAULT_FREQ[31:0];
            // Use same formula as runtime: phase_inc = freq × 2^32 / CLK_FREQ
            phase_inc <= (DEFAULT_FREQ * 64'd4294967296) / CLK_FREQ;
            enabled   <= 1'b0;
        end else begin
            // Recompute phase_inc only when freq_reg changes.
            // Using: phase_inc = freq × 2^32 / CLK_FREQ
            // ≡ freq × (2^32 / CLK_FREQ)
            // For CLK_FREQ = 100MHz: 2^32/100MHz = 42.9497 → multiply by 43 then >>1 approx.
            // Exact: phase_inc = (freq_reg * 64'd4294967296) / CLK_FREQ
            //        (this is synthesizable with DSP since CLK_FREQ is a constant)
            phase_inc <= (freq_reg * 64'd4294967296) / CLK_FREQ;
        end
    end

    // =========================================================================
    // NCO phase accumulator
    // =========================================================================
    reg [PHASE_WIDTH-1:0] phase_acc;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            phase_acc <= 0;
        else if (enabled)
            phase_acc <= phase_acc + phase_inc;
    end

    // Top SINE_LUT_BITS of phase accumulator address the LUT
    assign wave_out     = sine_lut[phase_acc[PHASE_WIDTH-1 -: SINE_LUT_BITS]];
    assign sim_freq_hz  = freq_reg;
    assign sample_valid = enabled;  // One sample valid per clock cycle when enabled

    // =========================================================================
    // Wishbone register interface
    // =========================================================================
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            wb_ack_o <= 1'b0;
            wb_dat_o <= 32'd0;
        end else begin
            wb_ack_o <= 1'b0;

            if (wb_cyc_i && wb_stb_i && !wb_ack_o) begin
                wb_ack_o <= 1'b1;

                if (wb_we_i) begin
                    case (wb_adr_i[4:2])
                        3'd0: enabled  <= wb_dat_i[0];           // SIM_CTRL
                        3'd2: freq_reg <= wb_dat_i;               // SIM_FREQ_HZ
                        3'd4: freq_reg <= wb_dat_i;               // SIM_FREQ_HZ alias
                        default: ;
                    endcase
                end else begin
                    case (wb_adr_i[4:2])
                        3'd0: wb_dat_o <= 32'd0;                  // SIM_CTRL (write-only)
                        3'd1: wb_dat_o <= {31'd0, enabled};       // SIM_STATUS
                        3'd2: wb_dat_o <= freq_reg;               // SIM_FREQ_HZ
                        3'd3: wb_dat_o <= {{(32-OUTPUT_WIDTH){wave_out[OUTPUT_WIDTH-1]}},
                                           wave_out};             // SIM_WAVE_OUT
                        3'd4: wb_dat_o <= freq_reg;               // SIM_FREQ_HZ alias
                        default: wb_dat_o <= 32'd0;
                    endcase
                end
            end
        end
    end

endmodule
`default_nettype wire

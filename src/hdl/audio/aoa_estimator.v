// =============================================================================
// Hardware Angle-of-Arrival Estimator
// Target: Xilinx Artix-7, Nexys A7-100T
//
// Description:
//   Estimates the Angle of Arrival (AoA) of a broadband acoustic source
//   using Time-Difference of Arrival (TDOA) between the two end microphones
//   (mic 0 and mic 3) of a 4-element linear array.
//
//   The TDOA is estimated by computing the cross-correlation between mic0
//   and a range of time-shifted versions of mic3, then choosing the lag
//   index at which the correlation magnitude is maximum.  That lag is
//   converted to an angle via a pre-computed look-up table.
//
// Algorithm:
//   For lag k (integer samples, range −MAX_LAG … +MAX_LAG):
//     cc[k] = Σ  mic0[n − MAX_LAG] × mic3[n − (MAX_LAG − k)]
//             n
//   implemented as:
//     • mic0 is delayed by MAX_LAG samples (fixed reference)
//     • mic3 is delayed by (MAX_LAG − k) samples → index j = MAX_LAG + k
//       so j runs 0 … 2·MAX_LAG (= 0 … 8)
//     • cc[j] = Σ  mic0_delay[MAX_LAG] × mic3_delay[j]
//   After ACCUM_LEN samples, find j_peak with max |cc[j]|.
//
//   Physical parameters (d = 10 mm mic pitch, 3 spacings between mic0 & mic3):
//     TDOA_max = 3 × 0.010 × 48828 / 343 ≈ 4.27 samples → MAX_LAG = 4
//
//   Angle look-up table (degrees × 10):
//     j  lag k  angle
//     0   +4   +695  (≈ +69.5°, src on mic3 side)
//     1   +3   +446
//     2   +2   +279
//     3   +1   +135
//     4    0      0  (broadside)
//     5   −1   −135
//     6   −2   −279
//     7   −3   −446
//     8   −4   −695  (≈ −69.5°, src on mic0 side)
//
// I/O:
//   mic0, mic3    — truncated 16-bit PCM from channels 0 and 3
//   pcm_valid     — one pulse per new sample pair
//   aoa_angle     — estimated AoA, signed, degrees × 10
//   angle_valid   — one pulse when a new estimate is available
// =============================================================================
`timescale 1ns / 1ps
`default_nettype none

module aoa_estimator #(
    parameter DATA_WIDTH = 16,    // PCM sample width
    parameter MAX_LAG    = 4,     // Maximum TDOA lag (samples); 2×MAX_LAG+1 lags total
    parameter ACCUM_LEN  = 256    // Accumulation window length (samples)
)(
    input  wire                        clk,
    input  wire                        rst_n,

    // PCM inputs (truncated from 24-bit I2S to DATA_WIDTH)
    input  wire signed [DATA_WIDTH-1:0] mic0,
    input  wire signed [DATA_WIDTH-1:0] mic3,
    input  wire                         pcm_valid,  // One pulse per sample

    // Output
    output reg  signed [15:0]           aoa_angle,  // Degrees × 10, signed
    output reg                          angle_valid  // Pulse when estimate ready
);

    // -------------------------------------------------------------------------
    // Derived parameters
    // -------------------------------------------------------------------------
    localparam NUM_LAGS   = 2 * MAX_LAG + 1;              // 9
    localparam DELAY_DEPTH = 2 * MAX_LAG + 1;             // 9 entries needed
    localparam ACCUM_BITS = DATA_WIDTH * 2 +
                            $clog2(ACCUM_LEN) + 1;        // ≈ 41 bits; safe 48 bits

    // -------------------------------------------------------------------------
    // Angle look-up table (degrees × 10, ROM-style)
    // Index j = 0..8; angle_lut[j] = arcsin((MAX_LAG-j)*c/(3*d*fs)) × 10
    // c=343 m/s, d=10mm pitch, 3 spacings, fs=48828 Hz
    // -------------------------------------------------------------------------
    reg signed [15:0] angle_lut [0:NUM_LAGS-1];
    initial begin
        angle_lut[0] =  695;   // lag = +4 → +69.5°
        angle_lut[1] =  446;   // lag = +3 → +44.6°
        angle_lut[2] =  279;   // lag = +2 → +27.9°
        angle_lut[3] =  135;   // lag = +1 → +13.5°
        angle_lut[4] =    0;   // lag =  0 →   0°
        angle_lut[5] = -135;   // lag = −1 → −13.5°
        angle_lut[6] = -279;   // lag = −2 → −27.9°
        angle_lut[7] = -446;   // lag = −3 → −44.6°
        angle_lut[8] = -695;   // lag = −4 → −69.5°
    end

    // -------------------------------------------------------------------------
    // Delay lines
    // -------------------------------------------------------------------------
    // mic0 needs a fixed delay of MAX_LAG samples
    // mic3 needs delays of 0 … 2×MAX_LAG samples
    reg signed [DATA_WIDTH-1:0] mic0_dl [0:MAX_LAG];        // 5 taps
    reg signed [DATA_WIDTH-1:0] mic3_dl [0:2*MAX_LAG];      // 9 taps

    integer i;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            for (i = 0; i <= MAX_LAG;     i = i + 1) mic0_dl[i] <= 0;
            for (i = 0; i <= 2 * MAX_LAG; i = i + 1) mic3_dl[i] <= 0;
        end else if (pcm_valid) begin
            // Shift mic0 delay line (index 0 = newest)
            mic0_dl[0] <= mic0;
            for (i = 1; i <= MAX_LAG; i = i + 1)
                mic0_dl[i] <= mic0_dl[i-1];

            // Shift mic3 delay line (index 0 = newest)
            mic3_dl[0] <= mic3;
            for (i = 1; i <= 2 * MAX_LAG; i = i + 1)
                mic3_dl[i] <= mic3_dl[i-1];
        end
    end

    // -------------------------------------------------------------------------
    // Cross-correlation accumulators
    // cc_acc[j] = Σ mic0_dl[MAX_LAG] × mic3_dl[j]  for j = 0..2·MAX_LAG
    // -------------------------------------------------------------------------
    reg signed [47:0] cc_acc [0:NUM_LAGS-1];      // 48-bit accumulators
    reg signed [47:0] cc_snap [0:NUM_LAGS-1];     // Snapshot at end of window
    reg [$clog2(ACCUM_LEN):0] samp_cnt;            // 0 … ACCUM_LEN

    genvar g;
    generate
        for (g = 0; g < NUM_LAGS; g = g + 1) begin : gen_corr
            // Signed product: 16b × 16b = 32b; sign-extended to 48b before accumulate
            wire signed [31:0] prod = mic0_dl[MAX_LAG] * mic3_dl[g];
            // Accumulator update is handled in the always block below
        end
    endgenerate

    integer j;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            for (j = 0; j < NUM_LAGS; j = j + 1) begin
                cc_acc[j]  <= 48'sd0;
                cc_snap[j] <= 48'sd0;
            end
            samp_cnt <= 0;
        end else if (pcm_valid) begin
            if (samp_cnt == ACCUM_LEN - 1) begin
                // Snapshot accumulators and clear.
                // Both operands are declared signed, so the 16×16 product is
                // a signed 32-bit value; the 48-bit signed accumulator
                // will sign-extend it automatically on addition.
                for (j = 0; j < NUM_LAGS; j = j + 1) begin
                    cc_snap[j] <= cc_acc[j] + (mic0_dl[MAX_LAG] * mic3_dl[j]);
                    cc_acc[j]  <= 48'sd0;
                end
                samp_cnt <= 0;
            end else begin
                for (j = 0; j < NUM_LAGS; j = j + 1)
                    cc_acc[j] <= cc_acc[j] + (mic0_dl[MAX_LAG] * mic3_dl[j]);
                samp_cnt <= samp_cnt + 1;
            end
        end
    end

    // -------------------------------------------------------------------------
    // Peak-detection state machine
    // Runs one cycle after the snapshot is taken (samp_cnt wraps to 0).
    // -------------------------------------------------------------------------
    reg snapshot_ready;    // Pulse when new snapshot is available

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            snapshot_ready <= 1'b0;
        else
            snapshot_ready <= pcm_valid && (samp_cnt == ACCUM_LEN - 1);
    end

    // Peak search runs sequentially over the NUM_LAGS values the cycle
    // after snapshot_ready.  Uses absolute value for comparison.
    reg [3:0]  search_idx;     // 0..8
    reg [47:0] best_mag;       // Unsigned magnitude of best correlation
    reg [3:0]  best_j;         // Index of best correlation

    localparam SEARCH_IDLE   = 1'b0;
    localparam SEARCH_ACTIVE = 1'b1;
    reg search_state;

    function [47:0] abs48;
        input signed [47:0] x;
        abs48 = x[47] ? (~x + 48'd1) : x;
    endfunction

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            search_idx   <= 0;
            best_mag     <= 0;
            best_j       <= MAX_LAG[3:0];  // Default: broadside (j = MAX_LAG)
            search_state <= SEARCH_IDLE;
            aoa_angle    <= 16'sd0;
            angle_valid  <= 1'b0;
        end else begin
            angle_valid <= 1'b0;

            case (search_state)
                SEARCH_IDLE: begin
                    if (snapshot_ready) begin
                        search_idx   <= 0;
                        best_mag     <= 0;
                        best_j       <= MAX_LAG[3:0];
                        search_state <= SEARCH_ACTIVE;
                    end
                end

                SEARCH_ACTIVE: begin
                    // One lag per cycle; compare absolute value
                    if (abs48(cc_snap[search_idx]) > best_mag) begin
                        best_mag <= abs48(cc_snap[search_idx]);
                        best_j   <= search_idx[3:0];
                    end

                    if (search_idx == NUM_LAGS - 1) begin
                        // Search complete — output result
                        aoa_angle    <= angle_lut[best_j];
                        angle_valid  <= 1'b1;
                        search_state <= SEARCH_IDLE;
                    end else begin
                        search_idx <= search_idx + 1;
                    end
                end

                default: search_state <= SEARCH_IDLE;
            endcase
        end
    end

endmodule
`default_nettype wire

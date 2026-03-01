// =============================================================================
// Radix-2 FFT Butterfly Unit
// Description: Single butterfly computation for DIT (Decimation-In-Time) FFT.
//              Complex multiply-add/subtract with fixed-point Q1.15 twiddle.
// =============================================================================
`timescale 1ns / 1ps
`default_nettype none

module fft_butterfly #(
    parameter DATA_WIDTH = 16   // Width of real/imag components
)(
    input  wire                          clk,
    input  wire                          rst_n,
    input  wire                          valid_in,

    // Input pair (A, B) – complex
    input  wire signed [DATA_WIDTH-1:0]  ar, ai,   // A: real, imag
    input  wire signed [DATA_WIDTH-1:0]  br, bi,   // B: real, imag

    // Twiddle factor W = Wr + j*Wi  (Q1.15 format)
    input  wire signed [DATA_WIDTH-1:0]  wr, wi,

    // Output pair (X, Y) – complex
    output reg  signed [DATA_WIDTH-1:0]  xr, xi,   // X = A + W*B
    output reg  signed [DATA_WIDTH-1:0]  yr, yi,   // Y = A - W*B
    output reg                           valid_out
);

    // Pipeline stage 1: Complex multiply W * B
    reg signed [2*DATA_WIDTH-1:0] mult_br_wr, mult_bi_wi;
    reg signed [2*DATA_WIDTH-1:0] mult_br_wi, mult_bi_wr;
    reg signed [DATA_WIDTH-1:0]   ar_d1, ai_d1;
    reg                           valid_d1;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            mult_br_wr <= 0; mult_bi_wi <= 0;
            mult_br_wi <= 0; mult_bi_wr <= 0;
            ar_d1 <= 0; ai_d1 <= 0;
            valid_d1 <= 1'b0;
        end else begin
            valid_d1   <= valid_in;
            ar_d1      <= ar;
            ai_d1      <= ai;
            mult_br_wr <= br * wr;
            mult_bi_wi <= bi * wi;
            mult_br_wi <= br * wi;
            mult_bi_wr <= bi * wr;
        end
    end

    // Pipeline stage 2: Add/subtract to form butterfly outputs
    wire signed [DATA_WIDTH-1:0] wb_real = (mult_br_wr - mult_bi_wi) >>> (DATA_WIDTH - 1);
    wire signed [DATA_WIDTH-1:0] wb_imag = (mult_br_wi + mult_bi_wr) >>> (DATA_WIDTH - 1);

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            xr <= 0; xi <= 0;
            yr <= 0; yi <= 0;
            valid_out <= 1'b0;
        end else begin
            valid_out <= valid_d1;
            xr <= ar_d1 + wb_real;
            xi <= ai_d1 + wb_imag;
            yr <= ar_d1 - wb_real;
            yi <= ai_d1 - wb_imag;
        end
    end

endmodule
`default_nettype wire

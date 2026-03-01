// =============================================================================
// Twiddle Factor ROM
// Description: Pre-computed twiddle factors for a 256-point FFT.
//              W(k) = cos(2*pi*k/N) - j*sin(2*pi*k/N) in Q1.15 format.
//              Only N/2 = 128 entries needed (symmetry).
// =============================================================================
`timescale 1ns / 1ps
`default_nettype none

module twiddle_rom #(
    parameter FFT_SIZE   = 256,
    parameter DATA_WIDTH = 16
)(
    input  wire                          clk,
    input  wire [$clog2(FFT_SIZE/2)-1:0] addr,

    output reg  signed [DATA_WIDTH-1:0]  tw_real,
    output reg  signed [DATA_WIDTH-1:0]  tw_imag
);

    // Q1.15 format: value = integer / 32768
    // cos/sin values pre-computed for 256-point FFT

    reg signed [DATA_WIDTH-1:0] rom_real [0:FFT_SIZE/2-1];
    reg signed [DATA_WIDTH-1:0] rom_imag [0:FFT_SIZE/2-1];

    initial begin : init_twiddles
        integer k;
        real theta;
        for (k = 0; k < FFT_SIZE/2; k = k + 1) begin
            theta = -2.0 * 3.14159265358979 * k / FFT_SIZE;
            // $rtoi rounds toward zero; add 0.5 for rounding
            rom_real[k] = $rtoi($cos(theta) * 32767.0);
            rom_imag[k] = $rtoi($sin(theta) * 32767.0);
        end
    end

    always @(posedge clk) begin
        tw_real <= rom_real[addr];
        tw_imag <= rom_imag[addr];
    end

endmodule
`default_nettype wire

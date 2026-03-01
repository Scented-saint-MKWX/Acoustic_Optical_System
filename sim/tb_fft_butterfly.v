// =============================================================================
// Testbench: FFT Butterfly Unit
// Verifies the radix-2 butterfly computation with known twiddle factors.
// =============================================================================
`timescale 1ns / 1ps

module tb_fft_butterfly;

    parameter CLK_PERIOD = 10;
    parameter DW = 16;

    reg                     clk, rst_n, valid_in;
    reg  signed [DW-1:0]    ar, ai, br, bi, wr, wi;
    wire signed [DW-1:0]    xr, xi, yr, yi;
    wire                    valid_out;

    fft_butterfly #(.DATA_WIDTH(DW)) uut (
        .clk(clk), .rst_n(rst_n), .valid_in(valid_in),
        .ar(ar), .ai(ai), .br(br), .bi(bi),
        .wr(wr), .wi(wi),
        .xr(xr), .xi(xi), .yr(yr), .yi(yi),
        .valid_out(valid_out)
    );

    initial clk = 0;
    always #(CLK_PERIOD/2) clk = ~clk;

    initial begin
        $dumpfile("tb_fft_butterfly.vcd");
        $dumpvars(0, tb_fft_butterfly);

        rst_n    = 0;
        valid_in = 0;
        ar = 0; ai = 0; br = 0; bi = 0; wr = 0; wi = 0;

        #50;
        rst_n = 1;
        #20;

        // ---- Test 1: W = 1 + j0 (twiddle = unity) ----
        // A = (100, 0), B = (50, 0), W = (32767, 0) ≈ 1.0 in Q1.15
        // Expected: X = A + B = (150, 0), Y = A - B = (50, 0)
        @(posedge clk);
        ar = 16'd100;  ai = 16'd0;
        br = 16'd50;   bi = 16'd0;
        wr = 16'd32767; wi = 16'd0;   // W ≈ 1.0
        valid_in = 1;
        @(posedge clk);
        valid_in = 0;

        // Wait for output
        wait(valid_out);
        @(posedge clk);
        $display("Test 1: X=(%0d,%0d) Y=(%0d,%0d)  [Expected X=(150,0) Y=(50,0)]",
                 xr, xi, yr, yi);

        #40;

        // ---- Test 2: W = 0 - j1 (twiddle = -j) ----
        // A = (100, 0), B = (0, 50), W = (0, -32767) ≈ -j
        // W*B = (-j)*(j50) = 50  → X = (150, 0), Y = (50, 0)
        @(posedge clk);
        ar = 16'd100;  ai = 16'd0;
        br = 16'd0;    bi = 16'd50;
        wr = 16'd0;    wi = -16'd32767;
        valid_in = 1;
        @(posedge clk);
        valid_in = 0;

        wait(valid_out);
        @(posedge clk);
        $display("Test 2: X=(%0d,%0d) Y=(%0d,%0d)", xr, xi, yr, yi);

        #100;
        $display("=== FFT Butterfly testbench complete ===");
        $finish;
    end

endmodule

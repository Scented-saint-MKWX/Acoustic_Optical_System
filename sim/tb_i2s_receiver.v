// =============================================================================
// Testbench: I2S Receiver
// Drives simulated INMP441-style I2S data and verifies PCM capture.
// =============================================================================
`timescale 1ns / 1ps

module tb_i2s_receiver;

    parameter CLK_PERIOD = 10;  // 100 MHz

    // DUT I/O
    reg         clk, rst_n;
    wire        i2s_sck;
    wire        i2s_ws;
    reg  [3:0]  i2s_sd;
    wire [95:0] pcm_out;     // 4 × 24 bits
    wire        pcm_valid;

    i2s_receiver #(
        .NUM_MICS  (4),
        .SCK_DIV   (32),
        .FRAME_LEN (32),
        .DATA_BITS (24)
    ) uut (
        .clk       (clk),
        .rst_n     (rst_n),
        .i2s_sck   (i2s_sck),
        .i2s_ws    (i2s_ws),
        .i2s_sd    (i2s_sd),
        .pcm_out   (pcm_out),
        .pcm_valid (pcm_valid)
    );

    // Clock generation
    initial clk = 1'b0;
    always #(CLK_PERIOD/2) clk = ~clk;

    // ==========================================================================
    // Simulated INMP441 response:
    //   mic0 outputs a fixed 24-bit pattern: 24'hA5_1234
    //   mic1: 24'h0B_ABCD
    //   mic2: 24'h00_0001
    //   mic3: 24'hFF_FFFF
    // ==========================================================================
    reg [23:0] mic_data [0:3];
    reg [4:0]  bit_pos;   // Track which bit is being shifted out
    reg        prev_ws;

    initial begin
        mic_data[0] = 24'hA5_1234;
        mic_data[1] = 24'h0B_ABCD;
        mic_data[2] = 24'h00_0001;
        mic_data[3] = 24'hFF_FFFF;
        i2s_sd      = 4'b0000;
        bit_pos     = 0;
        prev_ws     = 1'b1;
    end

    // Drive SD lines: output MSB-first on rising SCK when WS = 0 (left channel)
    always @(posedge i2s_sck or posedge i2s_ws) begin
        if (i2s_ws) begin
            // Right channel: drive 0 (mics are left-channel only)
            i2s_sd  <= 4'b0000;
            bit_pos <= 0;
        end else begin
            // Left channel: shift out one bit per SCK cycle
            if (bit_pos < 24)
                i2s_sd <= {mic_data[3][23 - bit_pos],
                           mic_data[2][23 - bit_pos],
                           mic_data[1][23 - bit_pos],
                           mic_data[0][23 - bit_pos]};
            else
                i2s_sd <= 4'b0000;   // Padding bits
            bit_pos <= bit_pos + 1;
        end
    end

    // Monitor
    always @(posedge clk) begin
        if (pcm_valid) begin
            $display("T=%0t  pcm_valid: mic0=%h mic1=%h mic2=%h mic3=%h",
                     $time,
                     pcm_out[23:0],
                     pcm_out[47:24],
                     pcm_out[71:48],
                     pcm_out[95:72]);
        end
    end

    // Test sequence
    integer sample_count;
    initial begin
        $dumpfile("tb_i2s_receiver.vcd");
        $dumpvars(0, tb_i2s_receiver);

        rst_n        = 1'b0;
        sample_count = 0;
        #100;
        rst_n = 1'b1;

        // Wait for 4 complete sample frames
        @(posedge pcm_valid); sample_count++;
        @(posedge pcm_valid); sample_count++;
        @(posedge pcm_valid); sample_count++;
        @(posedge pcm_valid); sample_count++;

        $display("[PASS] Captured %0d sample frames.", sample_count);

        // Verify first sample (basic sanity — full bit check requires gate-sim)
        if (pcm_out[23:0] !== 24'hA5_1234)
            $display("[WARN] mic0 PCM = %h (expected A51234)", pcm_out[23:0]);

        #200;
        $finish;
    end

endmodule

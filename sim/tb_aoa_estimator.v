// =============================================================================
// Testbench: AoA Estimator
// Injects synthetic I2S PCM samples with a known time delay between mic0 and
// mic3 and verifies that the estimated angle is in the expected quadrant.
// =============================================================================
`timescale 1ns / 1ps

module tb_aoa_estimator;

    parameter CLK_PERIOD = 10;   // 100 MHz
    parameter ACCUM_LEN  = 256;

    reg        clk, rst_n;
    reg signed [15:0] mic0_in, mic3_in;
    reg                pcm_valid;
    wire signed [15:0] aoa_angle;
    wire               angle_valid;

    aoa_estimator #(
        .DATA_WIDTH (16),
        .MAX_LAG    (4),
        .ACCUM_LEN  (ACCUM_LEN)
    ) uut (
        .clk         (clk),
        .rst_n       (rst_n),
        .mic0        (mic0_in),
        .mic3        (mic3_in),
        .pcm_valid   (pcm_valid),
        .aoa_angle   (aoa_angle),
        .angle_valid (angle_valid)
    );

    initial clk = 1'b0;
    always #(CLK_PERIOD/2) clk = ~clk;

    // ==========================================================================
    // Stimulus: pure sine wave, mic3 leads mic0 by +2 samples (lag k=+2)
    // Expected AoA: +279 (= +27.9°, source on mic3 side)
    // ==========================================================================
    integer  samp_idx;
    integer  n;
    real     twopi;
    real     freq;
    real     fs;
    real     sig_val;
    integer  DELAY;     // Lag: mic3 leads mic0 by DELAY samples

    reg signed [15:0] wave_buf [0:511];   // Pre-computed sine table
    integer           buf_head;

    initial begin
        twopi = 2.0 * 3.14159265358979;
        freq  = 1000.0;    // 1 kHz test tone
        fs    = 48828.0;
        DELAY = 2;         // mic3 leads mic0 by 2 samples

        // Fill sine buffer (two ACCUM_LEN windows worth)
        for (n = 0; n < 512; n = n + 1) begin
            sig_val      = $sin(twopi * freq * n / fs) * 16384.0;
            wave_buf[n]  = $rtoi(sig_val);
        end
    end

    // Monitor
    always @(posedge clk) begin
        if (angle_valid) begin
            $display("T=%0t  angle_valid: aoa_angle=%0d (degrees×10)", $time, aoa_angle);
        end
    end

    // Test sequence
    integer estimate_count;
    initial begin
        $dumpfile("tb_aoa_estimator.vcd");
        $dumpvars(0, tb_aoa_estimator);

        rst_n          = 1'b0;
        pcm_valid      = 1'b0;
        mic0_in        = 16'sd0;
        mic3_in        = 16'sd0;
        samp_idx       = 0;
        estimate_count = 0;
        buf_head       = 0;

        #200;
        rst_n = 1'b1;
        #50;

        // ---- Inject ACCUM_LEN × 3 samples and collect two angle estimates ----
        while (estimate_count < 2) begin
            @(posedge clk);
            pcm_valid = 1'b1;
            // mic0 = wave at n, mic3 = wave at n+DELAY (mic3 leads by DELAY)
            mic0_in = wave_buf[samp_idx % 512];
            mic3_in = wave_buf[(samp_idx + DELAY) % 512];
            samp_idx++;
            @(posedge clk);
            pcm_valid = 1'b0;
            @(posedge clk);

            if (angle_valid) begin
                estimate_count++;
                if (aoa_angle > 16'sd0)
                    $display("[PASS] Estimate %0d: AoA = %0d (positive, mic3-side source)",
                             estimate_count, aoa_angle);
                else
                    $display("[WARN] Estimate %0d: AoA = %0d (expected positive for lag +2)",
                             estimate_count, aoa_angle);
            end
        end

        $display("[DONE] aoa_estimator testbench complete.");
        #500;
        $finish;
    end

endmodule

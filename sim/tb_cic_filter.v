// =============================================================================
// Testbench: CIC Decimation Filter
// Feeds a 1-bit PDM signal (square wave) and checks decimated output.
// =============================================================================
`timescale 1ns / 1ps

module tb_cic_filter;

    parameter CLK_PERIOD = 10;  // 100 MHz

    reg        clk;
    reg        rst_n;
    reg        sample_valid;
    reg        data_in;

    wire [15:0] data_out;
    wire        data_valid;

    // DUT
    cic_filter #(
        .ORDER     (4),
        .DEC_RATIO (64),
        .INP_WIDTH (1),
        .ACC_WIDTH (36),
        .OUT_WIDTH (16)
    ) uut (
        .clk          (clk),
        .rst_n        (rst_n),
        .sample_valid (sample_valid),
        .data_in      (data_in),
        .data_out     (data_out),
        .data_valid   (data_valid)
    );

    // Clock generation
    initial clk = 0;
    always #(CLK_PERIOD/2) clk = ~clk;

    // PDM sample rate tick generator (~3.125 MHz → every 32 clocks)
    integer pdm_cnt;
    initial pdm_cnt = 0;

    always @(posedge clk) begin
        sample_valid <= 1'b0;
        if (pdm_cnt == 31) begin
            pdm_cnt      <= 0;
            sample_valid <= 1'b1;
        end else begin
            pdm_cnt <= pdm_cnt + 1;
        end
    end

    // Generate a PDM-like square wave (high for 48, low for 16 → ~75% duty)
    integer pdm_phase;
    initial pdm_phase = 0;

    always @(posedge clk) begin
        if (sample_valid) begin
            data_in   <= (pdm_phase < 48) ? 1'b1 : 1'b0;
            pdm_phase <= (pdm_phase == 63) ? 0 : pdm_phase + 1;
        end
    end

    // Monitor output
    integer out_count;
    initial out_count = 0;

    always @(posedge clk) begin
        if (data_valid) begin
            $display("T=%0t  CIC output[%0d] = %0d (0x%04h)",
                     $time, out_count, $signed(data_out), data_out);
            out_count <= out_count + 1;
        end
    end

    // Stimulus
    initial begin
        $dumpfile("tb_cic_filter.vcd");
        $dumpvars(0, tb_cic_filter);

        rst_n   = 0;
        data_in = 0;
        #100;
        rst_n = 1;

        // Run for enough time to see many decimated outputs
        // 64 PDM samples per output × 32 clk per PDM sample = 2048 clk per output
        // 20 outputs × 2048 = ~40960 clocks
        #500000;

        $display("=== CIC Filter test complete. %0d outputs generated. ===", out_count);
        $finish;
    end

endmodule

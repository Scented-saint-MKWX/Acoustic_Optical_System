// =============================================================================
// Testbench: PDM Interface
// Simulates PDM microphone data capture and clock generation.
// =============================================================================
`timescale 1ns / 1ps

module tb_pdm_interface;

    parameter CLK_PERIOD = 10;  // 100 MHz

    reg        clk, rst_n, enable;
    reg  [3:0] pdm_data;
    wire       pdm_clk;
    wire [3:0] sample_out;
    wire       sample_valid;

    pdm_interface #(.NUM_MICS(4), .CLK_DIV(32)) uut (
        .clk          (clk),
        .rst_n        (rst_n),
        .enable       (enable),
        .pdm_clk      (pdm_clk),
        .pdm_data     (pdm_data),
        .sample_out   (sample_out),
        .sample_valid (sample_valid)
    );

    initial clk = 0;
    always #(CLK_PERIOD/2) clk = ~clk;

    // Simulate PDM outputs (toggling patterns)
    integer sample_cnt;
    initial sample_cnt = 0;

    always @(posedge pdm_clk) begin
        // Mic 0: 75% ones (high-amplitude positive)
        pdm_data[0] <= ($random % 4 != 0) ? 1'b1 : 1'b0;
        // Mic 1: 50% ones (zero crossing)
        pdm_data[1] <= $random % 2;
        // Mic 2: 25% ones (negative)
        pdm_data[2] <= ($random % 4 == 0) ? 1'b1 : 1'b0;
        // Mic 3: all ones (max positive)
        pdm_data[3] <= 1'b1;
        sample_cnt  <= sample_cnt + 1;
    end

    // Monitor
    always @(posedge clk) begin
        if (sample_valid)
            $display("T=%0t  PDM capture: %b", $time, sample_out);
    end

    initial begin
        $dumpfile("tb_pdm_interface.vcd");
        $dumpvars(0, tb_pdm_interface);

        rst_n    = 0;
        enable   = 0;
        pdm_data = 4'b0000;

        #100;
        rst_n = 1;
        #50;
        enable = 1;

        // Run for ~200 PDM samples
        #200000;

        $display("=== PDM Interface test complete. %0d samples captured. ===", sample_cnt);
        $finish;
    end

endmodule

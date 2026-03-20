// =============================================================================
// Testbench: Laser Simulator
// Verifies NCO/DDS frequency output and Wishbone register interface.
// =============================================================================
`timescale 1ns / 1ps

module tb_laser_simulator;

    parameter CLK_PERIOD = 10;  // 100 MHz

    reg         clk, rst_n;
    reg  [31:0] wb_adr_i, wb_dat_i;
    wire [31:0] wb_dat_o;
    reg         wb_we_i, wb_cyc_i, wb_stb_i;
    wire        wb_ack_o;
    wire [31:0] sim_freq_hz;
    wire signed [15:0] wave_out;
    wire        sample_valid;

    laser_simulator #(
        .CLK_FREQ     (100_000_000),
        .DEFAULT_FREQ (440),
        .PHASE_WIDTH  (32),
        .OUTPUT_WIDTH (16)
    ) uut (
        .clk          (clk),
        .rst_n        (rst_n),
        .wb_adr_i     (wb_adr_i),
        .wb_dat_i     (wb_dat_i),
        .wb_dat_o     (wb_dat_o),
        .wb_we_i      (wb_we_i),
        .wb_cyc_i     (wb_cyc_i),
        .wb_stb_i     (wb_stb_i),
        .wb_ack_o     (wb_ack_o),
        .sim_freq_hz  (sim_freq_hz),
        .wave_out     (wave_out),
        .sample_valid (sample_valid)
    );

    initial clk = 1'b0;
    always #(CLK_PERIOD/2) clk = ~clk;

    // Task: single Wishbone write
    task wb_write;
        input [31:0] addr;
        input [31:0] data;
        begin
            @(posedge clk);
            wb_adr_i = addr; wb_dat_i = data;
            wb_we_i  = 1'b1; wb_cyc_i = 1'b1; wb_stb_i = 1'b1;
            @(posedge wb_ack_o);
            @(posedge clk);
            wb_cyc_i = 1'b0; wb_stb_i = 1'b0; wb_we_i = 1'b0;
        end
    endtask

    // Task: single Wishbone read
    task wb_read;
        input  [31:0] addr;
        output [31:0] data;
        begin
            @(posedge clk);
            wb_adr_i = addr;
            wb_we_i  = 1'b0; wb_cyc_i = 1'b1; wb_stb_i = 1'b1;
            @(posedge wb_ack_o);
            data = wb_dat_o;
            @(posedge clk);
            wb_cyc_i = 1'b0; wb_stb_i = 1'b0;
        end
    endtask

    reg [31:0] rd_data;
    integer i;

    initial begin
        $dumpfile("tb_laser_simulator.vcd");
        $dumpvars(0, tb_laser_simulator);

        rst_n    = 1'b0;
        wb_adr_i = 32'd0; wb_dat_i = 32'd0;
        wb_we_i  = 1'b0;  wb_cyc_i = 1'b0; wb_stb_i = 1'b0;
        #100;
        rst_n = 1'b1;
        #50;

        // ---- Test 1: Default frequency register = 440 Hz ----
        wb_read(32'h00000008, rd_data);
        if (rd_data !== 32'd440)
            $display("[FAIL] Default freq = %0d (expected 440)", rd_data);
        else
            $display("[PASS] Default freq = 440 Hz");

        // ---- Test 2: Enable the simulator ----
        wb_write(32'h00000000, 32'h00000001);  // SIM_CTRL = enable
        wb_read (32'h00000004, rd_data);        // SIM_STATUS
        if (rd_data[0] !== 1'b1)
            $display("[FAIL] Simulator not enabled");
        else
            $display("[PASS] Simulator enabled");

        // ---- Test 3: Observe sim_freq_hz output ----
        #20;
        if (sim_freq_hz !== 32'd440)
            $display("[FAIL] sim_freq_hz = %0d (expected 440)", sim_freq_hz);
        else
            $display("[PASS] sim_freq_hz = 440 Hz");

        // ---- Test 4: Change frequency to 880 Hz ----
        wb_write(32'h00000008, 32'd880);
        wb_read (32'h00000008, rd_data);
        if (rd_data !== 32'd880)
            $display("[FAIL] freq after update = %0d (expected 880)", rd_data);
        else
            $display("[PASS] Frequency updated to 880 Hz");

        // ---- Test 5: Observe wave output for a few cycles ----
        for (i = 0; i < 20; i = i + 1) begin
            @(posedge clk);
            if (i < 5)
                $display("  wave_out[%0d] = %0d", i, $signed(wave_out));
        end

        $display("[DONE] laser_simulator testbench complete.");
        #200;
        $finish;
    end

endmodule

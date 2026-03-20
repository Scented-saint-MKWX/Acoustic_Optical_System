// =============================================================================
// Testbench: AXI Memory Map
// Verifies Wishbone and AXI4-Lite read paths for the DSP output registers.
// =============================================================================
`timescale 1ns / 1ps

module tb_axi_memory_map;

    parameter CLK_PERIOD = 10;  // 100 MHz

    reg         clk, rst_n;

    // Hardware inputs
    reg signed [15:0] aoa_angle_in;
    reg        [31:0] sim_freq_hz_in;
    reg               angle_valid_in, freq_valid_in;

    // Wishbone
    reg  [31:0] wb_adr_i, wb_dat_i;
    wire [31:0] wb_dat_o;
    reg         wb_we_i, wb_cyc_i, wb_stb_i;
    wire        wb_ack_o;

    // AXI4-Lite
    reg  [31:0] s_axil_araddr;
    reg         s_axil_arvalid, s_axil_rready;
    wire        s_axil_arready;
    wire [31:0] s_axil_rdata;
    wire [ 1:0] s_axil_rresp;
    wire        s_axil_rvalid;
    reg  [31:0] s_axil_awaddr;
    reg         s_axil_awvalid, s_axil_wvalid, s_axil_bready;
    reg  [31:0] s_axil_wdata;
    reg  [ 3:0] s_axil_wstrb;
    wire        s_axil_awready, s_axil_wready, s_axil_bvalid;
    wire [ 1:0] s_axil_bresp;

    axi_memory_map uut (
        .clk              (clk),
        .rst_n            (rst_n),
        .aoa_angle_in     (aoa_angle_in),
        .sim_freq_hz_in   (sim_freq_hz_in),
        .angle_valid_in   (angle_valid_in),
        .freq_valid_in    (freq_valid_in),
        .wb_adr_i         (wb_adr_i),
        .wb_dat_i         (wb_dat_i),
        .wb_dat_o         (wb_dat_o),
        .wb_we_i          (wb_we_i),
        .wb_cyc_i         (wb_cyc_i),
        .wb_stb_i         (wb_stb_i),
        .wb_ack_o         (wb_ack_o),
        .s_axil_awaddr    (s_axil_awaddr),
        .s_axil_awvalid   (s_axil_awvalid),
        .s_axil_awready   (s_axil_awready),
        .s_axil_wdata     (s_axil_wdata),
        .s_axil_wstrb     (s_axil_wstrb),
        .s_axil_wvalid    (s_axil_wvalid),
        .s_axil_wready    (s_axil_wready),
        .s_axil_bresp     (s_axil_bresp),
        .s_axil_bvalid    (s_axil_bvalid),
        .s_axil_bready    (s_axil_bready),
        .s_axil_araddr    (s_axil_araddr),
        .s_axil_arvalid   (s_axil_arvalid),
        .s_axil_arready   (s_axil_arready),
        .s_axil_rdata     (s_axil_rdata),
        .s_axil_rresp     (s_axil_rresp),
        .s_axil_rvalid    (s_axil_rvalid),
        .s_axil_rready    (s_axil_rready)
    );

    initial clk = 1'b0;
    always #(CLK_PERIOD/2) clk = ~clk;

    // Task: Wishbone read
    task wb_read;
        input  [31:0] addr;
        output [31:0] data;
        begin
            @(posedge clk);
            wb_adr_i = addr; wb_we_i = 1'b0;
            wb_cyc_i = 1'b1; wb_stb_i = 1'b1;
            @(posedge wb_ack_o);
            data = wb_dat_o;
            @(posedge clk);
            wb_cyc_i = 1'b0; wb_stb_i = 1'b0;
        end
    endtask

    // Task: AXI4-Lite read
    task axil_read;
        input  [31:0] addr;
        output [31:0] data;
        begin
            @(posedge clk);
            s_axil_araddr  = addr;
            s_axil_arvalid = 1'b1;
            s_axil_rready  = 1'b1;
            @(posedge s_axil_rvalid);
            data = s_axil_rdata;
            @(posedge clk);
            s_axil_arvalid = 1'b0;
        end
    endtask

    reg [31:0] rd_data;

    initial begin
        $dumpfile("tb_axi_memory_map.vcd");
        $dumpvars(0, tb_axi_memory_map);

        // Init
        rst_n          = 1'b0;
        aoa_angle_in   = 16'sd0;
        sim_freq_hz_in = 32'd0;
        angle_valid_in = 1'b0;
        freq_valid_in  = 1'b0;
        wb_adr_i = 32'd0; wb_dat_i = 32'd0;
        wb_we_i = 1'b0; wb_cyc_i = 1'b0; wb_stb_i = 1'b0;
        s_axil_araddr = 32'd0; s_axil_arvalid = 1'b0; s_axil_rready = 1'b1;
        s_axil_awaddr = 32'd0; s_axil_awvalid = 1'b0; s_axil_wvalid = 1'b0;
        s_axil_wdata  = 32'd0; s_axil_wstrb   = 4'd0; s_axil_bready = 1'b1;
        #100;
        rst_n = 1'b1;
        #50;

        // ---- Test 1: Write hardware AoA and freq, read via Wishbone ----
        @(posedge clk);
        aoa_angle_in   = -16'sd279;   // −27.9° (× 10 = −279)
        sim_freq_hz_in = 32'd440;
        angle_valid_in = 1'b1;
        freq_valid_in  = 1'b1;
        @(posedge clk);
        angle_valid_in = 1'b0;
        freq_valid_in  = 1'b0;
        #20;

        wb_read(32'h00000000, rd_data);
        if ($signed(rd_data) !== -32'sd279)
            $display("[FAIL] WB AOA_ANGLE = %0d (expected -279)", $signed(rd_data));
        else
            $display("[PASS] WB AOA_ANGLE = -279 (−27.9°)");

        wb_read(32'h00000004, rd_data);
        if (rd_data !== 32'd440)
            $display("[FAIL] WB SIM_FREQ = %0d (expected 440)", rd_data);
        else
            $display("[PASS] WB SIM_FREQ = 440 Hz");

        wb_read(32'h00000008, rd_data);
        if (rd_data[1:0] !== 2'b11)
            $display("[FAIL] WB STATUS = %b (expected both valid bits set)", rd_data[1:0]);
        else
            $display("[PASS] WB STATUS bits set correctly");

        // ---- Test 2: Read via AXI4-Lite ----
        axil_read(32'h00000000, rd_data);
        if ($signed(rd_data) !== -32'sd279)
            $display("[FAIL] AXI AOA_ANGLE = %0d (expected -279)", $signed(rd_data));
        else
            $display("[PASS] AXI AOA_ANGLE = -279");

        axil_read(32'h00000004, rd_data);
        if (rd_data !== 32'd440)
            $display("[FAIL] AXI SIM_FREQ = %0d (expected 440)", rd_data);
        else
            $display("[PASS] AXI SIM_FREQ = 440 Hz");

        $display("[DONE] axi_memory_map testbench complete.");
        #500;
        $finish;
    end

endmodule

// =============================================================================
// AXI4-Lite Memory-Mapped DSP Output Register Block
// Target: Xilinx Artix-7, Nexys A7-100T
//
// Description:
//   Exposes two hardware-computed DSP outputs to the RISC-V softcore and to
//   any external AXI4-Lite master:
//     • AoA Angle  — signed integer, degrees × 10 (from aoa_estimator)
//     • Sim Freq   — unsigned Hz (from laser_simulator)
//
//   The module has two independent access interfaces that both read from the
//   same register file:
//
//   1. Wishbone Slave  — used by the RISC-V core (data bus at 0x8000_6000)
//   2. AXI4-Lite Slave — standard interface for any external AXI master
//
// Register Map (offset from base address):
//   0x00  AOA_ANGLE_REG — read-only, signed 32-bit (degrees × 10)
//   0x04  SIM_FREQ_REG  — read-only, unsigned 32-bit (Hz)
//   0x08  STATUS_REG    — read-only, bit0 = angle_valid, bit1 = freq_valid
//
// Wishbone base address: 0x8000_6000
// AXI4-Lite AWADDR / ARADDR use the same offsets.
//
// Both interfaces are read-only from the CPU perspective; the hardware
// (aoa_estimator and laser_simulator) are the sole writers.
// =============================================================================
`timescale 1ns / 1ps
`default_nettype none

module axi_memory_map (
    input  wire        clk,
    input  wire        rst_n,

    // ---- Hardware DSP inputs ----
    input  wire signed [15:0] aoa_angle_in,   // From aoa_estimator (degrees×10)
    input  wire [31:0]        sim_freq_hz_in, // From laser_simulator (Hz)
    input  wire               angle_valid_in, // Pulse when new angle is ready
    input  wire               freq_valid_in,  // Pulse when new freq is ready

    // =========================================================================
    // Wishbone Slave (for RISC-V softcore)
    // =========================================================================
    input  wire [31:0] wb_adr_i,
    input  wire [31:0] wb_dat_i,
    output reg  [31:0] wb_dat_o,
    input  wire        wb_we_i,
    input  wire        wb_cyc_i,
    input  wire        wb_stb_i,
    output reg         wb_ack_o,

    // =========================================================================
    // AXI4-Lite Slave Interface
    // =========================================================================
    // --- Write address channel ---
    input  wire [31:0] s_axil_awaddr,
    input  wire        s_axil_awvalid,
    output wire        s_axil_awready,

    // --- Write data channel ---
    input  wire [31:0] s_axil_wdata,
    input  wire [ 3:0] s_axil_wstrb,
    input  wire        s_axil_wvalid,
    output wire        s_axil_wready,

    // --- Write response channel ---
    output wire [ 1:0] s_axil_bresp,
    output wire        s_axil_bvalid,
    input  wire        s_axil_bready,

    // --- Read address channel ---
    input  wire [31:0] s_axil_araddr,
    input  wire        s_axil_arvalid,
    output wire        s_axil_arready,

    // --- Read data channel ---
    output reg  [31:0] s_axil_rdata,
    output wire [ 1:0] s_axil_rresp,
    output wire        s_axil_rvalid,
    input  wire        s_axil_rready
);

    // =========================================================================
    // Internal register file
    // =========================================================================
    reg signed [31:0] reg_aoa_angle;   // 0x00
    reg        [31:0] reg_sim_freq;    // 0x04
    reg        [ 1:0] reg_status;      // 0x08  bit0=angle_valid, bit1=freq_valid

    // Latch hardware inputs
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            reg_aoa_angle <= 32'sd0;
            reg_sim_freq  <= 32'd0;
            reg_status    <= 2'b00;
        end else begin
            if (angle_valid_in) begin
                reg_aoa_angle <= {{16{aoa_angle_in[15]}}, aoa_angle_in};
                reg_status[0] <= 1'b1;
            end
            if (freq_valid_in) begin
                reg_sim_freq  <= sim_freq_hz_in;
                reg_status[1] <= 1'b1;
            end
        end
    end

    // Internal read helper
    function [31:0] do_read;
        input [3:0] offset_word;  // word-aligned offset (addr[3:2])
        case (offset_word)
            4'd0:    do_read = reg_aoa_angle;         // AOA_ANGLE_REG
            4'd1:    do_read = reg_sim_freq;           // SIM_FREQ_REG
            4'd2:    do_read = {30'd0, reg_status};   // STATUS_REG
            default: do_read = 32'd0;
        endcase
    endfunction

    // =========================================================================
    // Wishbone Slave logic
    // =========================================================================
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            wb_ack_o <= 1'b0;
            wb_dat_o <= 32'd0;
        end else begin
            wb_ack_o <= 1'b0;
            if (wb_cyc_i && wb_stb_i && !wb_ack_o) begin
                wb_ack_o <= 1'b1;
                if (!wb_we_i)
                    wb_dat_o <= do_read(wb_adr_i[3:2]);
                // All registers are read-only; writes are silently ignored
            end
        end
    end

    // =========================================================================
    // AXI4-Lite Slave logic
    // =========================================================================
    // Read path: single-cycle ARVALID→RVALID handshake
    reg axil_rvalid_r;
    reg [31:0] axil_rdata_r;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            axil_rvalid_r <= 1'b0;
            axil_rdata_r  <= 32'd0;
            s_axil_rdata  <= 32'd0;
        end else begin
            if (axil_rvalid_r && s_axil_rready)
                axil_rvalid_r <= 1'b0;

            if (s_axil_arvalid && !axil_rvalid_r) begin
                s_axil_rdata  <= do_read(s_axil_araddr[3:2]);
                axil_rvalid_r <= 1'b1;
            end
        end
    end

    // Write path: registers are read-only; accept writes with OKAY response
    // but discard the data.
    reg axil_bvalid_r;
    reg axil_aw_accepted, axil_w_accepted;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            axil_bvalid_r    <= 1'b0;
            axil_aw_accepted <= 1'b0;
            axil_w_accepted  <= 1'b0;
        end else begin
            // Latch each channel only on a valid handshake (valid & ready),
            // preventing a previous accepted flag from being re-latched while
            // the response channel is still busy.
            if (s_axil_awvalid && s_axil_awready) axil_aw_accepted <= 1'b1;
            if (s_axil_wvalid  && s_axil_wready)  axil_w_accepted  <= 1'b1;

            if (axil_aw_accepted && axil_w_accepted) begin
                axil_bvalid_r    <= 1'b1;
                axil_aw_accepted <= 1'b0;
                axil_w_accepted  <= 1'b0;
            end

            if (axil_bvalid_r && s_axil_bready)
                axil_bvalid_r <= 1'b0;
        end
    end

    // AXI4-Lite tie-offs
    assign s_axil_awready = !axil_aw_accepted && !axil_bvalid_r;
    assign s_axil_wready  = !axil_w_accepted  && !axil_bvalid_r;
    assign s_axil_bresp   = 2'b00;           // OKAY
    assign s_axil_bvalid  = axil_bvalid_r;
    assign s_axil_arready = !axil_rvalid_r;
    assign s_axil_rresp   = 2'b00;           // OKAY
    assign s_axil_rvalid  = axil_rvalid_r;

endmodule
`default_nettype wire

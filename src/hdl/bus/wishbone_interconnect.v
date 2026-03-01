// =============================================================================
// Wishbone B4 Interconnect (1 Master → N Slaves)
// Description: Simple address-decode crossbar for the RISC-V data bus.
//              Routes requests to slaves based on upper address bits.
// =============================================================================
`timescale 1ns / 1ps
`default_nettype none

module wishbone_interconnect (
    input  wire        clk,
    input  wire        rst_n,

    // ------ Master Port (from RISC-V data bus) ------
    input  wire [31:0] m_adr_i,
    input  wire [31:0] m_dat_i,
    output reg  [31:0] m_dat_o,
    input  wire [ 3:0] m_sel_i,
    input  wire        m_we_i,
    input  wire        m_cyc_i,
    input  wire        m_stb_i,
    output reg         m_ack_o,

    // ------ Slave 0: Block RAM (0x0000_0000 – 0x0000_1FFF) ------
    output wire [31:0] s0_adr_o,
    output wire [31:0] s0_dat_o,
    input  wire [31:0] s0_dat_i,
    output wire [ 3:0] s0_sel_o,
    output wire        s0_we_o,
    output wire        s0_cyc_o,
    output wire        s0_stb_o,
    input  wire        s0_ack_i,

    // ------ Slave 1: GPIO (0x8000_0000) ------
    output wire [31:0] s1_adr_o,
    output wire [31:0] s1_dat_o,
    input  wire [31:0] s1_dat_i,
    output wire        s1_we_o,
    output wire        s1_cyc_o,
    output wire        s1_stb_o,
    input  wire        s1_ack_i,

    // ------ Slave 2: UART TX (0x8000_1000) ------
    output wire [31:0] s2_adr_o,
    output wire [31:0] s2_dat_o,
    input  wire [31:0] s2_dat_i,
    output wire        s2_we_o,
    output wire        s2_cyc_o,
    output wire        s2_stb_o,
    input  wire        s2_ack_i,

    // ------ Slave 3: UART RX (0x8000_2000) ------
    output wire [31:0] s3_adr_o,
    output wire [31:0] s3_dat_o,
    input  wire [31:0] s3_dat_i,
    output wire        s3_we_o,
    output wire        s3_cyc_o,
    output wire        s3_stb_o,
    input  wire        s3_ack_i,

    // ------ Slave 4: Beamformer (0x8000_3000) ------
    output wire [31:0] s4_adr_o,
    output wire [31:0] s4_dat_o,
    input  wire [31:0] s4_dat_i,
    output wire        s4_we_o,
    output wire        s4_cyc_o,
    output wire        s4_stb_o,
    input  wire        s4_ack_i,

    // ------ Slave 5: FFT Engine (0x8000_4000) ------
    output wire [31:0] s5_adr_o,
    output wire [31:0] s5_dat_o,
    input  wire [31:0] s5_dat_i,
    output wire        s5_we_o,
    output wire        s5_cyc_o,
    output wire        s5_stb_o,
    input  wire        s5_ack_i,

    // ------ Slave 6: Laser Vibrometer (0x8000_5000) ------
    output wire [31:0] s6_adr_o,
    output wire [31:0] s6_dat_o,
    input  wire [31:0] s6_dat_i,
    output wire        s6_we_o,
    output wire        s6_cyc_o,
    output wire        s6_stb_o,
    input  wire        s6_ack_i
);

    // =========================================================================
    // Address Decode
    // =========================================================================
    localparam NUM_SLAVES = 7;

    wire [NUM_SLAVES-1:0] slave_sel;

    // Memory map:
    //   0x0000_0000 – 0x7FFF_FFFF : Slave 0 (RAM)
    //   0x8000_0xxx                : Slave 1 (GPIO)
    //   0x8000_1xxx                : Slave 2 (UART TX)
    //   0x8000_2xxx                : Slave 3 (UART RX)
    //   0x8000_3xxx                : Slave 4 (Beamformer)
    //   0x8000_4xxx                : Slave 5 (FFT)
    //   0x8000_5xxx                : Slave 6 (Laser)

    assign slave_sel[0] = (m_adr_i[31] == 1'b0);
    assign slave_sel[1] = (m_adr_i[31] == 1'b1) && (m_adr_i[15:12] == 4'h0);
    assign slave_sel[2] = (m_adr_i[31] == 1'b1) && (m_adr_i[15:12] == 4'h1);
    assign slave_sel[3] = (m_adr_i[31] == 1'b1) && (m_adr_i[15:12] == 4'h2);
    assign slave_sel[4] = (m_adr_i[31] == 1'b1) && (m_adr_i[15:12] == 4'h3);
    assign slave_sel[5] = (m_adr_i[31] == 1'b1) && (m_adr_i[15:12] == 4'h4);
    assign slave_sel[6] = (m_adr_i[31] == 1'b1) && (m_adr_i[15:12] == 4'h5);

    // =========================================================================
    // Pass-through signals (address, data, control)
    // =========================================================================
    // Common outputs to all slaves
    assign s0_adr_o = m_adr_i;  assign s0_dat_o = m_dat_i;  assign s0_sel_o = m_sel_i;
    assign s1_adr_o = m_adr_i;  assign s1_dat_o = m_dat_i;
    assign s2_adr_o = m_adr_i;  assign s2_dat_o = m_dat_i;
    assign s3_adr_o = m_adr_i;  assign s3_dat_o = m_dat_i;
    assign s4_adr_o = m_adr_i;  assign s4_dat_o = m_dat_i;
    assign s5_adr_o = m_adr_i;  assign s5_dat_o = m_dat_i;
    assign s6_adr_o = m_adr_i;  assign s6_dat_o = m_dat_i;

    assign s0_we_o = m_we_i;  assign s1_we_o = m_we_i;  assign s2_we_o = m_we_i;
    assign s3_we_o = m_we_i;  assign s4_we_o = m_we_i;  assign s5_we_o = m_we_i;
    assign s6_we_o = m_we_i;

    // Cycle/strobe gated by address decode
    assign s0_cyc_o = m_cyc_i & slave_sel[0];  assign s0_stb_o = m_stb_i & slave_sel[0];
    assign s1_cyc_o = m_cyc_i & slave_sel[1];  assign s1_stb_o = m_stb_i & slave_sel[1];
    assign s2_cyc_o = m_cyc_i & slave_sel[2];  assign s2_stb_o = m_stb_i & slave_sel[2];
    assign s3_cyc_o = m_cyc_i & slave_sel[3];  assign s3_stb_o = m_stb_i & slave_sel[3];
    assign s4_cyc_o = m_cyc_i & slave_sel[4];  assign s4_stb_o = m_stb_i & slave_sel[4];
    assign s5_cyc_o = m_cyc_i & slave_sel[5];  assign s5_stb_o = m_stb_i & slave_sel[5];
    assign s6_cyc_o = m_cyc_i & slave_sel[6];  assign s6_stb_o = m_stb_i & slave_sel[6];

    // =========================================================================
    // Return mux (data + ack back to master)
    // =========================================================================
    always @(*) begin
        m_dat_o = 32'd0;
        m_ack_o = 1'b0;
        case (1'b1)
            slave_sel[0]: begin m_dat_o = s0_dat_i; m_ack_o = s0_ack_i; end
            slave_sel[1]: begin m_dat_o = s1_dat_i; m_ack_o = s1_ack_i; end
            slave_sel[2]: begin m_dat_o = s2_dat_i; m_ack_o = s2_ack_i; end
            slave_sel[3]: begin m_dat_o = s3_dat_i; m_ack_o = s3_ack_i; end
            slave_sel[4]: begin m_dat_o = s4_dat_i; m_ack_o = s4_ack_i; end
            slave_sel[5]: begin m_dat_o = s5_dat_i; m_ack_o = s5_ack_i; end
            slave_sel[6]: begin m_dat_o = s6_dat_i; m_ack_o = s6_ack_i; end
            default:      begin m_dat_o = 32'd0;    m_ack_o = 1'b0;     end
        endcase
    end

endmodule
`default_nettype wire

// =============================================================================
// Block RAM with Wishbone Interface
// Description: Dual-port Block RAM for instruction and data memory.
//              8 KB default (2048 x 32-bit words).
// =============================================================================
`timescale 1ns / 1ps
`default_nettype none

module block_ram #(
    parameter DEPTH     = 2048,   // Number of 32-bit words
    parameter INIT_FILE = ""      // Optional hex init file
)(
    input  wire        clk,

    // Port A – Instruction Fetch (read-only)
    input  wire [31:0] a_adr_i,
    output reg  [31:0] a_dat_o,
    input  wire        a_cyc_i,
    input  wire        a_stb_i,
    output reg         a_ack_o,

    // Port B – Data Access (read/write)
    input  wire [31:0] b_adr_i,
    input  wire [31:0] b_dat_i,
    output reg  [31:0] b_dat_o,
    input  wire [ 3:0] b_sel_i,
    input  wire        b_we_i,
    input  wire        b_cyc_i,
    input  wire        b_stb_i,
    output reg         b_ack_o
);

    localparam AW = $clog2(DEPTH);

    // Storage
    reg [31:0] mem [0:DEPTH-1];

    // Address alignment – word-aligned (drop bottom 2 bits)
    wire [AW-1:0] addr_a = a_adr_i[AW+1:2];
    wire [AW-1:0] addr_b = b_adr_i[AW+1:2];

    // Initialisation
    initial begin
        integer i;
        for (i = 0; i < DEPTH; i = i + 1)
            mem[i] = 32'h0000_0013; // NOP
        if (INIT_FILE != "")
            $readmemh(INIT_FILE, mem);
    end

    // Port A – Instruction
    always @(posedge clk) begin
        a_ack_o <= 1'b0;
        if (a_cyc_i && a_stb_i && !a_ack_o) begin
            a_dat_o <= mem[addr_a];
            a_ack_o <= 1'b1;
        end
    end

    // Port B – Data
    always @(posedge clk) begin
        b_ack_o <= 1'b0;
        if (b_cyc_i && b_stb_i && !b_ack_o) begin
            if (b_we_i) begin
                if (b_sel_i[0]) mem[addr_b][ 7: 0] <= b_dat_i[ 7: 0];
                if (b_sel_i[1]) mem[addr_b][15: 8] <= b_dat_i[15: 8];
                if (b_sel_i[2]) mem[addr_b][23:16] <= b_dat_i[23:16];
                if (b_sel_i[3]) mem[addr_b][31:24] <= b_dat_i[31:24];
            end else begin
                b_dat_o <= mem[addr_b];
            end
            b_ack_o <= 1'b1;
        end
    end

endmodule
`default_nettype wire

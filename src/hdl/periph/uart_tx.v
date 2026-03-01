// =============================================================================
// UART Transmitter (Wishbone Slave)
// Description: 8N1 UART TX with configurable baud rate.
//              Default: 115200 baud @ 100 MHz clock.
// =============================================================================
`timescale 1ns / 1ps
`default_nettype none

module uart_tx #(
    parameter CLK_FREQ  = 100_000_000,
    parameter BAUD_RATE = 115_200
)(
    input  wire        clk,
    input  wire        rst_n,

    // Wishbone Slave
    input  wire [31:0] wb_adr_i,
    input  wire [31:0] wb_dat_i,
    output reg  [31:0] wb_dat_o,
    input  wire        wb_we_i,
    input  wire        wb_cyc_i,
    input  wire        wb_stb_i,
    output reg         wb_ack_o,

    // UART pin
    output reg         tx
);

    localparam BAUD_DIV = CLK_FREQ / BAUD_RATE;

    reg [15:0] baud_cnt;
    reg [ 3:0] bit_idx;
    reg [ 9:0] shift_reg;  // start + 8 data + stop
    reg        busy;

    // Wishbone interface
    // 0x00: TX Data [W] – write byte to transmit
    // 0x04: Status  [R] – bit0: busy

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            wb_ack_o  <= 1'b0;
            wb_dat_o  <= 32'd0;
            tx        <= 1'b1;  // Idle high
            busy      <= 1'b0;
            baud_cnt  <= 0;
            bit_idx   <= 0;
            shift_reg <= 10'h3FF;
        end else begin
            wb_ack_o <= 1'b0;

            // Transmission logic
            if (busy) begin
                if (baud_cnt == BAUD_DIV - 1) begin
                    baud_cnt <= 0;
                    if (bit_idx == 10) begin
                        busy <= 1'b0;
                        tx   <= 1'b1;
                    end else begin
                        tx        <= shift_reg[0];
                        shift_reg <= {1'b1, shift_reg[9:1]};
                        bit_idx   <= bit_idx + 1;
                    end
                end else begin
                    baud_cnt <= baud_cnt + 1;
                end
            end

            // Wishbone access
            if (wb_cyc_i && wb_stb_i && !wb_ack_o) begin
                wb_ack_o <= 1'b1;
                if (wb_we_i && wb_adr_i[2] == 1'b0) begin
                    // Start TX
                    if (!busy) begin
                        shift_reg <= {1'b1, wb_dat_i[7:0], 1'b0}; // stop, data, start
                        busy      <= 1'b1;
                        bit_idx   <= 0;
                        baud_cnt  <= 0;
                    end
                end else if (!wb_we_i) begin
                    case (wb_adr_i[2])
                        1'b0: wb_dat_o <= 32'd0;
                        1'b1: wb_dat_o <= {31'd0, busy};
                    endcase
                end
            end
        end
    end

endmodule
`default_nettype wire

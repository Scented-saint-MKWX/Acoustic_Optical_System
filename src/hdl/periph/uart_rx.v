// =============================================================================
// UART Receiver (Wishbone Slave)
// Description: 8N1 UART RX with configurable baud rate.
//              Includes 8-byte FIFO.
// =============================================================================
`timescale 1ns / 1ps
`default_nettype none

module uart_rx #(
    parameter CLK_FREQ  = 100_000_000,
    parameter BAUD_RATE = 115_200,
    parameter FIFO_DEPTH = 8
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
    input  wire        rx,

    // Interrupt
    output reg         rx_irq
);

    localparam BAUD_DIV  = CLK_FREQ / BAUD_RATE;
    localparam HALF_BAUD = BAUD_DIV / 2;

    // RX state machine
    localparam RX_IDLE  = 2'd0,
               RX_START = 2'd1,
               RX_DATA  = 2'd2,
               RX_STOP  = 2'd3;

    reg [1:0]  rx_state;
    reg [15:0] baud_cnt;
    reg [2:0]  bit_idx;
    reg [7:0]  rx_shift;
    reg        rx_sync1, rx_sync2;  // Double-flop synchronizer

    // FIFO
    reg [7:0]  fifo [0:FIFO_DEPTH-1];
    reg [$clog2(FIFO_DEPTH):0] fifo_wr, fifo_rd, fifo_count;

    // Synchronize RX input
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            rx_sync1 <= 1'b1;
            rx_sync2 <= 1'b1;
        end else begin
            rx_sync1 <= rx;
            rx_sync2 <= rx_sync1;
        end
    end

    // RX state machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            rx_state  <= RX_IDLE;
            baud_cnt  <= 0;
            bit_idx   <= 0;
            rx_shift  <= 0;
            fifo_wr   <= 0;
            fifo_count <= 0;
            rx_irq    <= 1'b0;
        end else begin
            rx_irq <= 1'b0;

            case (rx_state)
                RX_IDLE: begin
                    if (!rx_sync2) begin  // Start bit detected
                        baud_cnt <= 0;
                        rx_state <= RX_START;
                    end
                end

                RX_START: begin
                    if (baud_cnt == HALF_BAUD - 1) begin
                        // Sample at middle of start bit
                        if (!rx_sync2) begin
                            baud_cnt <= 0;
                            bit_idx  <= 0;
                            rx_state <= RX_DATA;
                        end else begin
                            rx_state <= RX_IDLE; // False start
                        end
                    end else begin
                        baud_cnt <= baud_cnt + 1;
                    end
                end

                RX_DATA: begin
                    if (baud_cnt == BAUD_DIV - 1) begin
                        baud_cnt <= 0;
                        rx_shift <= {rx_sync2, rx_shift[7:1]};
                        if (bit_idx == 7) begin
                            rx_state <= RX_STOP;
                        end else begin
                            bit_idx <= bit_idx + 1;
                        end
                    end else begin
                        baud_cnt <= baud_cnt + 1;
                    end
                end

                RX_STOP: begin
                    if (baud_cnt == BAUD_DIV - 1) begin
                        if (rx_sync2) begin  // Valid stop bit
                            if (fifo_count < FIFO_DEPTH) begin
                                fifo[fifo_wr[$clog2(FIFO_DEPTH)-1:0]] <= rx_shift;
                                fifo_wr    <= fifo_wr + 1;
                                fifo_count <= fifo_count + 1;
                                rx_irq     <= 1'b1;
                            end
                        end
                        rx_state <= RX_IDLE;
                    end else begin
                        baud_cnt <= baud_cnt + 1;
                    end
                end
            endcase
        end
    end

    // -------------------------------------------------------------------------
    // Wishbone Interface
    // -------------------------------------------------------------------------
    // 0x00: RX Data  [R] – read byte from FIFO (auto-pops)
    // 0x04: Status   [R] – bit0: data available, [7:4]: count

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            wb_ack_o <= 1'b0;
            wb_dat_o <= 32'd0;
            fifo_rd  <= 0;
        end else begin
            wb_ack_o <= 1'b0;
            if (wb_cyc_i && wb_stb_i && !wb_ack_o) begin
                wb_ack_o <= 1'b1;
                if (!wb_we_i) begin
                    case (wb_adr_i[2])
                        1'b0: begin
                            // Read data + pop
                            if (fifo_count > 0) begin
                                wb_dat_o   <= {24'd0, fifo[fifo_rd[$clog2(FIFO_DEPTH)-1:0]]};
                                fifo_rd    <= fifo_rd + 1;
                                fifo_count <= fifo_count - 1;
                            end else begin
                                wb_dat_o <= 32'd0;
                            end
                        end
                        1'b1: wb_dat_o <= {24'd0, fifo_count[3:0], 3'd0, (fifo_count > 0)};
                    endcase
                end
            end
        end
    end

endmodule
`default_nettype wire

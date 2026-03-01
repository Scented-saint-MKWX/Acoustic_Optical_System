// =============================================================================
// SPI Master
// Description: Configurable SPI master with variable clock divider.
//              Supports CPOL/CPHA modes. Used for ADC communication.
// =============================================================================
`timescale 1ns / 1ps
`default_nettype none

module spi_master #(
    parameter WIDTH   = 16,
    parameter CPOL    = 0,
    parameter CPHA    = 0,
    parameter CLK_DIV = 8    // sclk = clk / (2 * CLK_DIV)
)(
    input  wire              clk,
    input  wire              rst_n,

    // Control
    input  wire              start,
    input  wire [WIDTH-1:0]  tx_data,
    output reg  [WIDTH-1:0]  rx_data,
    output reg               done,

    // SPI bus
    output reg               sclk,
    output reg               cs_n,
    output reg               mosi,
    input  wire              miso
);

    localparam CNT_W = $clog2(CLK_DIV);

    reg [CNT_W-1:0] clk_cnt;
    reg [$clog2(WIDTH):0] bit_cnt;
    reg [WIDTH-1:0] shift_tx;
    reg [WIDTH-1:0] shift_rx;
    reg running;
    reg sclk_edge;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            sclk     <= CPOL;
            cs_n     <= 1'b1;
            mosi     <= 1'b0;
            rx_data  <= 0;
            done     <= 1'b0;
            running  <= 1'b0;
            clk_cnt  <= 0;
            bit_cnt  <= 0;
            shift_tx <= 0;
            shift_rx <= 0;
        end else begin
            done <= 1'b0;

            if (!running) begin
                if (start) begin
                    running  <= 1'b1;
                    cs_n     <= 1'b0;
                    shift_tx <= tx_data;
                    shift_rx <= 0;
                    bit_cnt  <= 0;
                    clk_cnt  <= 0;
                    sclk     <= CPOL;
                    mosi     <= tx_data[WIDTH-1];  // MSB first
                end
            end else begin
                if (clk_cnt == CLK_DIV - 1) begin
                    clk_cnt <= 0;
                    sclk    <= ~sclk;

                    // Sample on appropriate edge based on CPHA
                    if ((CPHA == 0 && sclk != CPOL) || (CPHA == 1 && sclk == CPOL)) begin
                        // Sampling edge
                        shift_rx <= {shift_rx[WIDTH-2:0], miso};
                    end else begin
                        // Shifting edge
                        if (bit_cnt == WIDTH) begin
                            // Transfer complete
                            running <= 1'b0;
                            cs_n    <= 1'b1;
                            sclk    <= CPOL;
                            rx_data <= {shift_rx[WIDTH-2:0], miso};
                            done    <= 1'b1;
                        end else begin
                            shift_tx <= {shift_tx[WIDTH-2:0], 1'b0};
                            mosi     <= shift_tx[WIDTH-2];
                            bit_cnt  <= bit_cnt + 1;
                        end
                    end
                end else begin
                    clk_cnt <= clk_cnt + 1;
                end
            end
        end
    end

endmodule
`default_nettype wire

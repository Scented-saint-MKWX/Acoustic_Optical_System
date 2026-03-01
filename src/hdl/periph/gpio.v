// =============================================================================
// GPIO Module (Wishbone Slave)
// Description: 16-bit bidirectional GPIO with direction register.
//              Used for LEDs, switches, and general I/O on Nexys A7.
// =============================================================================
`timescale 1ns / 1ps
`default_nettype none

module gpio #(
    parameter WIDTH = 16
)(
    input  wire              clk,
    input  wire              rst_n,

    // Wishbone Slave
    input  wire [31:0]       wb_adr_i,
    input  wire [31:0]       wb_dat_i,
    output reg  [31:0]       wb_dat_o,
    input  wire              wb_we_i,
    input  wire              wb_cyc_i,
    input  wire              wb_stb_i,
    output reg               wb_ack_o,

    // GPIO pins
    input  wire [WIDTH-1:0]  gpio_in,
    output reg  [WIDTH-1:0]  gpio_out,
    output reg  [WIDTH-1:0]  gpio_dir   // 1 = output, 0 = input
);

    // Register map:
    // 0x00: Data Out   [R/W]
    // 0x04: Direction  [R/W]  (1=output)
    // 0x08: Data In    [R]

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            wb_ack_o <= 1'b0;
            wb_dat_o <= 32'd0;
            gpio_out <= {WIDTH{1'b0}};
            gpio_dir <= {WIDTH{1'b0}};  // All inputs by default
        end else begin
            wb_ack_o <= 1'b0;
            if (wb_cyc_i && wb_stb_i && !wb_ack_o) begin
                wb_ack_o <= 1'b1;
                if (wb_we_i) begin
                    case (wb_adr_i[3:2])
                        2'd0: gpio_out <= wb_dat_i[WIDTH-1:0];
                        2'd1: gpio_dir <= wb_dat_i[WIDTH-1:0];
                        default: ;
                    endcase
                end else begin
                    case (wb_adr_i[3:2])
                        2'd0: wb_dat_o <= {{(32-WIDTH){1'b0}}, gpio_out};
                        2'd1: wb_dat_o <= {{(32-WIDTH){1'b0}}, gpio_dir};
                        2'd2: wb_dat_o <= {{(32-WIDTH){1'b0}}, gpio_in};
                        default: wb_dat_o <= 32'd0;
                    endcase
                end
            end
        end
    end

endmodule
`default_nettype wire

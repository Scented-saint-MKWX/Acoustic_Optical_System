// =============================================================================
// PDM (Pulse-Density Modulation) Interface
// Description: Generates the PDM clock and captures 1-bit PDM data from up to
//              4 MEMS microphones (e.g., Knowles SPH0645LM4H).
//              PDM_CLK output ≈ 3.072 MHz (from 100 MHz sys_clk / 32).
// =============================================================================
`timescale 1ns / 1ps
`default_nettype none

module pdm_interface #(
    parameter NUM_MICS   = 4,
    parameter CLK_DIV    = 32     // 100 MHz / 32 ≈ 3.125 MHz PDM clock
)(
    input  wire                    clk,          // 100 MHz system clock
    input  wire                    rst_n,
    input  wire                    enable,

    // PDM physical pins
    output reg                     pdm_clk,      // clock to microphones
    input  wire [NUM_MICS-1:0]     pdm_data,     // 1-bit PDM streams

    // Output: one-bit samples, active for one sys_clk cycle per PDM edge
    output reg  [NUM_MICS-1:0]     sample_out,
    output reg                     sample_valid
);

    // Clock divider
    reg [$clog2(CLK_DIV)-1:0] clk_cnt;
    reg                        pdm_clk_prev;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            clk_cnt      <= 0;
            pdm_clk      <= 1'b0;
            pdm_clk_prev <= 1'b0;
            sample_out   <= {NUM_MICS{1'b0}};
            sample_valid <= 1'b0;
        end else if (enable) begin
            pdm_clk_prev <= pdm_clk;
            sample_valid <= 1'b0;

            if (clk_cnt == (CLK_DIV/2 - 1)) begin
                clk_cnt <= 0;
                pdm_clk <= ~pdm_clk;

                // Capture on rising edge of PDM clock
                if (!pdm_clk) begin
                    sample_out   <= pdm_data;
                    sample_valid <= 1'b1;
                end
            end else begin
                clk_cnt <= clk_cnt + 1;
            end
        end else begin
            clk_cnt      <= 0;
            pdm_clk      <= 1'b0;
            sample_valid <= 1'b0;
        end
    end

endmodule
`default_nettype wire

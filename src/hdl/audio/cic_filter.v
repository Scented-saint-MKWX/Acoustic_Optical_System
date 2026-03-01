// =============================================================================
// CIC Decimation Filter (Cascaded Integrator-Comb)
// Description: 4th-order CIC filter that converts the 1-bit PDM stream into
//              a multi-bit PCM signal. Decimation ratio R configurable.
//              Output width = 1 + N*log2(R) bits (N=order, R=decimation).
//              For R=64, N=4: output is 1+4*6 = 25 bits → truncated to 16.
// =============================================================================
`timescale 1ns / 1ps
`default_nettype none

module cic_filter #(
    parameter ORDER     = 4,       // CIC filter order (number of stages)
    parameter DEC_RATIO = 64,      // Decimation ratio
    parameter INP_WIDTH = 1,       // 1-bit PDM input
    parameter ACC_WIDTH = 36,      // Internal accumulator width (generous)
    parameter OUT_WIDTH = 16       // Truncated output width
)(
    input  wire                    clk,
    input  wire                    rst_n,
    input  wire                    sample_valid,  // One pulse per PDM sample
    input  wire [INP_WIDTH-1:0]    data_in,       // PDM bit (0 or 1)

    output reg  [OUT_WIDTH-1:0]    data_out,
    output reg                     data_valid     // Pulse when new output ready
);

    // -------------------------------------------------------------------------
    // Integrator stages (run at PDM sample rate)
    // -------------------------------------------------------------------------
    reg signed [ACC_WIDTH-1:0] integrator [0:ORDER-1];

    // Sign-extend 1-bit PDM: 0 → -1, 1 → +1
    wire signed [ACC_WIDTH-1:0] pdm_signed = data_in ? {{(ACC_WIDTH-1){1'b0}}, 1'b1}
                                                      : {ACC_WIDTH{1'b1}};  // -1

    integer i;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            for (i = 0; i < ORDER; i = i + 1)
                integrator[i] <= 0;
        end else if (sample_valid) begin
            integrator[0] <= integrator[0] + pdm_signed;
            for (i = 1; i < ORDER; i = i + 1)
                integrator[i] <= integrator[i] + integrator[i-1];
        end
    end

    // -------------------------------------------------------------------------
    // Decimation counter
    // -------------------------------------------------------------------------
    reg [$clog2(DEC_RATIO)-1:0] dec_cnt;
    reg                          dec_tick;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            dec_cnt  <= 0;
            dec_tick <= 1'b0;
        end else begin
            dec_tick <= 1'b0;
            if (sample_valid) begin
                if (dec_cnt == DEC_RATIO - 1) begin
                    dec_cnt  <= 0;
                    dec_tick <= 1'b1;
                end else begin
                    dec_cnt <= dec_cnt + 1;
                end
            end
        end
    end

    // -------------------------------------------------------------------------
    // Comb stages (run at decimated rate)
    // -------------------------------------------------------------------------
    reg signed [ACC_WIDTH-1:0] comb      [0:ORDER-1];
    reg signed [ACC_WIDTH-1:0] comb_prev [0:ORDER-1];

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            for (i = 0; i < ORDER; i = i + 1) begin
                comb[i]      <= 0;
                comb_prev[i] <= 0;
            end
            data_out   <= 0;
            data_valid <= 1'b0;
        end else begin
            data_valid <= 1'b0;
            if (dec_tick) begin
                // First comb takes integrator output
                comb[0]      <= integrator[ORDER-1] - comb_prev[0];
                comb_prev[0] <= integrator[ORDER-1];

                // Subsequent comb stages
                for (i = 1; i < ORDER; i = i + 1) begin
                    comb[i]      <= comb[i-1] - comb_prev[i];
                    comb_prev[i] <= comb[i-1];
                end

                // Output: truncate MSBs to OUT_WIDTH
                data_out   <= comb[ORDER-1][ACC_WIDTH-1 -: OUT_WIDTH];
                data_valid <= 1'b1;
            end
        end
    end

endmodule
`default_nettype wire

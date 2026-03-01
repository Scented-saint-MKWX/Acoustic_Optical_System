// =============================================================================
// Delay-and-Sum Beamformer
// Description: Implements a time-domain delay-and-sum beamformer for a
//              4-element linear microphone array. Delays are programmed by
//              the RISC-V core via a Wishbone register interface.
//              Each channel has a configurable sample delay (0–31 taps).
// =============================================================================
`timescale 1ns / 1ps
`default_nettype none

module beamformer #(
    parameter NUM_CHANNELS = 4,
    parameter DATA_WIDTH   = 16,
    parameter MAX_DELAY    = 32,   // Max delay taps per channel
    parameter OUT_WIDTH    = 18    // Output width (log2(NUM_CH) extra bits)
)(
    input  wire                              clk,
    input  wire                              rst_n,

    // PCM input from CIC filters
    input  wire [NUM_CHANNELS*DATA_WIDTH-1:0] pcm_in,
    input  wire                              pcm_valid,

    // Delay configuration (Wishbone slave)
    input  wire [31:0]                       wb_adr_i,
    input  wire [31:0]                       wb_dat_i,
    input  wire                              wb_we_i,
    input  wire                              wb_cyc_i,
    input  wire                              wb_stb_i,
    output reg                               wb_ack_o,

    // Beamformed output
    output reg  signed [OUT_WIDTH-1:0]       beam_out,
    output reg                               beam_valid
);

    // -------------------------------------------------------------------------
    // Delay registers (set by CPU)
    // -------------------------------------------------------------------------
    reg [4:0] delay_taps [0:NUM_CHANNELS-1];

    // Wishbone config interface
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            wb_ack_o <= 1'b0;
            delay_taps[0] <= 5'd0;
            delay_taps[1] <= 5'd0;
            delay_taps[2] <= 5'd0;
            delay_taps[3] <= 5'd0;
        end else begin
            wb_ack_o <= 1'b0;
            if (wb_cyc_i && wb_stb_i && !wb_ack_o) begin
                wb_ack_o <= 1'b1;
                if (wb_we_i) begin
                    if (wb_adr_i[3:2] < NUM_CHANNELS)
                        delay_taps[wb_adr_i[3:2]] <= wb_dat_i[4:0];
                end
            end
        end
    end

    // -------------------------------------------------------------------------
    // Delay lines (circular buffers)
    // -------------------------------------------------------------------------
    reg signed [DATA_WIDTH-1:0] delay_mem [0:NUM_CHANNELS-1][0:MAX_DELAY-1];
    reg [$clog2(MAX_DELAY)-1:0] wr_ptr;

    integer ch, d;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            wr_ptr <= 0;
            for (ch = 0; ch < NUM_CHANNELS; ch = ch + 1)
                for (d = 0; d < MAX_DELAY; d = d + 1)
                    delay_mem[ch][d] <= 0;
        end else if (pcm_valid) begin
            for (ch = 0; ch < NUM_CHANNELS; ch = ch + 1)
                delay_mem[ch][wr_ptr] <= pcm_in[ch*DATA_WIDTH +: DATA_WIDTH];
            wr_ptr <= wr_ptr + 1;
        end
    end

    // -------------------------------------------------------------------------
    // Sum delayed outputs
    // -------------------------------------------------------------------------
    reg signed [OUT_WIDTH-1:0] sum;
    wire [$clog2(MAX_DELAY)-1:0] rd_ptr [0:NUM_CHANNELS-1];

    genvar g;
    generate
        for (g = 0; g < NUM_CHANNELS; g = g + 1) begin : gen_rd_ptr
            assign rd_ptr[g] = wr_ptr - delay_taps[g] - 1;
        end
    endgenerate

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            beam_out   <= 0;
            beam_valid <= 1'b0;
        end else begin
            beam_valid <= 1'b0;
            if (pcm_valid) begin
                sum = 0;
                for (ch = 0; ch < NUM_CHANNELS; ch = ch + 1)
                    sum = sum + delay_mem[ch][rd_ptr[ch]];
                beam_out   <= sum;
                beam_valid <= 1'b1;
            end
        end
    end

endmodule
`default_nettype wire

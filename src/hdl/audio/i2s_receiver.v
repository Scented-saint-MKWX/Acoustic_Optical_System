// =============================================================================
// I2S Receiver for 4× INMP441 Microphones
// Target: Xilinx Artix-7, Nexys A7-100T (100 MHz system clock)
//
// Description:
//   Acts as the I2S master, generating SCK (bit clock) and WS (word select /
//   frame sync) for up to NUM_MICS INMP441 microphones.  Each mic is wired
//   to a separate serial-data (SD) pin and must have its L/R pin tied to GND
//   (left-channel mode).  All mics transmit simultaneously during the WS = 0
//   (left-channel) half-frame.
//
// Protocol: Left-Justified I2S (INMP441 default output format)
//   - SCK rising edge: FPGA samples SD
//   - WS transitions are synchronous with SCK falling edge
//   - First valid data bit (B23, MSB) is presented on the FIRST rising SCK
//     edge after WS falls  (left-justified; no 1-SCK delay)
//   - 24 valid bits per channel in a 32-SCK half-frame (bits 25-32 = 0)
//
// Clock arithmetic (CLK_FREQ = 100 MHz, SCK_DIV = 32):
//   SCK  = CLK_FREQ / SCK_DIV = 100 000 000 / 32 = 3 125 000 Hz
//   WS   = SCK / (2 × FRAME_LEN) = 3 125 000 / 64 = 48 828 Hz  (≈ 48 kHz)
//
// Outputs:
//   i2s_sck    — SCK output to all mics (bit clock)
//   i2s_ws     — WS  output to all mics (L = 0 → left channel)
//   pcm_out    — Packed 24-bit PCM, [NUM_MICS*24-1:0]; mic0 in bits [23:0]
//   pcm_valid  — Single-cycle pulse when a complete new set of samples is ready
// =============================================================================
`timescale 1ns / 1ps
`default_nettype none

module i2s_receiver #(
    parameter NUM_MICS  = 4,   // Number of microphones
    parameter SCK_DIV   = 32,  // sys-clock divider → SCK = 100MHz/32 = 3.125MHz
    parameter FRAME_LEN = 32,  // Bits per WS half-frame (32 for I2S)
    parameter DATA_BITS = 24   // INMP441 audio word width
)(
    input  wire                              clk,
    input  wire                              rst_n,

    // I2S bus (to microphone array)
    output wire                              i2s_sck,    // Bit clock output
    output wire                              i2s_ws,     // Word-select output (0=left)
    input  wire [NUM_MICS-1:0]               i2s_sd,     // Serial data from each mic

    // Parallel PCM output (24-bit per channel)
    output reg  [NUM_MICS*DATA_BITS-1:0]     pcm_out,    // Packed PCM samples
    output reg                               pcm_valid   // Pulse when samples ready
);

    // -------------------------------------------------------------------------
    // Parameter validation
    // -------------------------------------------------------------------------
    // SCK_DIV must be even so SCK has a 50 % duty cycle.
    // FRAME_LEN must be at least DATA_BITS.

    // -------------------------------------------------------------------------
    // SCK generation
    // -------------------------------------------------------------------------
    // sck_cnt counts 0 … (SCK_DIV-1) and is the fine-grained clock divider.
    // SCK transitions at sck_cnt == 0 and sck_cnt == SCK_DIV/2.

    localparam SCK_HALF  = SCK_DIV / 2;                    // 16 cycles
    localparam TOTAL_CNT = SCK_DIV * FRAME_LEN * 2;        // 2048 cycles per WS period

    reg [$clog2(SCK_DIV)-1:0]         sck_cnt;   // 0..SCK_DIV-1
    reg [$clog2(FRAME_LEN*2)-1:0]     bit_cnt;   // 0..2*FRAME_LEN-1 (SCK-edge count)
    reg                               sck_reg;   // Registered SCK output
    reg                               ws_reg;    // Registered WS output

    // SCK is low when sck_cnt < SCK_HALF, high otherwise
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            sck_cnt <= 0;
            bit_cnt <= 0;
            sck_reg <= 1'b0;
            ws_reg  <= 1'b0;   // Start WS low: first half-frame is left channel
        end else begin
            if (sck_cnt == SCK_DIV - 1) begin
                sck_cnt <= 0;
                // Increment bit counter on the SCK falling edge
                // (sck_cnt wrapping back to 0 marks a falling SCK edge because
                //  SCK goes low at sck_cnt = 0)
                if (bit_cnt == FRAME_LEN * 2 - 1)
                    bit_cnt <= 0;
                else
                    bit_cnt <= bit_cnt + 1;
            end else begin
                sck_cnt <= sck_cnt + 1;
            end

            // SCK: low for first half of period, high for second half (exact 50% duty)
            sck_reg <= (sck_cnt >= SCK_HALF);

            // WS: low during first FRAME_LEN bit-periods (left channel)
            //     high during second FRAME_LEN bit-periods (right channel)
            ws_reg  <= (bit_cnt >= FRAME_LEN);
        end
    end

    assign i2s_sck = sck_reg;
    assign i2s_ws  = ws_reg;

    // -------------------------------------------------------------------------
    // Rising SCK edge detection (used for data capture)
    // -------------------------------------------------------------------------
    // SCK goes high when sck_cnt transitions from SCK_HALF-1 to SCK_HALF.
    // We detect the rising edge one cycle later (sck_cnt == SCK_HALF + 1)
    // to ensure the INMP441 data bit is settled on the SD line.

    wire sck_rising = (sck_cnt == SCK_HALF + 1);

    // -------------------------------------------------------------------------
    // Serial-to-parallel shift registers (one per mic)
    // -------------------------------------------------------------------------
    // In left-justified mode the INMP441 drives the MSB of the audio word
    // onto SD starting with the FIRST rising SCK edge after WS falls.
    // bit_cnt 0 corresponds to the last bit of the previous right-channel frame
    // (WS just fell to 0 at bit_cnt = 0 by the loop above).
    // Therefore the first valid bit (B23) is captured when:
    //   ws_reg == 0  AND  bit_cnt == 1  AND  sck_rising

    // Data is captured on bits 0..23 of the left-channel half-frame.
    // bit position within left channel = bit_cnt (valid for bit_cnt 0..23 while ws=0)

    reg [DATA_BITS-1:0] shift_reg [0:NUM_MICS-1];   // Per-mic shift register

    integer m;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            for (m = 0; m < NUM_MICS; m = m + 1)
                shift_reg[m] <= 0;
        end else if (sck_rising && !ws_reg && (bit_cnt < DATA_BITS)) begin
            // Shift in MSB-first: bit_cnt == 0 → MSB (B23)
            for (m = 0; m < NUM_MICS; m = m + 1)
                shift_reg[m] <= {shift_reg[m][DATA_BITS-2:0], i2s_sd[m]};
        end
    end

    // -------------------------------------------------------------------------
    // Output register: latch samples at end of left-channel frame
    // -------------------------------------------------------------------------
    // At bit_cnt == DATA_BITS (one SCK after last data bit) on a falling edge
    // (sck_cnt == 0) the shift register holds the complete word.

    wire frame_done = (bit_cnt == DATA_BITS) && (sck_cnt == 0) && !ws_reg;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            pcm_out   <= 0;
            pcm_valid <= 1'b0;
        end else begin
            pcm_valid <= 1'b0;
            if (frame_done) begin
                for (m = 0; m < NUM_MICS; m = m + 1)
                    pcm_out[m*DATA_BITS +: DATA_BITS] <= shift_reg[m];
                pcm_valid <= 1'b1;
            end
        end
    end

endmodule
`default_nettype wire

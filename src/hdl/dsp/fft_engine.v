// =============================================================================
// 256-Point Radix-2 DIT FFT Engine
// Description: In-place iterative FFT with single butterfly unit.
//              Uses internal dual-port BRAM for sample storage.
//              Wishbone slave for CPU control and result readout.
// =============================================================================
`timescale 1ns / 1ps
`default_nettype none

module fft_engine #(
    parameter FFT_SIZE   = 256,
    parameter DATA_WIDTH = 16
)(
    input  wire        clk,
    input  wire        rst_n,

    // Streaming input
    input  wire signed [DATA_WIDTH-1:0] sample_in,
    input  wire                         sample_valid,

    // Wishbone Slave – control/status/readout
    input  wire [31:0] wb_adr_i,
    input  wire [31:0] wb_dat_i,
    output reg  [31:0] wb_dat_o,
    input  wire        wb_we_i,
    input  wire        wb_cyc_i,
    input  wire        wb_stb_i,
    output reg         wb_ack_o,

    // Interrupt: FFT complete
    output reg         fft_done_irq
);

    localparam LOG2N = $clog2(FFT_SIZE);  // 8 for 256

    // =========================================================================
    // State Machine
    // =========================================================================
    localparam ST_IDLE    = 3'd0,
               ST_LOAD    = 3'd1,
               ST_COMPUTE = 3'd2,
               ST_DONE    = 3'd3;

    reg [2:0] state;

    // =========================================================================
    // Sample Memory (real + imaginary)
    // =========================================================================
    reg signed [DATA_WIDTH-1:0] mem_real [0:FFT_SIZE-1];
    reg signed [DATA_WIDTH-1:0] mem_imag [0:FFT_SIZE-1];

    // =========================================================================
    // Load counter
    // =========================================================================
    reg [LOG2N-1:0] load_cnt;

    // =========================================================================
    // FFT computation indices
    // =========================================================================
    reg [LOG2N-1:0] stage;          // Current stage (0..LOG2N-1)
    reg [LOG2N-1:0] butterfly_idx;  // Butterfly index within stage
    reg [LOG2N-1:0] group_idx;
    reg [LOG2N-1:0] pair_idx;

    wire [LOG2N-1:0] half_size = (1 << stage);
    wire [LOG2N-1:0] group_size = (1 << (stage + 1));

    // Butterfly unit wires
    reg                           bf_valid_in;
    reg  signed [DATA_WIDTH-1:0]  bf_ar, bf_ai, bf_br, bf_bi;
    wire signed [DATA_WIDTH-1:0]  bf_xr, bf_xi, bf_yr, bf_yi;
    wire                          bf_valid_out;

    // Twiddle ROM
    reg  [LOG2N-2:0]              tw_addr;
    wire signed [DATA_WIDTH-1:0]  tw_real, tw_imag;

    // Butterfly addresses
    reg [LOG2N-1:0] addr_top, addr_bot;

    // Pipeline control
    reg [2:0] compute_phase;
    reg       compute_busy;

    // =========================================================================
    // Instantiate butterfly
    // =========================================================================
    fft_butterfly #(.DATA_WIDTH(DATA_WIDTH)) u_butterfly (
        .clk       (clk),
        .rst_n     (rst_n),
        .valid_in  (bf_valid_in),
        .ar        (bf_ar), .ai(bf_ai),
        .br        (bf_br), .bi(bf_bi),
        .wr        (tw_real), .wi(tw_imag),
        .xr        (bf_xr), .xi(bf_xi),
        .yr        (bf_yr), .yi(bf_yi),
        .valid_out (bf_valid_out)
    );

    // =========================================================================
    // Instantiate twiddle ROM
    // =========================================================================
    twiddle_rom #(.FFT_SIZE(FFT_SIZE), .DATA_WIDTH(DATA_WIDTH)) u_twiddle (
        .clk     (clk),
        .addr    (tw_addr),
        .tw_real (tw_real),
        .tw_imag (tw_imag)
    );

    // =========================================================================
    // Bit-reverse function for input ordering
    // =========================================================================
    function [LOG2N-1:0] bit_reverse;
        input [LOG2N-1:0] val;
        integer b;
        begin
            for (b = 0; b < LOG2N; b = b + 1)
                bit_reverse[b] = val[LOG2N - 1 - b];
        end
    endfunction

    // =========================================================================
    // Main FSM
    // =========================================================================
    integer j;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state         <= ST_IDLE;
            load_cnt      <= 0;
            stage         <= 0;
            butterfly_idx <= 0;
            bf_valid_in   <= 1'b0;
            fft_done_irq  <= 1'b0;
            compute_phase <= 0;
            compute_busy  <= 1'b0;
            for (j = 0; j < FFT_SIZE; j = j + 1) begin
                mem_real[j] <= 0;
                mem_imag[j] <= 0;
            end
        end else begin
            bf_valid_in  <= 1'b0;
            fft_done_irq <= 1'b0;

            case (state)
                ST_IDLE: begin
                    load_cnt <= 0;
                    // Transition triggered by WB write to control reg
                end

                ST_LOAD: begin
                    if (sample_valid) begin
                        mem_real[bit_reverse(load_cnt)] <= sample_in;
                        mem_imag[bit_reverse(load_cnt)] <= 0;
                        if (load_cnt == FFT_SIZE - 1) begin
                            load_cnt      <= 0;
                            stage         <= 0;
                            butterfly_idx <= 0;
                            compute_phase <= 0;
                            state         <= ST_COMPUTE;
                        end else begin
                            load_cnt <= load_cnt + 1;
                        end
                    end
                end

                ST_COMPUTE: begin
                    case (compute_phase)
                        3'd0: begin
                            // Calculate butterfly addresses
                            addr_top <= (butterfly_idx / half_size) * group_size
                                        + (butterfly_idx % half_size);
                            addr_bot <= (butterfly_idx / half_size) * group_size
                                        + (butterfly_idx % half_size) + half_size;
                            tw_addr  <= (butterfly_idx % half_size) * (FFT_SIZE / group_size);
                            compute_phase <= 3'd1;
                        end

                        3'd1: begin
                            // Read operands and present to butterfly
                            bf_ar <= mem_real[addr_top];
                            bf_ai <= mem_imag[addr_top];
                            bf_br <= mem_real[addr_bot];
                            bf_bi <= mem_imag[addr_bot];
                            bf_valid_in <= 1'b1;
                            compute_phase <= 3'd2;
                        end

                        3'd2: begin
                            // Wait for butterfly pipeline (2 cycles)
                            compute_phase <= 3'd3;
                        end

                        3'd3: begin
                            if (bf_valid_out) begin
                                mem_real[addr_top] <= bf_xr;
                                mem_imag[addr_top] <= bf_xi;
                                mem_real[addr_bot] <= bf_yr;
                                mem_imag[addr_bot] <= bf_yi;

                                // Advance to next butterfly
                                if (butterfly_idx == (FFT_SIZE/2 - 1)) begin
                                    butterfly_idx <= 0;
                                    if (stage == LOG2N - 1) begin
                                        state        <= ST_DONE;
                                        fft_done_irq <= 1'b1;
                                    end else begin
                                        stage <= stage + 1;
                                    end
                                end else begin
                                    butterfly_idx <= butterfly_idx + 1;
                                end
                                compute_phase <= 3'd0;
                            end
                        end

                        default: compute_phase <= 3'd0;
                    endcase
                end

                ST_DONE: begin
                    // Wait for CPU to read results, then re-arm
                end
            endcase
        end
    end

    // =========================================================================
    // Wishbone Slave Interface
    // =========================================================================
    // Register map (word-addressed):
    //   0x00: Control  [W] bit0=start_load, bit1=re-arm
    //   0x04: Status   [R] bit0=busy, bit1=done
    //   0x08: Reserved
    //   0x100–0x2FF: Real part readout (256 words)
    //   0x300–0x4FF: Imag part readout (256 words)

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            wb_ack_o <= 1'b0;
            wb_dat_o <= 32'd0;
        end else begin
            wb_ack_o <= 1'b0;
            if (wb_cyc_i && wb_stb_i && !wb_ack_o) begin
                wb_ack_o <= 1'b1;

                if (wb_we_i) begin
                    // Write: control register
                    if (wb_adr_i[11:0] == 12'h000) begin
                        if (wb_dat_i[0]) state <= ST_LOAD;
                        if (wb_dat_i[1]) state <= ST_IDLE;
                    end
                end else begin
                    // Read
                    case (wb_adr_i[11:8])
                        4'h0: begin
                            if (wb_adr_i[3:0] == 4'h4)
                                wb_dat_o <= {30'd0, (state == ST_DONE), (state != ST_IDLE && state != ST_DONE)};
                            else
                                wb_dat_o <= 32'd0;
                        end
                        4'h1: wb_dat_o <= {{(32-DATA_WIDTH){mem_real[wb_adr_i[LOG2N+1:2]][DATA_WIDTH-1]}},
                                            mem_real[wb_adr_i[LOG2N+1:2]]};
                        4'h3: wb_dat_o <= {{(32-DATA_WIDTH){mem_imag[wb_adr_i[LOG2N+1:2]][DATA_WIDTH-1]}},
                                            mem_imag[wb_adr_i[LOG2N+1:2]]};
                        default: wb_dat_o <= 32'd0;
                    endcase
                end
            end
        end
    end

endmodule
`default_nettype wire

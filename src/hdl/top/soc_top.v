// =============================================================================
// Acoustic-Optical SoC Top-Level
// Target: Xilinx Artix-7 (Nexys A7-100T) — XC7A100T-1CSG324C
// Description: Integrates RISC-V CPU, PDM microphone array, CIC filters,
//              beamformer, FFT engine, laser vibrometer, UART and GPIO.
// =============================================================================
`timescale 1ns / 1ps
`default_nettype none

module soc_top (
    // Clock & Reset
    input  wire        CLK100MHZ,     // 100 MHz oscillator (E3)
    input  wire        CPU_RESETN,    // Active-low reset button (C12)

    // UART (USB-UART bridge)
    output wire        UART_RXD_OUT,  // FPGA TX → USB
    input  wire        UART_TXD_IN,   // USB → FPGA RX

    // LEDs
    output wire [15:0] LED,

    // Switches
    input  wire [15:0] SW,

    // PDM Microphones (via Pmod JA)
    output wire        JA_PDM_CLK,    // PDM clock to mic array
    input  wire [ 3:0] JA_PDM_DATA,   // PDM data from 4 mics

    // Laser Vibrometer ADC (via Pmod JB – SPI)
    output wire        JB_ADC_SCLK,
    output wire        JB_ADC_CS_N,
    output wire        JB_ADC_MOSI,
    input  wire        JB_ADC_MISO
);

    // =========================================================================
    //  Clock & Reset
    // =========================================================================
    wire clk = CLK100MHZ;
    wire rst_n = CPU_RESETN;

    // =========================================================================
    //  RISC-V Core
    // =========================================================================
    wire [31:0] iwb_adr, iwb_dat;
    wire        iwb_cyc, iwb_stb, iwb_ack;

    wire [31:0] dwb_adr, dwb_dat_wr, dwb_dat_rd;
    wire [ 3:0] dwb_sel;
    wire        dwb_we, dwb_cyc, dwb_stb, dwb_ack;

    riscv_core #(.RESET_ADDR(32'h0000_0000)) u_cpu (
        .clk         (clk),
        .rst_n       (rst_n),

        .iwb_adr_o   (iwb_adr),
        .iwb_dat_i   (iwb_dat),
        .iwb_cyc_o   (iwb_cyc),
        .iwb_stb_o   (iwb_stb),
        .iwb_ack_i   (iwb_ack),

        .dwb_adr_o   (dwb_adr),
        .dwb_dat_o   (dwb_dat_wr),
        .dwb_dat_i   (dwb_dat_rd),
        .dwb_sel_o   (dwb_sel),
        .dwb_we_o    (dwb_we),
        .dwb_cyc_o   (dwb_cyc),
        .dwb_stb_o   (dwb_stb),
        .dwb_ack_i   (dwb_ack),

        .irq_external(1'b0),
        .irq_timer   (1'b0)
    );

    // =========================================================================
    //  Block RAM (8 KB – instruction + data)
    // =========================================================================
    wire [31:0] ram_d_adr, ram_d_dat_wr, ram_d_dat_rd;
    wire [ 3:0] ram_d_sel;
    wire        ram_d_we, ram_d_cyc, ram_d_stb, ram_d_ack;

    block_ram #(
        .DEPTH     (2048),
        .INIT_FILE ("firmware.hex")
    ) u_ram (
        .clk      (clk),
        // Port A: Instruction fetch
        .a_adr_i  (iwb_adr),
        .a_dat_o  (iwb_dat),
        .a_cyc_i  (iwb_cyc),
        .a_stb_i  (iwb_stb),
        .a_ack_o  (iwb_ack),
        // Port B: Data
        .b_adr_i  (ram_d_adr),
        .b_dat_i  (ram_d_dat_wr),
        .b_dat_o  (ram_d_dat_rd),
        .b_sel_i  (ram_d_sel),
        .b_we_i   (ram_d_we),
        .b_cyc_i  (ram_d_cyc),
        .b_stb_i  (ram_d_stb),
        .b_ack_o  (ram_d_ack)
    );

    // =========================================================================
    //  GPIO
    // =========================================================================
    wire [31:0] gpio_adr, gpio_dat_wr, gpio_dat_rd;
    wire        gpio_we, gpio_cyc, gpio_stb, gpio_ack;

    gpio #(.WIDTH(16)) u_gpio (
        .clk      (clk),
        .rst_n    (rst_n),
        .wb_adr_i (gpio_adr),
        .wb_dat_i (gpio_dat_wr),
        .wb_dat_o (gpio_dat_rd),
        .wb_we_i  (gpio_we),
        .wb_cyc_i (gpio_cyc),
        .wb_stb_i (gpio_stb),
        .wb_ack_o (gpio_ack),
        .gpio_in  (SW),
        .gpio_out (LED),
        .gpio_dir ()       // Direction not exposed to pins
    );

    // =========================================================================
    //  UART TX
    // =========================================================================
    wire [31:0] utx_adr, utx_dat_wr, utx_dat_rd;
    wire        utx_we, utx_cyc, utx_stb, utx_ack;

    uart_tx #(.CLK_FREQ(100_000_000), .BAUD_RATE(115_200)) u_uart_tx (
        .clk      (clk),
        .rst_n    (rst_n),
        .wb_adr_i (utx_adr),
        .wb_dat_i (utx_dat_wr),
        .wb_dat_o (utx_dat_rd),
        .wb_we_i  (utx_we),
        .wb_cyc_i (utx_cyc),
        .wb_stb_i (utx_stb),
        .wb_ack_o (utx_ack),
        .tx       (UART_RXD_OUT)
    );

    // =========================================================================
    //  UART RX
    // =========================================================================
    wire [31:0] urx_adr, urx_dat_wr, urx_dat_rd;
    wire        urx_we, urx_cyc, urx_stb, urx_ack;
    wire        urx_irq;

    uart_rx #(.CLK_FREQ(100_000_000), .BAUD_RATE(115_200)) u_uart_rx (
        .clk      (clk),
        .rst_n    (rst_n),
        .wb_adr_i (urx_adr),
        .wb_dat_i (urx_dat_wr),
        .wb_dat_o (urx_dat_rd),
        .wb_we_i  (urx_we),
        .wb_cyc_i (urx_cyc),
        .wb_stb_i (urx_stb),
        .wb_ack_o (urx_ack),
        .rx       (UART_TXD_IN),
        .rx_irq   (urx_irq)
    );

    // =========================================================================
    //  PDM Microphone Array + CIC Filters
    // =========================================================================
    wire        pdm_clk_out;
    wire [3:0]  pdm_samples;
    wire        pdm_valid;

    pdm_interface #(.NUM_MICS(4), .CLK_DIV(32)) u_pdm (
        .clk          (clk),
        .rst_n        (rst_n),
        .enable       (1'b1),
        .pdm_clk      (pdm_clk_out),
        .pdm_data     (JA_PDM_DATA),
        .sample_out   (pdm_samples),
        .sample_valid (pdm_valid)
    );

    assign JA_PDM_CLK = pdm_clk_out;

    // CIC filter per channel
    wire [15:0] pcm_ch [0:3];
    wire [3:0]  pcm_valid;

    genvar ch;
    generate
        for (ch = 0; ch < 4; ch = ch + 1) begin : gen_cic
            cic_filter #(
                .ORDER     (4),
                .DEC_RATIO (64),
                .INP_WIDTH (1),
                .ACC_WIDTH (36),
                .OUT_WIDTH (16)
            ) u_cic (
                .clk          (clk),
                .rst_n        (rst_n),
                .sample_valid (pdm_valid),
                .data_in      (pdm_samples[ch]),
                .data_out     (pcm_ch[ch]),
                .data_valid   (pcm_valid[ch])
            );
        end
    endgenerate

    // =========================================================================
    //  Beamformer
    // =========================================================================
    wire [31:0] beam_adr, beam_dat_wr, beam_dat_rd;
    wire        beam_we, beam_cyc, beam_stb, beam_ack;
    wire signed [17:0] beam_out;
    wire               beam_valid;

    beamformer #(
        .NUM_CHANNELS(4),
        .DATA_WIDTH  (16),
        .MAX_DELAY   (32),
        .OUT_WIDTH   (18)
    ) u_beamformer (
        .clk       (clk),
        .rst_n     (rst_n),
        .pcm_in    ({pcm_ch[3], pcm_ch[2], pcm_ch[1], pcm_ch[0]}),
        .pcm_valid (pcm_valid[0]),  // All channels produce data simultaneously
        .wb_adr_i  (beam_adr),
        .wb_dat_i  (beam_dat_wr),
        .wb_we_i   (beam_we),
        .wb_cyc_i  (beam_cyc),
        .wb_stb_i  (beam_stb),
        .wb_ack_o  (beam_ack),
        .beam_out  (beam_out),
        .beam_valid(beam_valid)
    );

    // =========================================================================
    //  FFT Engine (on beamformed stream)
    // =========================================================================
    wire [31:0] fft_adr, fft_dat_wr, fft_dat_rd;
    wire        fft_we, fft_cyc, fft_stb, fft_ack;
    wire        fft_done_irq;

    fft_engine #(.FFT_SIZE(256), .DATA_WIDTH(16)) u_fft (
        .clk          (clk),
        .rst_n        (rst_n),
        .sample_in    (beam_out[17:2]),   // Truncate to 16 bits
        .sample_valid (beam_valid),
        .wb_adr_i     (fft_adr),
        .wb_dat_i     (fft_dat_wr),
        .wb_dat_o     (fft_dat_rd),
        .wb_we_i      (fft_we),
        .wb_cyc_i     (fft_cyc),
        .wb_stb_i     (fft_stb),
        .wb_ack_o     (fft_ack),
        .fft_done_irq (fft_done_irq)
    );

    // =========================================================================
    //  Laser Vibrometer
    // =========================================================================
    wire [31:0] lv_adr, lv_dat_wr, lv_dat_rd;
    wire        lv_we, lv_cyc, lv_stb, lv_ack;
    wire        lv_irq;

    laser_vibrometer #(.DATA_WIDTH(16)) u_laser (
        .clk             (clk),
        .rst_n           (rst_n),
        .adc_sclk        (JB_ADC_SCLK),
        .adc_cs_n        (JB_ADC_CS_N),
        .adc_mosi        (JB_ADC_MOSI),
        .adc_miso        (JB_ADC_MISO),
        .wb_adr_i        (lv_adr),
        .wb_dat_i        (lv_dat_wr),
        .wb_dat_o        (lv_dat_rd),
        .wb_we_i         (lv_we),
        .wb_cyc_i        (lv_cyc),
        .wb_stb_i        (lv_stb),
        .wb_ack_o        (lv_ack),
        .velocity_out    (),
        .data_valid      (),
        .sample_ready_irq(lv_irq)
    );

    // =========================================================================
    //  Wishbone Interconnect
    // =========================================================================
    wishbone_interconnect u_bus (
        .clk      (clk),
        .rst_n    (rst_n),

        // Master (CPU data bus)
        .m_adr_i  (dwb_adr),
        .m_dat_i  (dwb_dat_wr),
        .m_dat_o  (dwb_dat_rd),
        .m_sel_i  (dwb_sel),
        .m_we_i   (dwb_we),
        .m_cyc_i  (dwb_cyc),
        .m_stb_i  (dwb_stb),
        .m_ack_o  (dwb_ack),

        // Slave 0: RAM
        .s0_adr_o (ram_d_adr),  .s0_dat_o(ram_d_dat_wr), .s0_dat_i(ram_d_dat_rd),
        .s0_sel_o (ram_d_sel),  .s0_we_o (ram_d_we),
        .s0_cyc_o (ram_d_cyc),  .s0_stb_o(ram_d_stb),    .s0_ack_i(ram_d_ack),

        // Slave 1: GPIO
        .s1_adr_o (gpio_adr),   .s1_dat_o(gpio_dat_wr),  .s1_dat_i(gpio_dat_rd),
        .s1_we_o  (gpio_we),    .s1_cyc_o(gpio_cyc),     .s1_stb_o(gpio_stb),
        .s1_ack_i (gpio_ack),

        // Slave 2: UART TX
        .s2_adr_o (utx_adr),    .s2_dat_o(utx_dat_wr),   .s2_dat_i(utx_dat_rd),
        .s2_we_o  (utx_we),     .s2_cyc_o(utx_cyc),      .s2_stb_o(utx_stb),
        .s2_ack_i (utx_ack),

        // Slave 3: UART RX
        .s3_adr_o (urx_adr),    .s3_dat_o(urx_dat_wr),   .s3_dat_i(urx_dat_rd),
        .s3_we_o  (urx_we),     .s3_cyc_o(urx_cyc),      .s3_stb_o(urx_stb),
        .s3_ack_i (urx_ack),

        // Slave 4: Beamformer
        .s4_adr_o (beam_adr),   .s4_dat_o(beam_dat_wr),  .s4_dat_i(beam_dat_rd),
        .s4_we_o  (beam_we),    .s4_cyc_o(beam_cyc),     .s4_stb_o(beam_stb),
        .s4_ack_i (beam_ack),

        // Slave 5: FFT
        .s5_adr_o (fft_adr),    .s5_dat_o(fft_dat_wr),   .s5_dat_i(fft_dat_rd),
        .s5_we_o  (fft_we),     .s5_cyc_o(fft_cyc),      .s5_stb_o(fft_stb),
        .s5_ack_i (fft_ack),

        // Slave 6: Laser
        .s6_adr_o (lv_adr),     .s6_dat_o(lv_dat_wr),    .s6_dat_i(lv_dat_rd),
        .s6_we_o  (lv_we),      .s6_cyc_o(lv_cyc),       .s6_stb_o(lv_stb),
        .s6_ack_i (lv_ack)
    );

endmodule
`default_nettype wire

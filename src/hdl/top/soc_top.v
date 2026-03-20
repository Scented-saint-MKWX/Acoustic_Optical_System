// =============================================================================
// Acoustic-Optical SoC Top-Level
// Target: Xilinx Artix-7 (Nexys A7-100T) — XC7A100T-1CSG324C
// Description: Integrates RISC-V CPU, I2S microphone array (4× INMP441),
//              hardware AoA estimator, delay-and-sum beamformer, FFT engine,
//              laser vibrometer simulator (NCO/DDS), AXI4-Lite DSP output
//              register block, UART and GPIO.
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

    // I2S Microphone Array (4× INMP441 via Pmod JA)
    // Wire L/R pin of every mic to GND (left-channel mode).
    output wire        JA_I2S_SCK,    // I2S bit clock  (JA pin 1, C17)
    output wire        JA_I2S_WS,     // I2S word select (JA pin 2, D18)
    input  wire [ 3:0] JA_I2S_SD,     // I2S serial data from each mic
                                       //   SD[0] = mic0 (JA pin 3, E18)
                                       //   SD[1] = mic1 (JA pin 4, G17)
                                       //   SD[2] = mic2 (JA pin 7, D17)
                                       //   SD[3] = mic3 (JA pin 8, E17)

    // Laser Vibrometer ADC port (kept for physical connector compatibility;
    // driven to safe idle values — simulation uses laser_simulator internally)
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
    //  I2S Microphone Array (4× INMP441)
    //  Replaces the former PDM interface + CIC-filter chain.
    //  The INMP441 outputs 24-bit left-justified I2S PCM directly — no
    //  decimation filter is required.
    // =========================================================================
    // Clock arithmetic:
    //   SCK  = 100MHz / 32 = 3.125 MHz
    //   WS   = 3.125MHz / 64 = 48.828 kHz  (≈ 48 kHz audio sample rate)

    wire [23:0] i2s_pcm [0:3];    // 24-bit PCM per channel
    wire        i2s_valid;         // One pulse per sample set (48.828 kHz)
    wire [4*24-1:0] i2s_pcm_packed;

    i2s_receiver #(
        .NUM_MICS  (4),
        .SCK_DIV   (32),
        .FRAME_LEN (32),
        .DATA_BITS (24)
    ) u_i2s (
        .clk       (clk),
        .rst_n     (rst_n),
        .i2s_sck   (JA_I2S_SCK),
        .i2s_ws    (JA_I2S_WS),
        .i2s_sd    (JA_I2S_SD),
        .pcm_out   (i2s_pcm_packed),
        .pcm_valid (i2s_valid)
    );

    // Unpack 24-bit PCM words (mic0 = bits[23:0])
    assign i2s_pcm[0] = i2s_pcm_packed[23:0];
    assign i2s_pcm[1] = i2s_pcm_packed[47:24];
    assign i2s_pcm[2] = i2s_pcm_packed[71:48];
    assign i2s_pcm[3] = i2s_pcm_packed[95:72];

    // Truncate 24-bit → 16-bit for downstream beamformer (keep top 16 bits)
    wire [15:0] pcm_ch [0:3];
    assign pcm_ch[0] = i2s_pcm[0][23:8];
    assign pcm_ch[1] = i2s_pcm[1][23:8];
    assign pcm_ch[2] = i2s_pcm[2][23:8];
    assign pcm_ch[3] = i2s_pcm[3][23:8];

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
        .pcm_valid (i2s_valid),     // Single valid from I2S receiver
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
    //  Laser Vibrometer Simulator
    //  Replaces the physical laser vibrometer + SPI ADC for demonstration.
    //  The NCO/DDS generates a calibrated sine wave; the sim_freq_hz register
    //  outputs the configured frequency (default 440 Hz).
    //  The physical JB connector is driven to a safe idle state.
    // =========================================================================
    wire [31:0] lv_adr, lv_dat_wr, lv_dat_rd;
    wire        lv_we, lv_cyc, lv_stb, lv_ack;

    wire [31:0] sim_freq_hz;    // Feeds the AXI memory map

    laser_simulator #(
        .CLK_FREQ     (100_000_000),
        .DEFAULT_FREQ (440),
        .PHASE_WIDTH  (32),
        .OUTPUT_WIDTH (16)
    ) u_laser_sim (
        .clk          (clk),
        .rst_n        (rst_n),
        .wb_adr_i     (lv_adr),
        .wb_dat_i     (lv_dat_wr),
        .wb_dat_o     (lv_dat_rd),
        .wb_we_i      (lv_we),
        .wb_cyc_i     (lv_cyc),
        .wb_stb_i     (lv_stb),
        .wb_ack_o     (lv_ack),
        .sim_freq_hz  (sim_freq_hz),
        .wave_out     (),
        .sample_valid ()
    );

    // Drive JB SPI pins to a safe idle state (no physical ADC needed)
    assign JB_ADC_SCLK = 1'b0;
    assign JB_ADC_CS_N = 1'b1;   // Deselect
    assign JB_ADC_MOSI = 1'b0;

    // =========================================================================
    //  Hardware AoA Estimator
    //  Computes the angle of arrival from TDOA between mic 0 and mic 3.
    // =========================================================================
    wire signed [15:0] hw_aoa_angle;   // Degrees × 10, signed
    wire               hw_angle_valid;

    aoa_estimator #(
        .DATA_WIDTH (16),
        .MAX_LAG    (4),
        .ACCUM_LEN  (256)
    ) u_aoa (
        .clk         (clk),
        .rst_n       (rst_n),
        .mic0        (pcm_ch[0]),
        .mic3        (pcm_ch[3]),
        .pcm_valid   (i2s_valid),
        .aoa_angle   (hw_aoa_angle),
        .angle_valid (hw_angle_valid)
    );

    // =========================================================================
    //  AXI4-Lite / Wishbone DSP Output Register Block
    //  Slave 7 on Wishbone bus → base address 0x8000_6000
    //  Exposes hw_aoa_angle and sim_freq_hz for RISC-V polling.
    // =========================================================================
    wire [31:0] axim_adr, axim_dat_wr, axim_dat_rd;
    wire        axim_we, axim_cyc, axim_stb, axim_ack;

    axi_memory_map u_axi_map (
        .clk              (clk),
        .rst_n            (rst_n),
        // Hardware inputs
        .aoa_angle_in     (hw_aoa_angle),
        .sim_freq_hz_in   (sim_freq_hz),
        .angle_valid_in   (hw_angle_valid),
        .freq_valid_in    (1'b1),           // sim_freq_hz is always valid
        // Wishbone
        .wb_adr_i         (axim_adr),
        .wb_dat_i         (axim_dat_wr),
        .wb_dat_o         (axim_dat_rd),
        .wb_we_i          (axim_we),
        .wb_cyc_i         (axim_cyc),
        .wb_stb_i         (axim_stb),
        .wb_ack_o         (axim_ack),
        // AXI4-Lite (tied off — no external AXI master on this board)
        .s_axil_awaddr    (32'd0),
        .s_axil_awvalid   (1'b0),
        .s_axil_awready   (),
        .s_axil_wdata     (32'd0),
        .s_axil_wstrb     (4'd0),
        .s_axil_wvalid    (1'b0),
        .s_axil_wready    (),
        .s_axil_bresp     (),
        .s_axil_bvalid    (),
        .s_axil_bready    (1'b1),
        .s_axil_araddr    (32'd0),
        .s_axil_arvalid   (1'b0),
        .s_axil_arready   (),
        .s_axil_rdata     (),
        .s_axil_rresp     (),
        .s_axil_rvalid    (),
        .s_axil_rready    (1'b1)
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

        // Slave 6: Laser Simulator
        .s6_adr_o (lv_adr),     .s6_dat_o(lv_dat_wr),    .s6_dat_i(lv_dat_rd),
        .s6_we_o  (lv_we),      .s6_cyc_o(lv_cyc),       .s6_stb_o(lv_stb),
        .s6_ack_i (lv_ack),

        // Slave 7: AXI Memory Map (DSP output registers)
        .s7_adr_o (axim_adr),   .s7_dat_o(axim_dat_wr),  .s7_dat_i(axim_dat_rd),
        .s7_we_o  (axim_we),    .s7_cyc_o(axim_cyc),     .s7_stb_o(axim_stb),
        .s7_ack_i (axim_ack)
    );

endmodule
`default_nettype wire

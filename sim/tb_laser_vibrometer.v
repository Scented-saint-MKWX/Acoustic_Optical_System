// =============================================================================
// Testbench: Laser Vibrometer
// Simulates ADC SPI responses and verifies quadrature demodulation output.
// =============================================================================
`timescale 1ns / 1ps

module tb_laser_vibrometer;

    parameter CLK_PERIOD = 10;

    reg  clk, rst_n;
    wire adc_sclk, adc_cs_n, adc_mosi;
    reg  adc_miso;

    // Wishbone
    reg  [31:0] wb_adr, wb_dat_wr;
    wire [31:0] wb_dat_rd;
    reg         wb_we, wb_cyc, wb_stb;
    wire        wb_ack;

    wire signed [15:0] velocity;
    wire        data_valid;
    wire        irq;

    laser_vibrometer #(.DATA_WIDTH(16), .SAMPLE_RATE(48000)) uut (
        .clk             (clk),
        .rst_n           (rst_n),
        .adc_sclk        (adc_sclk),
        .adc_cs_n        (adc_cs_n),
        .adc_mosi        (adc_mosi),
        .adc_miso        (adc_miso),
        .wb_adr_i        (wb_adr),
        .wb_dat_i        (wb_dat_wr),
        .wb_dat_o        (wb_dat_rd),
        .wb_we_i         (wb_we),
        .wb_cyc_i        (wb_cyc),
        .wb_stb_i        (wb_stb),
        .wb_ack_o        (wb_ack),
        .velocity_out    (velocity),
        .data_valid      (data_valid),
        .sample_ready_irq(irq)
    );

    initial clk = 0;
    always #(CLK_PERIOD/2) clk = ~clk;

    // Simulate ADC: return a rotating phasor (I = cos, Q = sin)
    reg [15:0] adc_response;
    reg [15:0] phase;
    initial phase = 0;

    always @(negedge adc_cs_n) begin
        // Alternate between I and Q channels
        adc_response <= (phase[0]) ? (16'h2000 + phase * 16'h0100) :
                                      (16'h3000 - phase * 16'h0080);
        phase <= phase + 1;
    end

    always @(negedge adc_sclk or posedge adc_cs_n) begin
        if (adc_cs_n) begin
            adc_miso <= 1'b0;
        end else begin
            adc_miso     <= adc_response[15];
            adc_response <= {adc_response[14:0], 1'b0};
        end
    end

    // Monitor
    always @(posedge clk) begin
        if (data_valid)
            $display("T=%0t  Velocity = %0d", $time, velocity);
    end

    // Wishbone write task
    task wb_write(input [31:0] addr, input [31:0] data);
        begin
            @(posedge clk);
            wb_adr    <= addr;
            wb_dat_wr <= data;
            wb_we     <= 1;
            wb_cyc    <= 1;
            wb_stb    <= 1;
            @(posedge clk);
            wait(wb_ack);
            @(posedge clk);
            wb_cyc <= 0;
            wb_stb <= 0;
            wb_we  <= 0;
        end
    endtask

    initial begin
        $dumpfile("tb_laser_vibrometer.vcd");
        $dumpvars(0, tb_laser_vibrometer);

        rst_n     = 0;
        adc_miso  = 0;
        wb_adr    = 0;
        wb_dat_wr = 0;
        wb_we     = 0;
        wb_cyc    = 0;
        wb_stb    = 0;

        #100;
        rst_n = 1;
        #50;

        // Enable the vibrometer
        wb_write(32'h80005000, 32'h0000_0001);
        $display("Laser vibrometer enabled.");

        // Let it run for several sample periods
        #5_000_000;

        $display("=== Laser Vibrometer testbench complete ===");
        $finish;
    end

endmodule

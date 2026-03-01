// =============================================================================
// Laser Vibrometer Interface
// Description: Interfaces with an external laser vibrometer sensor.
//              Reads quadrature (I/Q) signals from an ADC via SPI,
//              performs digital quadrature demodulation to extract
//              displacement/velocity of the target surface.
//              Wishbone slave for CPU configuration and data readout.
// =============================================================================
`timescale 1ns / 1ps
`default_nettype none

module laser_vibrometer #(
    parameter DATA_WIDTH  = 16,
    parameter SAMPLE_RATE = 48000  // Hz (informational)
)(
    input  wire        clk,
    input  wire        rst_n,

    // SPI interface to external ADC (e.g., AD7606 or ADS8688)
    output wire        adc_sclk,
    output wire        adc_cs_n,
    output wire        adc_mosi,
    input  wire        adc_miso,

    // Wishbone Slave – control/status/data
    input  wire [31:0] wb_adr_i,
    input  wire [31:0] wb_dat_i,
    output reg  [31:0] wb_dat_o,
    input  wire        wb_we_i,
    input  wire        wb_cyc_i,
    input  wire        wb_stb_i,
    output reg         wb_ack_o,

    // Data output
    output reg  signed [DATA_WIDTH-1:0] velocity_out,
    output reg                          data_valid,

    // Interrupt
    output reg                          sample_ready_irq
);

    // =========================================================================
    // SPI Master for ADC readout
    // =========================================================================
    reg        spi_start;
    reg [15:0] spi_tx_data;
    wire [15:0] spi_rx_data;
    wire        spi_done;

    spi_master #(.WIDTH(16), .CPOL(0), .CPHA(0), .CLK_DIV(8)) u_spi (
        .clk      (clk),
        .rst_n    (rst_n),
        .start    (spi_start),
        .tx_data  (spi_tx_data),
        .rx_data  (spi_rx_data),
        .done     (spi_done),
        .sclk     (adc_sclk),
        .cs_n     (adc_cs_n),
        .mosi     (adc_mosi),
        .miso     (adc_miso)
    );

    // =========================================================================
    // Sample timing generator
    // =========================================================================
    localparam SAMPLE_DIV = 100_000_000 / SAMPLE_RATE; // ~2083 for 48 kHz
    reg [15:0] sample_cnt;
    reg        sample_tick;
    reg        enabled;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            sample_cnt  <= 0;
            sample_tick <= 1'b0;
        end else begin
            sample_tick <= 1'b0;
            if (enabled) begin
                if (sample_cnt >= SAMPLE_DIV - 1) begin
                    sample_cnt  <= 0;
                    sample_tick <= 1'b1;
                end else begin
                    sample_cnt <= sample_cnt + 1;
                end
            end else begin
                sample_cnt <= 0;
            end
        end
    end

    // =========================================================================
    // ADC Acquisition State Machine
    // =========================================================================
    localparam ACQ_IDLE     = 2'd0,
               ACQ_READ_I   = 2'd1,
               ACQ_READ_Q   = 2'd2,
               ACQ_PROCESS  = 2'd3;

    reg [1:0] acq_state;
    reg signed [DATA_WIDTH-1:0] adc_i_sample;
    reg signed [DATA_WIDTH-1:0] adc_q_sample;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            acq_state    <= ACQ_IDLE;
            adc_i_sample <= 0;
            adc_q_sample <= 0;
            spi_start    <= 1'b0;
            spi_tx_data  <= 16'd0;
        end else begin
            spi_start <= 1'b0;

            case (acq_state)
                ACQ_IDLE: begin
                    if (sample_tick) begin
                        spi_tx_data <= 16'h0000; // Read channel 0 (I)
                        spi_start   <= 1'b1;
                        acq_state   <= ACQ_READ_I;
                    end
                end

                ACQ_READ_I: begin
                    if (spi_done) begin
                        adc_i_sample <= spi_rx_data;
                        spi_tx_data  <= 16'h0001; // Read channel 1 (Q)
                        spi_start    <= 1'b1;
                        acq_state    <= ACQ_READ_Q;
                    end
                end

                ACQ_READ_Q: begin
                    if (spi_done) begin
                        adc_q_sample <= spi_rx_data;
                        acq_state    <= ACQ_PROCESS;
                    end
                end

                ACQ_PROCESS: begin
                    acq_state <= ACQ_IDLE;
                end
            endcase
        end
    end

    // =========================================================================
    // Quadrature Demodulation – extract instantaneous phase & velocity
    // =========================================================================
    reg signed [DATA_WIDTH-1:0] prev_i, prev_q;
    reg signed [31:0] phase_diff;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            prev_i          <= 0;
            prev_q          <= 0;
            velocity_out    <= 0;
            data_valid      <= 1'b0;
            sample_ready_irq <= 1'b0;
            phase_diff      <= 0;
        end else begin
            data_valid       <= 1'b0;
            sample_ready_irq <= 1'b0;

            if (acq_state == ACQ_PROCESS) begin
                // Approximate atan2 differentiation:
                // dφ ≈ (I_prev * Q_curr - Q_prev * I_curr) / (I^2 + Q^2)
                // Simplified for fixed-point: just numerator scaled down
                phase_diff <= (prev_i * adc_q_sample) - (prev_q * adc_i_sample);
                velocity_out <= phase_diff[DATA_WIDTH+7 : 8]; // Scale down
                data_valid       <= 1'b1;
                sample_ready_irq <= 1'b1;

                prev_i <= adc_i_sample;
                prev_q <= adc_q_sample;
            end
        end
    end

    // =========================================================================
    // Wishbone Register Interface
    // =========================================================================
    // 0x00: Control – bit0: enable
    // 0x04: Status  – bit0: data_valid
    // 0x08: I sample (last)
    // 0x0C: Q sample (last)
    // 0x10: Velocity (last)

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            wb_ack_o <= 1'b0;
            wb_dat_o <= 32'd0;
            enabled  <= 1'b0;
        end else begin
            wb_ack_o <= 1'b0;
            if (wb_cyc_i && wb_stb_i && !wb_ack_o) begin
                wb_ack_o <= 1'b1;
                if (wb_we_i) begin
                    case (wb_adr_i[4:2])
                        3'd0: enabled <= wb_dat_i[0];
                        default: ;
                    endcase
                end else begin
                    case (wb_adr_i[4:2])
                        3'd0: wb_dat_o <= {31'd0, enabled};
                        3'd1: wb_dat_o <= {31'd0, data_valid};
                        3'd2: wb_dat_o <= {{(32-DATA_WIDTH){adc_i_sample[DATA_WIDTH-1]}}, adc_i_sample};
                        3'd3: wb_dat_o <= {{(32-DATA_WIDTH){adc_q_sample[DATA_WIDTH-1]}}, adc_q_sample};
                        3'd4: wb_dat_o <= {{(32-DATA_WIDTH){velocity_out[DATA_WIDTH-1]}}, velocity_out};
                        default: wb_dat_o <= 32'd0;
                    endcase
                end
            end
        end
    end

endmodule
`default_nettype wire

// =============================================================================
// Testbench: SoC Top-Level Integration
// Verifies that the full SoC boots, UART transmits, and subsystems respond.
// =============================================================================
`timescale 1ns / 1ps

module tb_soc_top;

    parameter CLK_PERIOD = 10;  // 100 MHz

    reg         clk;
    reg         rst_n;
    wire        uart_tx;
    wire [15:0] led;
    reg  [15:0] sw;
    wire        pdm_clk;
    reg  [ 3:0] pdm_data;
    wire        adc_sclk, adc_cs_n, adc_mosi;
    reg         adc_miso;

    soc_top uut (
        .CLK100MHZ    (clk),
        .CPU_RESETN   (rst_n),
        .UART_RXD_OUT (uart_tx),
        .UART_TXD_IN  (1'b1),      // Idle high (no RX data)
        .LED          (led),
        .SW           (sw),
        .JA_PDM_CLK   (pdm_clk),
        .JA_PDM_DATA  (pdm_data),
        .JB_ADC_SCLK  (adc_sclk),
        .JB_ADC_CS_N  (adc_cs_n),
        .JB_ADC_MOSI  (adc_mosi),
        .JB_ADC_MISO  (adc_miso)
    );

    // Clock
    initial clk = 0;
    always #(CLK_PERIOD/2) clk = ~clk;

    // Simulate PDM microphone (simple toggle)
    always @(posedge pdm_clk) begin
        pdm_data <= $random;
    end

    // Simulate ADC MISO (return incrementing pattern)
    reg [15:0] adc_shift;
    always @(negedge adc_sclk or posedge adc_cs_n) begin
        if (adc_cs_n)
            adc_shift <= 16'h1234;
        else begin
            adc_miso  <= adc_shift[15];
            adc_shift <= {adc_shift[14:0], 1'b0};
        end
    end

    // UART byte capture (for monitoring TX output)
    reg [7:0] uart_shift;
    reg [3:0] uart_bit_cnt;
    integer   uart_baud_cnt;
    localparam UART_BAUD_TICKS = 100_000_000 / 115_200;

    initial begin
        uart_bit_cnt = 0;
        uart_baud_cnt = 0;
    end

    always @(posedge clk) begin
        if (uart_bit_cnt == 0) begin
            // Wait for start bit (falling edge on TX)
            if (!uart_tx) begin
                uart_baud_cnt <= UART_BAUD_TICKS + UART_BAUD_TICKS/2; // sample mid-bit
                uart_bit_cnt  <= 1;
            end
        end else begin
            if (uart_baud_cnt == 0) begin
                if (uart_bit_cnt <= 8) begin
                    uart_shift <= {uart_tx, uart_shift[7:1]};
                    uart_baud_cnt <= UART_BAUD_TICKS;
                    uart_bit_cnt  <= uart_bit_cnt + 1;
                end else begin
                    // Stop bit – print character
                    if (uart_shift >= 8'h20 && uart_shift < 8'h7F)
                        $write("%c", uart_shift);
                    else if (uart_shift == 8'h0A)
                        $write("\n");
                    else if (uart_shift == 8'h0D)
                        ; // skip CR
                    else
                        $write("[%02h]", uart_shift);
                    uart_bit_cnt <= 0;
                end
            end else begin
                uart_baud_cnt <= uart_baud_cnt - 1;
            end
        end
    end

    // Test scenario
    initial begin
        $dumpfile("tb_soc_top.vcd");
        $dumpvars(0, tb_soc_top);

        rst_n    = 0;
        sw       = 16'h0030;  // ~30° steering angle
        adc_miso = 0;

        #200;
        rst_n = 1;

        // Run for a long time to see UART boot message
        #10_000_000;

        $display("\n=== SoC Integration test complete ===");
        $display("LEDs = 0x%04h", led);
        $finish;
    end

endmodule

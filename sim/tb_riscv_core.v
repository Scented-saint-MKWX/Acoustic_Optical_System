// =============================================================================
// Testbench: RISC-V Core
// Loads a small test program into RAM and checks execution.
// =============================================================================
`timescale 1ns / 1ps

module tb_riscv_core;

    parameter CLK_PERIOD = 10;

    reg  clk, rst_n;

    // Instruction bus
    wire [31:0] iwb_adr;
    reg  [31:0] iwb_dat;
    wire        iwb_cyc, iwb_stb;
    reg         iwb_ack;

    // Data bus
    wire [31:0] dwb_adr, dwb_dat_wr;
    reg  [31:0] dwb_dat_rd;
    wire [ 3:0] dwb_sel;
    wire        dwb_we, dwb_cyc, dwb_stb;
    reg         dwb_ack;

    riscv_core #(.RESET_ADDR(32'h0000_0000)) uut (
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

    initial clk = 0;
    always #(CLK_PERIOD/2) clk = ~clk;

    // Simple instruction memory (16 words)
    reg [31:0] imem [0:15];

    initial begin
        // Test program:
        // 0x00: addi x1, x0, 42       → x1 = 42
        // 0x04: addi x2, x0, 10       → x2 = 10
        // 0x08: add  x3, x1, x2       → x3 = 52
        // 0x0C: sw   x3, 0(x0)        → mem[0x80000000] = 52 (GPIO write)
        // 0x10: jal  x0, 0x10         → infinite loop

        imem[0]  = 32'h02A00093; // addi x1, x0, 42
        imem[1]  = 32'h00A00113; // addi x2, x0, 10
        imem[2]  = 32'h002081B3; // add  x3, x1, x2
        imem[3]  = 32'h80000237; // lui  x4, 0x80000
        imem[4]  = 32'h00322023; // sw   x3, 0(x4)
        imem[5]  = 32'h0000006F; // jal  x0, 0   (loop)
        imem[6]  = 32'h00000013; // nop
        imem[7]  = 32'h00000013; // nop
    end

    // Instruction fetch responder
    always @(posedge clk) begin
        iwb_ack <= 1'b0;
        if (iwb_cyc && iwb_stb && !iwb_ack) begin
            iwb_dat <= imem[iwb_adr[5:2]];
            iwb_ack <= 1'b1;
        end
    end

    // Data bus responder (just acknowledge and log)
    always @(posedge clk) begin
        dwb_ack <= 1'b0;
        if (dwb_cyc && dwb_stb && !dwb_ack) begin
            dwb_ack   <= 1'b1;
            dwb_dat_rd <= 32'hDEAD_BEEF;
            if (dwb_we)
                $display("T=%0t  DATA WRITE: addr=0x%08h data=0x%08h sel=%04b",
                         $time, dwb_adr, dwb_dat_wr, dwb_sel);
            else
                $display("T=%0t  DATA READ:  addr=0x%08h", $time, dwb_adr);
        end
    end

    // Test stimulus
    initial begin
        $dumpfile("tb_riscv_core.vcd");
        $dumpvars(0, tb_riscv_core);

        rst_n = 0;
        #100;
        rst_n = 1;

        // Let the CPU run for some cycles
        #2000;

        // Check that x3 got the right value
        if (uut.regfile[3] == 32'd52)
            $display("PASS: x3 = %0d (expected 52)", uut.regfile[3]);
        else
            $display("FAIL: x3 = %0d (expected 52)", uut.regfile[3]);

        $display("x1=%0d x2=%0d x3=%0d x4=0x%08h",
                 uut.regfile[1], uut.regfile[2], uut.regfile[3], uut.regfile[4]);

        $display("=== RISC-V Core testbench complete ===");
        $finish;
    end

endmodule

// =============================================================================
// RISC-V RV32I Soft-Core Processor
// Target: Xilinx Artix-7 (Nexys A7-100T)
// Description: 3-stage pipelined RV32I core (Fetch, Decode/Execute, Writeback)
//              with Wishbone B4 bus interface.
// =============================================================================
`timescale 1ns / 1ps
`default_nettype none

module riscv_core #(
    parameter RESET_ADDR = 32'h0000_0000
)(
    input  wire        clk,
    input  wire        rst_n,

    // Wishbone Master – Instruction Fetch
    output reg  [31:0] iwb_adr_o,
    input  wire [31:0] iwb_dat_i,
    output wire        iwb_cyc_o,
    output wire        iwb_stb_o,
    input  wire        iwb_ack_i,

    // Wishbone Master – Data Load/Store
    output reg  [31:0] dwb_adr_o,
    output reg  [31:0] dwb_dat_o,
    input  wire [31:0] dwb_dat_i,
    output reg  [ 3:0] dwb_sel_o,
    output reg         dwb_we_o,
    output wire        dwb_cyc_o,
    output wire        dwb_stb_o,
    input  wire        dwb_ack_i,

    // Interrupt interface
    input  wire        irq_external,
    input  wire        irq_timer
);

    // =========================================================================
    // Pipeline State
    // =========================================================================
    localparam S_FETCH   = 2'd0,
               S_EXEC    = 2'd1,
               S_MEM     = 2'd2,
               S_WB      = 2'd3;

    reg [1:0] state, state_next;

    // Program Counter
    reg  [31:0] pc, pc_next;
    reg  [31:0] instruction;

    // Register File
    reg  [31:0] regfile [0:31];

    // Decoded fields
    wire [ 6:0] opcode  = instruction[ 6: 0];
    wire [ 4:0] rd      = instruction[11: 7];
    wire [ 2:0] funct3  = instruction[14:12];
    wire [ 4:0] rs1     = instruction[19:15];
    wire [ 4:0] rs2     = instruction[24:20];
    wire [ 6:0] funct7  = instruction[31:25];

    // Immediate generation
    wire [31:0] imm_i = {{20{instruction[31]}}, instruction[31:20]};
    wire [31:0] imm_s = {{20{instruction[31]}}, instruction[31:25], instruction[11:7]};
    wire [31:0] imm_b = {{19{instruction[31]}}, instruction[31], instruction[7],
                          instruction[30:25], instruction[11:8], 1'b0};
    wire [31:0] imm_u = {instruction[31:12], 12'b0};
    wire [31:0] imm_j = {{11{instruction[31]}}, instruction[31], instruction[19:12],
                          instruction[20], instruction[30:21], 1'b0};

    // Source operands
    wire [31:0] rs1_val = (rs1 == 5'd0) ? 32'd0 : regfile[rs1];
    wire [31:0] rs2_val = (rs2 == 5'd0) ? 32'd0 : regfile[rs2];

    // ALU
    reg  [31:0] alu_result;
    wire [31:0] alu_a = rs1_val;
    reg  [31:0] alu_b;
    reg         branch_taken;
    reg  [31:0] wb_data;
    reg         wb_en;

    // Bus request flags
    reg  ifetch_req;
    reg  dmem_req;

    assign iwb_cyc_o = ifetch_req;
    assign iwb_stb_o = ifetch_req;
    assign dwb_cyc_o = dmem_req;
    assign dwb_stb_o = dmem_req;

    // =========================================================================
    // RV32I Opcodes
    // =========================================================================
    localparam OP_LUI    = 7'b0110111,
               OP_AUIPC  = 7'b0010111,
               OP_JAL    = 7'b1101111,
               OP_JALR   = 7'b1100111,
               OP_BRANCH = 7'b1100011,
               OP_LOAD   = 7'b0000011,
               OP_STORE  = 7'b0100011,
               OP_IMM    = 7'b0010011,
               OP_REG    = 7'b0110011,
               OP_FENCE  = 7'b0001111,
               OP_SYSTEM = 7'b1110011;

    // =========================================================================
    // State Machine
    // =========================================================================
    integer i;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state       <= S_FETCH;
            pc          <= RESET_ADDR;
            instruction <= 32'h0000_0013; // NOP (addi x0, x0, 0)
            ifetch_req  <= 1'b0;
            dmem_req    <= 1'b0;
            dwb_we_o    <= 1'b0;
            dwb_adr_o   <= 32'd0;
            dwb_dat_o   <= 32'd0;
            dwb_sel_o   <= 4'b0000;
            iwb_adr_o   <= RESET_ADDR;
            for (i = 0; i < 32; i = i + 1)
                regfile[i] <= 32'd0;
        end else begin
            case (state)
                // ---------------------------------------------------------
                // FETCH: request instruction from memory
                // ---------------------------------------------------------
                S_FETCH: begin
                    iwb_adr_o  <= pc;
                    ifetch_req <= 1'b1;
                    dmem_req   <= 1'b0;
                    if (iwb_ack_i) begin
                        instruction <= iwb_dat_i;
                        ifetch_req  <= 1'b0;
                        state       <= S_EXEC;
                    end
                end

                // ---------------------------------------------------------
                // EXECUTE: decode + ALU + branch resolution
                // ---------------------------------------------------------
                S_EXEC: begin
                    ifetch_req <= 1'b0;
                    wb_en      <= 1'b0;
                    branch_taken <= 1'b0;

                    case (opcode)
                        OP_LUI: begin
                            wb_data <= imm_u;
                            wb_en   <= 1'b1;
                            pc      <= pc + 32'd4;
                            state   <= S_WB;
                        end

                        OP_AUIPC: begin
                            wb_data <= pc + imm_u;
                            wb_en   <= 1'b1;
                            pc      <= pc + 32'd4;
                            state   <= S_WB;
                        end

                        OP_JAL: begin
                            wb_data <= pc + 32'd4;
                            wb_en   <= 1'b1;
                            pc      <= pc + imm_j;
                            state   <= S_WB;
                        end

                        OP_JALR: begin
                            wb_data <= pc + 32'd4;
                            wb_en   <= 1'b1;
                            pc      <= (rs1_val + imm_i) & 32'hFFFF_FFFE;
                            state   <= S_WB;
                        end

                        OP_BRANCH: begin
                            case (funct3)
                                3'b000: branch_taken <= (rs1_val == rs2_val);             // BEQ
                                3'b001: branch_taken <= (rs1_val != rs2_val);             // BNE
                                3'b100: branch_taken <= ($signed(rs1_val) < $signed(rs2_val));  // BLT
                                3'b101: branch_taken <= ($signed(rs1_val) >= $signed(rs2_val)); // BGE
                                3'b110: branch_taken <= (rs1_val < rs2_val);              // BLTU
                                3'b111: branch_taken <= (rs1_val >= rs2_val);             // BGEU
                                default: branch_taken <= 1'b0;
                            endcase
                            state <= S_WB;
                        end

                        OP_LOAD: begin
                            dwb_adr_o <= rs1_val + imm_i;
                            dwb_we_o  <= 1'b0;
                            case (funct3)
                                3'b000: dwb_sel_o <= 4'b0001; // LB
                                3'b001: dwb_sel_o <= 4'b0011; // LH
                                3'b010: dwb_sel_o <= 4'b1111; // LW
                                3'b100: dwb_sel_o <= 4'b0001; // LBU
                                3'b101: dwb_sel_o <= 4'b0011; // LHU
                                default: dwb_sel_o <= 4'b1111;
                            endcase
                            dmem_req <= 1'b1;
                            state    <= S_MEM;
                        end

                        OP_STORE: begin
                            dwb_adr_o <= rs1_val + imm_s;
                            dwb_dat_o <= rs2_val;
                            dwb_we_o  <= 1'b1;
                            case (funct3)
                                3'b000: dwb_sel_o <= 4'b0001; // SB
                                3'b001: dwb_sel_o <= 4'b0011; // SH
                                3'b010: dwb_sel_o <= 4'b1111; // SW
                                default: dwb_sel_o <= 4'b1111;
                            endcase
                            dmem_req <= 1'b1;
                            state    <= S_MEM;
                        end

                        OP_IMM: begin
                            alu_b <= imm_i;
                            case (funct3)
                                3'b000: alu_result <= rs1_val + imm_i;                          // ADDI
                                3'b010: alu_result <= ($signed(rs1_val) < $signed(imm_i)) ? 1 : 0; // SLTI
                                3'b011: alu_result <= (rs1_val < imm_i) ? 1 : 0;                // SLTIU
                                3'b100: alu_result <= rs1_val ^ imm_i;                          // XORI
                                3'b110: alu_result <= rs1_val | imm_i;                          // ORI
                                3'b111: alu_result <= rs1_val & imm_i;                          // ANDI
                                3'b001: alu_result <= rs1_val << rs2;                           // SLLI
                                3'b101: alu_result <= (funct7[5]) ?
                                    ($signed(rs1_val) >>> rs2) :                               // SRAI
                                    (rs1_val >> rs2);                                          // SRLI
                            endcase
                            wb_data <= alu_result;
                            wb_en   <= 1'b1;
                            pc      <= pc + 32'd4;
                            state   <= S_WB;
                        end

                        OP_REG: begin
                            case (funct3)
                                3'b000: alu_result <= (funct7[5]) ? (rs1_val - rs2_val) : (rs1_val + rs2_val);
                                3'b001: alu_result <= rs1_val << rs2_val[4:0];                  // SLL
                                3'b010: alu_result <= ($signed(rs1_val) < $signed(rs2_val)) ? 1 : 0; // SLT
                                3'b011: alu_result <= (rs1_val < rs2_val) ? 1 : 0;              // SLTU
                                3'b100: alu_result <= rs1_val ^ rs2_val;                        // XOR
                                3'b101: alu_result <= (funct7[5]) ?
                                    ($signed(rs1_val) >>> rs2_val[4:0]) :                      // SRA
                                    (rs1_val >> rs2_val[4:0]);                                 // SRL
                                3'b110: alu_result <= rs1_val | rs2_val;                        // OR
                                3'b111: alu_result <= rs1_val & rs2_val;                        // AND
                            endcase
                            wb_data <= alu_result;
                            wb_en   <= 1'b1;
                            pc      <= pc + 32'd4;
                            state   <= S_WB;
                        end

                        OP_FENCE: begin
                            // NOP for single-core
                            pc    <= pc + 32'd4;
                            state <= S_FETCH;
                        end

                        OP_SYSTEM: begin
                            // Minimal CSR support (treated as NOP for now)
                            pc    <= pc + 32'd4;
                            state <= S_FETCH;
                        end

                        default: begin
                            // Illegal instruction – skip
                            pc    <= pc + 32'd4;
                            state <= S_FETCH;
                        end
                    endcase
                end

                // ---------------------------------------------------------
                // MEM: wait for data memory access to complete
                // ---------------------------------------------------------
                S_MEM: begin
                    if (dwb_ack_i) begin
                        dmem_req <= 1'b0;
                        if (!dwb_we_o) begin
                            // Load – sign/zero-extend
                            case (funct3)
                                3'b000: wb_data <= {{24{dwb_dat_i[7]}},  dwb_dat_i[ 7:0]}; // LB
                                3'b001: wb_data <= {{16{dwb_dat_i[15]}}, dwb_dat_i[15:0]}; // LH
                                3'b010: wb_data <= dwb_dat_i;                               // LW
                                3'b100: wb_data <= {24'd0, dwb_dat_i[ 7:0]};               // LBU
                                3'b101: wb_data <= {16'd0, dwb_dat_i[15:0]};               // LHU
                                default: wb_data <= dwb_dat_i;
                            endcase
                            wb_en <= 1'b1;
                        end
                        pc    <= pc + 32'd4;
                        state <= S_WB;
                    end
                end

                // ---------------------------------------------------------
                // WRITEBACK: commit result to register file
                // ---------------------------------------------------------
                S_WB: begin
                    if (opcode == OP_BRANCH) begin
                        pc <= branch_taken ? (pc + imm_b) : (pc + 32'd4);
                    end

                    if (wb_en && (rd != 5'd0)) begin
                        regfile[rd] <= (opcode == OP_IMM || opcode == OP_REG) ? alu_result : wb_data;
                    end
                    state <= S_FETCH;
                end
            endcase
        end
    end

endmodule
`default_nettype wire

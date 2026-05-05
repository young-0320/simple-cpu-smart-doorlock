`timescale 1ns / 1ps
`include "define.vh"

module decoder (
    input  wire [31:0] instruction,
    
    // 명령어 분류 신호
    output reg        is_load,
    output reg        is_store,
    output reg        is_alu_mem,  // ADD, SUB, CMP
    output reg        is_alu_imm,  // LOADI, ADDI, CMPI
    output reg        is_ext,      // SHL, SHR, AND
    output reg        is_jump,     // JMP, JZ, JNZ
    output reg        is_in,
    output reg        is_out,
    
    // ALU 및 플래그 제어 신호
    output reg [2:0]  alu_ctrl,
    output reg        zero_we,
    
    // 분기 제어
    output reg [1:0]  jump_type,
    
    // 피연산자 추출
    output wire [27:0] imm,
    output wire [11:0] addr,
    output wire [3:0]  port,
    output wire [3:0]  funct_bin
);

    wire [3:0] opcode = instruction[31:28];
    
    assign imm       = instruction[27:0];
    assign funct_bin = instruction[27:24];
    assign addr      = instruction[11:0];
    assign port      = instruction[3:0];

    always @(*) begin
        // 기본값 초기화
        is_load    = 1'b0;
        is_store   = 1'b0;
        is_alu_mem = 1'b0;
        is_alu_imm = 1'b0;
        is_ext     = 1'b0;
        is_jump    = 1'b0;
        is_in      = 1'b0;
        is_out     = 1'b0;

        alu_ctrl   = `ALU_PASS;
        zero_we    = 1'b0;
        jump_type  = `JMP_UNCOND;

        case (opcode)
            `OP_LOAD: begin
                is_load = 1'b1;
            end

            `OP_STORE: begin
                is_store = 1'b1;
            end

            `OP_ADD: begin
                is_alu_mem = 1'b1;
                alu_ctrl   = `ALU_ADD;
                zero_we    = 1'b1;
            end

            `OP_SUB: begin
                is_alu_mem = 1'b1;
                alu_ctrl   = `ALU_SUB;
                zero_we    = 1'b1;
            end

            `OP_CMP: begin
                is_alu_mem = 1'b1;
                alu_ctrl   = `ALU_CMP;
                zero_we    = 1'b1;
            end

            `OP_LOADI: begin
                is_alu_imm = 1'b1;
                alu_ctrl   = `ALU_PASS;
                zero_we    = 1'b0;
            end

            `OP_ADDI: begin
                is_alu_imm = 1'b1;
                alu_ctrl   = `ALU_ADD;
                zero_we    = 1'b1;
            end

            `OP_CMPI: begin
                is_alu_imm = 1'b1;
                alu_ctrl   = `ALU_CMP;
                zero_we    = 1'b1;
            end

            `OP_JMP: begin
                is_jump   = 1'b1;
                jump_type = `JMP_UNCOND;
            end

            `OP_JZ: begin
                is_jump   = 1'b1;
                jump_type = `JMP_JZ;
            end

            `OP_JNZ: begin
                is_jump   = 1'b1;
                jump_type = `JMP_JNZ;
            end

            `OP_NOP: begin
                // NOP
            end

            `OP_OUT: begin
                is_out = 1'b1;
            end

            `OP_IN: begin
                is_in = 1'b1;
            end

            `OP_RESV1: begin
                // Reserved: NOP처럼 처리
            end

            `OP_EXT: begin
                case (funct_bin)
                    `EXT_SHL: begin
                        is_ext   = 1'b1;
                        alu_ctrl = `ALU_SHL;
                        zero_we  = 1'b1;
                    end

                    `EXT_SHR: begin
                        is_ext   = 1'b1;
                        alu_ctrl = `ALU_SHR;
                        zero_we  = 1'b1;
                    end

                    `EXT_AND: begin
                        is_ext   = 1'b1;
                        alu_ctrl = `ALU_AND;
                        zero_we  = 1'b1;
                    end

                    default: begin
                        // 정의되지 않은 funct_bin은 NOP처럼 처리
                        is_ext   = 1'b0;
                        alu_ctrl = `ALU_PASS;
                        zero_we  = 1'b0;
                    end
                endcase
            end

            default: begin
                // NOP
            end
        endcase
    end

endmodule
`timescale 1ns / 1ps
`include "define.vh"

module decoder (
    input  wire [31:0] instruction,
    
    // 명령어 분류 신호
    output reg        is_load,
    output reg        is_store,
    output reg        is_alu_mem,  // ADD, SUB, CMP (BRAM 참조)
    output reg        is_alu_imm,  // LOADI, ADDI, CMPI (즉시값)
    output reg        is_jump,     // JMP, JZ, JNZ
    output reg        is_in,
    output reg        is_out,
    
    // ALU 제어 신호
    output reg [2:0]  alu_ctrl,    // 0: ADD, 1: SUB, 2: CMP, 3: PASS_IN
    
    // 분기 제어
    output reg [1:0]  jump_type,   // 0: UNCOND, 1: JZ, 2: JNZ
    
    // 피연산자 추출
    output wire [27:0] imm,        // 28비트 즉시값
    output wire [11:0] addr,       // BRAM/Instruction 주소 (operand[11:0])
    output wire [3:0]  port         // I/O 포트 번호 (operand[3:0])
);

    wire [3:0] opcode = instruction[31:28];
    
    // 피연산자 슬라이싱
    assign imm  = instruction[27:0];
    assign addr = instruction[11:0];
    assign port = instruction[3:0];

    always @(*) begin
        // 기본값 초기화 (Latch 방지)
        is_load    = 1'b0; is_store   = 1'b0; is_alu_mem = 1'b0;
        is_alu_imm = 1'b0; is_jump    = 1'b0; is_in      = 1'b0;
        is_out     = 1'b0; alu_ctrl   = 3'b000; jump_type  = 2'b00;

        case (opcode)
            4'b0000: is_load    = 1'b1;  // LOAD
            4'b0001: is_store   = 1'b1;  // STORE
            4'b0010: begin is_alu_mem = 1'b1; alu_ctrl = 3'd0; end // ADD
            4'b0011: begin is_alu_mem = 1'b1; alu_ctrl = 3'd1; end // SUB
            4'b0100: begin is_alu_mem = 1'b1; alu_ctrl = 3'd2; end // CMP
            
            4'b0101: begin is_alu_imm = 1'b1; alu_ctrl = 3'd3; end // LOADI (Pass immediate to ACC)
            4'b0110: begin is_alu_imm = 1'b1; alu_ctrl = 3'd0; end // ADDI
            4'b0111: begin is_alu_imm = 1'b1; alu_ctrl = 3'd2; end // CMPI
            
            4'b1000: begin is_jump = 1'b1; jump_type = 2'd0; end // JMP
            4'b1001: begin is_jump = 1'b1; jump_type = 2'd1; end // JZ
            4'b1010: begin is_jump = 1'b1; jump_type = 2'd2; end // JNZ
            
            4'b1100: is_out = 1'b1; // OUT
            4'b1101: is_in  = 1'b1; // IN
            
            4'b1011, 4'b1110, 4'b1111: ; // NOP & Reserved
            default: ;
        endcase
    end

endmodule
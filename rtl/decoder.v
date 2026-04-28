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
    
    // ALU 및 플래그 제어 신호
    output reg [2:0]  alu_ctrl,    // 0: ADD, 1: SUB, 2: CMP, 3: PASS_IN
    output reg        zero_we,     // ZERO_FLAG 업데이트 활성화 신호 추가
    
    // 분기 제어
    output reg [1:0]  jump_type,   // 0: UNCOND, 1: JZ, 2: JNZ
    
    // 피연산자 추출
    output wire [27:0] imm,        // 28비트 즉시값
    output wire [11:0] addr,       // BRAM/Instruction 주소 (operand[11:0])
    output wire [3:0]  port         // I/O 포트 번호 (operand[3:0])
);

    wire [3:0] opcode = instruction[31:28];
    
    assign imm  = instruction[27:0];
    assign addr = instruction[11:0];
    assign port = instruction[3:0];

    always @(*) begin
        // 기본값 초기화 (Latch 방지 및 안전 상태 보장)
        is_load    = 1'b0; is_store   = 1'b0; is_alu_mem = 1'b0;
        is_alu_imm = 1'b0; is_jump    = 1'b0; is_in      = 1'b0;
        is_out     = 1'b0; alu_ctrl   = `ALU_PASS; jump_type  = `JMP_UNCOND;
        zero_we    = 1'b0; // 기본적으로 플래그 업데이트를 차단함

        case (opcode)
            `OP_LOAD:  is_load    = 1'b1;  
            `OP_STORE: is_store   = 1'b1;  
            
            // 메모리 참조 연산 (플래그 업데이트 O)
            `OP_ADD:   begin is_alu_mem = 1'b1; alu_ctrl = `ALU_ADD; zero_we = 1'b1; end 
            `OP_SUB:   begin is_alu_mem = 1'b1; alu_ctrl = `ALU_SUB; zero_we = 1'b1; end 
            `OP_CMP:   begin is_alu_mem = 1'b1; alu_ctrl = `ALU_CMP; zero_we = 1'b1; end 
            
            // 즉시값 연산
            `OP_LOADI: begin is_alu_imm = 1'b1; alu_ctrl = `ALU_PASS; end // 플래그 업데이트 안 함
            `OP_ADDI:  begin is_alu_imm = 1'b1; alu_ctrl = `ALU_ADD; zero_we = 1'b1; end 
            `OP_CMPI:  begin is_alu_imm = 1'b1; alu_ctrl = `ALU_CMP; zero_we = 1'b1; end 
            
            // 분기 명령어
            `OP_JMP:   begin is_jump = 1'b1; jump_type = `JMP_UNCOND; end 
            `OP_JZ:    begin is_jump = 1'b1; jump_type = `JMP_JZ; end 
            `OP_JNZ:   begin is_jump = 1'b1; jump_type = `JMP_JNZ; end 
            
            // 입출력
            `OP_OUT:   is_out = 1'b1; 
            `OP_IN:    is_in  = 1'b1; 
            
            // NOP 및 예약어
            `OP_NOP, `OP_RESV1, `OP_RESV2: ; 
            default: ;
        endcase
    end

endmodule
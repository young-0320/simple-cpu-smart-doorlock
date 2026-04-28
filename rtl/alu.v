`timescale 1ns / 1ps

module alu (
    input  wire [31:0] acc_in,
    input  wire [31:0] operand_in,
    input  wire [2:0]  alu_ctrl,

    output reg  [31:0] alu_result,
    output reg         zero_result
);

    always @(*) begin
        alu_result  = acc_in;
        zero_result = 1'b0;

        case (alu_ctrl)
            3'd0: begin
                // ADD
                alu_result  = acc_in + operand_in;
                zero_result = (alu_result == 32'd0);
            end

            3'd1: begin
                // SUB
                alu_result  = acc_in - operand_in;
                zero_result = (alu_result == 32'd0);
            end

            3'd2: begin
                // CMP
                // ACC 값은 바꾸지 않고, 비교 결과만 zero_result로 전달
                alu_result  = acc_in;
                zero_result = (acc_in == operand_in);
            end

            3'd3: begin
                // PASS_IN
                // LOADI, IN 같은 값 전달용
                alu_result  = operand_in;
                zero_result = (operand_in == 32'd0);
            end

            default: begin
                alu_result  = acc_in;
                zero_result = 1'b0;
            end
        endcase
    end

endmodule
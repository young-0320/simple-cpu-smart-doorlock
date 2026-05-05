`timescale 1ns / 1ps
`include "define.vh"

module output_handler (
    input  wire        clk,
    input  wire        reset,

    // CPU 출력 상태 코드
    input  wire [3:0]  out_port,

    // 도어락 제어 (JD10, V18)
    output reg         door_open,

    // 온보드 LED LD0~LD3
    output reg  [3:0]  led
);

    always @(posedge clk) begin
        if (reset) begin
            door_open <= 1'b0;
            led       <= 4'b0000;
        end
        else begin
            case (out_port)
                `OUT_STATE_CLOSED: begin
                    door_open <= 1'b0;
                    led       <= 4'b0000;
                end
                `OUT_STATE_OPEN: begin
                    door_open <= 1'b1;
                    led       <= 4'b1000;  // LD3, JE V18: 열림
                end
                `OUT_STATE_FAIL1: begin
                    door_open <= 1'b0;
                    led       <= 4'b0100;  // LD2: 1회 오답
                end
                `OUT_STATE_FAIL2: begin
                    door_open <= 1'b0;
                    led       <= 4'b0010;  // LD1: 2회 오답
                end
                `OUT_STATE_FAIL3: begin
                    door_open <= 1'b0;
                    led       <= 4'b0001;  // LD0: 잠금
                end
                default: begin
                    door_open <= 1'b0;
                    led       <= 4'b0000;
                end
            endcase
        end
    end

endmodule

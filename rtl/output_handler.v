`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2026/04/29 11:54:35
// Design Name: 
// Module Name: output_handler
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////

`include "define.vh"

module output_handler (
    input  wire        clk,
    input  wire        reset,

    // CPU 출력 상태 코드
    input  wire [3:0]  out_port,

    // 도어락 제어
    output reg         door_open,

    // LED 출력
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
                    led       <= 4'b1000;  // 열림 LED
                end

                `OUT_STATE_FAIL1: begin
                    door_open <= 1'b0;
                    led       <= 4'b0100;  // 1회 오답 LED
                end

                `OUT_STATE_FAIL2: begin
                    door_open <= 1'b0;
                    led       <= 4'b0010;  // 2회 오답 LED
                end

                `OUT_STATE_FAIL3: begin
                    door_open <= 1'b0;
                    led       <= 4'b0001;  // 잠금 LED
                end

                default: begin
                    door_open <= 1'b0;
                    led       <= 4'b0000;
                end
            endcase
        end
    end

endmodule

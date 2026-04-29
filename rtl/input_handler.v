`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2026/04/29 11:53:58
// Design Name: 
// Module Name: input_handler
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

module input_handler (
    input  wire        clk,
    input  wire        reset,

    // PMOD raw 입력 (10비트 one-hot, 0~9)
    input  wire [9:0]  pmod_key,

    // 버튼 raw 입력 (active-high)
    input  wire        btn_input,    // 숫자 확정 (자리 하나 입력)
    input  wire        btn_confirm,  // 전체 비밀번호 확정
    input  wire        btn_cancel,   // 취소
    input  wire        btn_change,   // 비밀번호 변경 모드
    input  wire        btn_master,   // 마스터키

    // CPU in_port
    output wire [8:0]  in_port
);

    // ---------------------------------------------------------
    // 1. 각 버튼 debounce 인스턴스
    // ---------------------------------------------------------

    wire [9:0] key_pulse;   // 숫자 버튼 debounced pulse
    wire [9:0] key_level;   // 숫자 버튼 debounced level (미사용, 참고용)

    wire pulse_input,   level_input;
    wire pulse_confirm, level_confirm;
    wire pulse_cancel,  level_cancel;
    wire pulse_change,  level_change;
    wire pulse_master,  level_master;

    genvar i;
    generate
        for (i = 0; i < 10; i = i + 1) begin : gen_key_dbnc
            debouncer u_key_dbnc (
                .clk       (clk),
                .reset     (reset),
                .btn_in    (pmod_key[i]),
                .btn_level (key_level[i]),
                .btn_pulse (key_pulse[i])
            );
        end
    endgenerate

    debouncer u_dbnc_input (
        .clk       (clk),
        .reset     (reset),
        .btn_in    (btn_input),
        .btn_level (level_input),
        .btn_pulse (pulse_input)
    );

    debouncer u_dbnc_confirm (
        .clk       (clk),
        .reset     (reset),
        .btn_in    (btn_confirm),
        .btn_level (level_confirm),
        .btn_pulse (pulse_confirm)
    );

    debouncer u_dbnc_cancel (
        .clk       (clk),
        .reset     (reset),
        .btn_in    (btn_cancel),
        .btn_level (level_cancel),
        .btn_pulse (pulse_cancel)
    );

    debouncer u_dbnc_change (
        .clk       (clk),
        .reset     (reset),
        .btn_in    (btn_change),
        .btn_level (level_change),
        .btn_pulse (pulse_change)
    );

    debouncer u_dbnc_master (
        .clk       (clk),
        .reset     (reset),
        .btn_in    (btn_master),
        .btn_level (level_master),
        .btn_pulse (pulse_master)
    );

    // ---------------------------------------------------------
    // 2. 10비트 one-hot → 4비트 우선순위 인코더
    //    동시 입력 시 낮은 번호(0) 우선
    //    key_pulse 기준으로 인코딩 (레벨이 아닌 펄스 사용)
    // ---------------------------------------------------------

    reg [3:0] key_num;

    always @(*) begin
        casez (key_pulse)
            10'b??????????1: key_num = 4'd0;
            10'b?????????10: key_num = 4'd1;
            10'b????????100: key_num = 4'd2;
            10'b???????1000: key_num = 4'd3;
            10'b??????10000: key_num = 4'd4;
            10'b?????100000: key_num = 4'd5;
            10'b????1000000: key_num = 4'd6;
            10'b???10000000: key_num = 4'd7;
            10'b??100000000: key_num = 4'd8;
            10'b?1000000000: key_num = 4'd9;
            default:         key_num = 4'd0;
        endcase
    end

    // ---------------------------------------------------------
    // 3. in_port 조합
    //    숫자값은 key_pulse가 하나라도 있을 때만 유효
    //    CPU는 IN 1 (btn_input pulse)을 보고 숫자 읽기 타이밍 판단
    // ---------------------------------------------------------

    assign in_port[3:0] = key_num;
    assign in_port[4]   = pulse_input;
    assign in_port[5]   = pulse_confirm;
    assign in_port[6]   = pulse_cancel;
    assign in_port[7]   = pulse_change;
    assign in_port[8]   = pulse_master;

endmodule
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

    input  wire [9:0]  pmod_key,    // JE/JD 점퍼선
    input  wire        btn_input,   // BTN1 온보드 버튼
    input  wire        btn_confirm, // BTN2 온보드 버튼
    input  wire        btn_cancel,  // BTN3 온보드 버튼
    input  wire        btn_change,  // SW0  온보드 스위치
    input  wire        btn_master,  // SW1  온보드 스위치

    output wire [8:0]  in_port
);

    // ---------------------------------------------------------
    // 1. pmod_key debounce → key_level 사용
    // ---------------------------------------------------------

    wire [9:0] key_level;
    wire [9:0] key_pulse_nc;

    genvar i;
    generate
        for (i = 0; i < 10; i = i + 1) begin : gen_key_dbnc
            debouncer u_key_dbnc (
                .clk       (clk),
                .reset     (reset),
                .btn_in    (pmod_key[i]),
                .btn_level (key_level[i]),
                .btn_pulse (key_pulse_nc[i])
            );
        end
    endgenerate

    // ---------------------------------------------------------
    // 2. 버튼/스위치 debounce → pulse → 래치 SET 트리거
    //    버튼: 누르는 순간 상승 에지
    //    스위치: 올리는 순간 상승 에지
    //    동일한 debouncer로 처리 가능
    // ---------------------------------------------------------

    wire pulse_input,   level_nc_input;
    wire pulse_confirm, level_nc_confirm;
    wire pulse_cancel,  level_nc_cancel;
    wire pulse_change,  level_nc_change;
    wire pulse_master,  level_nc_master;

    debouncer u_dbnc_input (
        .clk       (clk), .reset (reset),
        .btn_in    (btn_input),
        .btn_level (level_nc_input),
        .btn_pulse (pulse_input)
    );
    debouncer u_dbnc_confirm (
        .clk       (clk), .reset (reset),
        .btn_in    (btn_confirm),
        .btn_level (level_nc_confirm),
        .btn_pulse (pulse_confirm)
    );
    debouncer u_dbnc_cancel (
        .clk       (clk), .reset (reset),
        .btn_in    (btn_cancel),
        .btn_level (level_nc_cancel),
        .btn_pulse (pulse_cancel)
    );
    debouncer u_dbnc_change (
        .clk       (clk), .reset (reset),
        .btn_in    (btn_change),
        .btn_level (level_nc_change),
        .btn_pulse (pulse_change)
    );
    debouncer u_dbnc_master (
        .clk       (clk), .reset (reset),
        .btn_in    (btn_master),
        .btn_level (level_nc_master),
        .btn_pulse (pulse_master)
    );

    // ---------------------------------------------------------
    // 3. 10비트 one-hot → 4비트 우선순위 인코더
    //    key_level 기반: 점퍼 꽂혀있는 동안 유효값 유지
    //    동시 입력 시 낮은 번호(0) 우선
    // ---------------------------------------------------------

    reg [3:0] key_num;

    always @(*) begin
        casez (key_level)
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
    // 4. self-clearing 래치
    //    pulse → SET(1), 다음 클럭 자동 CLR(0)
    //    SET과 CLR 동시 → SET 우선 (새 pulse 손실 방지)
    // ---------------------------------------------------------

    reg latch_input;
    reg latch_confirm;
    reg latch_cancel;
    reg latch_change;
    reg latch_master;

    always @(posedge clk) begin
        if (reset) begin
            latch_input   <= 1'b0;
            latch_confirm <= 1'b0;
            latch_cancel  <= 1'b0;
            latch_change  <= 1'b0;
            latch_master  <= 1'b0;
        end
        else begin
            if (pulse_input)        latch_input   <= 1'b1;
            else if (latch_input)   latch_input   <= 1'b0;

            if (pulse_confirm)      latch_confirm <= 1'b1;
            else if (latch_confirm) latch_confirm <= 1'b0;

            if (pulse_cancel)       latch_cancel  <= 1'b1;
            else if (latch_cancel)  latch_cancel  <= 1'b0;

            if (pulse_change)       latch_change  <= 1'b1;
            else if (latch_change)  latch_change  <= 1'b0;

            if (pulse_master)       latch_master  <= 1'b1;
            else if (latch_master)  latch_master  <= 1'b0;
        end
    end

    // ---------------------------------------------------------
    // 5. in_port 출력
    // ---------------------------------------------------------

    assign in_port[3:0] = key_num;
    assign in_port[4]   = latch_input;
    assign in_port[5]   = latch_confirm;
    assign in_port[6]   = latch_cancel;
    assign in_port[7]   = latch_change;
    assign in_port[8]   = latch_master;

endmodule

`timescale 1ns / 1ps
`include "define.vh"

module top_doorlock (
    // 보드 클럭 (Zybo Z7-20, 125MHz, 핀 K17)
    input  wire        clk,

    // 리셋 (BTN0, K18, active-high)
    input  wire        ext_reset,

    // PMOD 숫자 입력 (10비트 one-hot, JE/JD 점퍼선)
    input  wire [9:0]  pmod_key,

    // 입력 버튼 (BTN1~BTN3 온보드 버튼)
    input  wire        btn_input,    // BTN1 P16: 자리 입력 확정
    input  wire        btn_confirm,  // BTN2 K19: 전체 비밀번호 확정
    input  wire        btn_cancel,   // BTN3 Y16: 취소

    // 스위치 (SW0~SW1 온보드 슬라이드 스위치)
    input  wire        btn_change,   // SW0 G15: 비밀번호 변경 모드
    input  wire        btn_master,   // SW1 P15: 마스터키

    // 도어락 출력 (JD10, V18, 외부 LED)
    output wire        door_open,

    // 온보드 LED LD0~LD3
    output wire [3:0]  led

);

    // ---------------------------------------------------------
    // 1. Clocking Wizard
    //    Input:  125MHz (clk)
    //    Output: 10MHz   (clk_cpu)
    // ---------------------------------------------------------

    wire clk_cpu;
    wire clk_locked;

    clk_wiz_0 u_clk_wiz (
        .clk_out1 (clk_cpu),
        .locked   (clk_locked),
        .clk_in1  (clk)
    );

    // ---------------------------------------------------------
    // 2. 시스템 reset
    //    PLL lock 전 또는 ext_reset 시 CPU reset 유지
    // ---------------------------------------------------------

    wire sys_reset;
    assign sys_reset = ext_reset | ~clk_locked;

    // ---------------------------------------------------------
    // 3. clk_enable (상시 1, 추후 저전력 모드 연동 시 수정)
    // ---------------------------------------------------------

    wire clk_enable;
    assign clk_enable = 1'b1;

    // ---------------------------------------------------------
    // 4. BRAM
    //    Single Port RAM, Width=32, Depth=4096
    //    Init File: doorlock.coe
    // ---------------------------------------------------------

    wire [11:0] bram_addr;
    wire [31:0] bram_wdata;
    wire [31:0] bram_rdata;
    wire        bram_we;

    blk_mem_gen_0 u_bram (
        .clka  (clk_cpu),
        .ena   (1'b1),
        .wea   ({bram_we}),
        .addra (bram_addr),
        .dina  (bram_wdata),
        .douta (bram_rdata)
    );

    // ---------------------------------------------------------
    // 5. Input Handler
    // ---------------------------------------------------------

    wire [8:0] in_port;

    input_handler u_input_handler (
        .clk         (clk_cpu),
        .reset       (sys_reset),
        .pmod_key    (pmod_key),
        .btn_input   (btn_input),
        .btn_confirm (btn_confirm),
        .btn_cancel  (btn_cancel),
        .btn_change  (btn_change),
        .btn_master  (btn_master),
        .in_port     (in_port)
    );

    // ---------------------------------------------------------
    // 6. CPU
    // ---------------------------------------------------------

    wire [3:0] out_port;

    top_cpu u_cpu (
        .clk             (clk_cpu),
        .reset           (sys_reset),
        .clk_enable      (clk_enable),
        .bram_rdata      (bram_rdata),
        .bram_addr       (bram_addr),
        .bram_wdata      (bram_wdata),
        .bram_we         (bram_we),
        .in_port         (in_port),
        .out_port        (out_port)
    );

    // ---------------------------------------------------------
    // 7. Output Handler
    // ---------------------------------------------------------

    output_handler u_output_handler (
        .clk       (clk_cpu),
        .reset     (sys_reset),
        .out_port  (out_port),
        .door_open (door_open),
        .led       (led)
    );

endmodule

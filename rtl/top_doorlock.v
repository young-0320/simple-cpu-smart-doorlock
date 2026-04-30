`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2026/04/28 16:24:13
// Design Name: 
// Module Name: top_doorlock
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

module top_doorlock (
    // 보드 클럭 (Zybo Z7-20 기준 125MHz, 핀 K17)
    input  wire        clk,

    // 보드 리셋 버튼 (active-high 가정, XDC에서 확인)
    input  wire        ext_reset,

    // PMOD 숫자 입력 (10비트 one-hot, 0~9)
    input  wire [9:0]  pmod_key,

    // 제어 버튼 (active-high, 디바운스는 input_handler 내부 처리)
    input  wire        btn_input,    // 자리 입력 확정
    input  wire        btn_confirm,  // 전체 비밀번호 확정
    input  wire        btn_cancel,   // 취소
    input  wire        btn_change,   // 비밀번호 변경 모드
    input  wire        btn_master,   // 마스터키

    // 도어락 출력
    output wire        door_open,

    // LED 출력 (4비트)
    output wire [3:0]  led,

    // 디버그 출력 (필요 시 ILA 연결 또는 제거)
    output wire [11:0] pc_debug,
    output wire [31:0] acc_debug,
    output wire        zero_flag_debug,
    output wire [1:0]  state_debug
);

    // ---------------------------------------------------------
    // 1. Clocking Wizard (Vivado IP 인스턴스)
    //    - 인스턴스 이름은 Vivado에서 생성한 IP 이름과 맞출 것
    //    - clk_out1 주파수: define.vh의 CLK_FREQ와 일치해야 함
    //      현재 CLK_FREQ = 10MHz → Clocking Wizard 출력도 10MHz
    // ---------------------------------------------------------

    wire clk_cpu;
    wire clk_locked;

    clk_wiz_0 u_clk_wiz (
        .clk_out1 (clk_cpu),      // 출력 클럭 (10MHz)
        .locked   (clk_locked),    // MMCM lock 완료 신호
        .clk_in1  (clk)    // 보드 입력 클럭 (125MHz)
    );

    // ---------------------------------------------------------
    // 2. 시스템 reset 생성
    //    - MMCM lock 전 또는 ext_reset 시 CPU 리셋 유지
    // ---------------------------------------------------------

    wire sys_reset;
    assign sys_reset = ext_reset | ~clk_locked;

    // ---------------------------------------------------------
    // 3. clk_enable (상시 1 - 추후 저전력 모드 확장 가능)
    //    현재는 항상 동작, 추후 WAIT 명령어 등 연동 시 수정
    // ---------------------------------------------------------

    wire clk_enable;
    assign clk_enable = 1'b1;

    // ---------------------------------------------------------
    // 4. BRAM (Vivado Block Memory Generator IP)
    //    - IP 이름: blk_mem_gen_0 (Vivado에서 생성한 이름과 맞출 것)
    //    - Port 설정: Single Port RAM, Width=32, Depth=4096
    //    - Read Latency: 1 (동기식)
    //    - Init File: doorlock.coe
    // ---------------------------------------------------------

    wire [11:0] bram_addr;
    wire [31:0] bram_wdata;
    wire [31:0] bram_rdata;
    wire        bram_we;

    blk_mem_gen_0 u_bram (
        .clka  (clk_cpu),      // 클럭
        .ena   (1'b1),         // 항상 enable
        .wea   ({bram_we}),      // write enable
        .addra (bram_addr),    // 주소 (12비트)
        .dina  (bram_wdata),   // 쓰기 데이터
        .douta (bram_rdata)    // 읽기 데이터
    );

    // ---------------------------------------------------------
    // 5. Input Handler
    // ---------------------------------------------------------

    wire [8:0] in_port;

    input_handler u_input_handler (
        .clk        (clk_cpu),
        .reset      (sys_reset),
        .pmod_key   (pmod_key),
        .btn_input  (btn_input),
        .btn_confirm(btn_confirm),
        .btn_cancel (btn_cancel),
        .btn_change (btn_change),
        .btn_master (btn_master),
        .in_port    (in_port)
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
        .out_port        (out_port),
        .pc_debug        (pc_debug),
        .acc_debug       (acc_debug),
        .zero_flag_debug (zero_flag_debug),
        .state_debug     (state_debug)
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

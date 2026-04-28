
// Testbench 내부에서 1사이클 읽기 지연을 가지는 동기식 BRAM 모델과 
// 외부 포트 신호를 행동 수준(Behavioral Level)으로 완벽하게 모사(Emulation)해야만 
// 정확한 타이밍 검증이 가능합니다.

`timescale 1ns / 1ps
`include "define.vh"

module tb_top_cpu;

    // =======================================================
    // 1. 신호 선언
    // =======================================================
    reg         clk;
    reg         reset;
    reg         clk_enable;

    wire [31:0] bram_rdata;
    wire [11:0] bram_addr;
    wire [31:0] bram_wdata;
    wire        bram_we;

    reg  [8:0]  in_port;
    wire [3:0]  out_port;

    wire [11:0] pc_debug;
    wire [31:0] acc_debug;
    wire        zero_flag_debug;
    wire [1:0]  state_debug;

    // =======================================================
    // 2. DUT (Device Under Test) 인스턴스화
    // =======================================================
    top_cpu uut (
        .clk             (clk),
        .reset           (reset),
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

    // =======================================================
    // 3. 동기식 BRAM (Synchronous BRAM) 모델링
    // =======================================================
    reg [31:0] memory [0:4095];
    reg [31:0] bram_rdata_reg;

    always @(posedge clk) begin
        if (bram_we) begin
            memory[bram_addr] <= bram_wdata;
        end
        // 1사이클 지연을 발생시키는 Non-blocking 할당
        bram_rdata_reg <= memory[bram_addr]; 
    end
    assign bram_rdata = bram_rdata_reg;

    // =======================================================
    // 4. 클럭 생성 (50MHz 가정)
    // =======================================================
    initial begin
        clk = 0;
        forever #10 clk = ~clk; // 20ns period
    end

    // =======================================================
    // 5. 테스트 시나리오
    // =======================================================
    initial begin
        // 메모리 초기화 (Test Program 주입)
        // [Addr 0] LOADI 5  (0x50000005) -> ACC = 5
        memory[0] = 32'h50000005;
        // [Addr 1] ADDI 2   (0x60000002) -> ACC = 7, ZERO_FLAG = 0
        memory[1] = 32'h60000002;
        // [Addr 2] OUT 0    (0xC0000000) -> OUT_PORT = 7 (ACC[3:0])
        memory[2] = 32'hC0000000;
        // [Addr 3] STORE 10 (0x1000000A) -> BRAM[10] = 7
        memory[3] = 32'h1000000A;
        // [Addr 4] IN 1     (0xD0000001) -> ACC = in_port[4]
        memory[4] = 32'hD0000001;
        // [Addr 5] JMP 5    (0x80000005) -> 무한 루프 대기
        memory[5] = 32'h80000005;

        // 초기 신호 설정
        reset = 1;
        clk_enable = 1;
        in_port = 9'd0;

        #25;
        reset = 0; // 리셋 해제

        // 프로그램 실행 대기 (4 cycle * 4 instructions = 16 cycles 이상)
        #400;

        // IN 명령어 테스트용 입력 핀 인가 (in_port[4] = btn_in = 1)
        in_port[4] = 1'b1;

        #200;
        
        $display("========================================");
        $display("Simulation Finished.");
        $display("Memory[10] (Expected: 7): %d", memory[10]);
        $display("Out Port (Expected: 7): %d", out_port);
        $display("========================================");

        $finish;
    end

    // =======================================================
    // 6. 파형 디버깅을 위한 출력 모니터링
    // =======================================================
    initial begin
        $monitor("Time=%0t | PC=%d | State=%d | ACC=%d | Z_Flag=%b | Out=%d",
                 $time, pc_debug, state_debug, acc_debug, zero_flag_debug, out_port);
    end

endmodule
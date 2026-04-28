// Testbench 내부에서 1사이클 읽기 지연을 가지는 동기식 BRAM 모델과
// 외부 포트 신호를 행동 수준(Behavioral Level)으로 모사하여
// top_cpu의 4-cycle Fetch-Decode-Execute-Increment 동작을 검증한다.

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

    integer i;

    // =======================================================
    // 2. DUT 인스턴스화
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
    // 3. 동기식 BRAM 모델
    // =======================================================
    reg [31:0] memory [0:4095];
    reg [31:0] bram_rdata_reg;

    always @(posedge clk) begin
        if (bram_we) begin
            memory[bram_addr] <= bram_wdata;
        end

        // 동기식 BRAM read: 주소 입력 후 다음 clock에 데이터 출력
        bram_rdata_reg <= memory[bram_addr];
    end

    assign bram_rdata = bram_rdata_reg;

    // =======================================================
    // 4. 클럭 생성
    // =======================================================
    initial begin
        clk = 1'b0;
        forever #10 clk = ~clk; // 20ns period, 50MHz
    end

    // =======================================================
    // 5. 테스트 시나리오
    // =======================================================
    initial begin
        // ---------------------------------------------------
        // 메모리 전체 NOP 초기화
        // ---------------------------------------------------
        for (i = 0; i < 4096; i = i + 1) begin
            memory[i] = 32'hB0000000; // NOP
        end

        // ===================================================
        // Integrated CPU Instruction Test Program
        // ===================================================

        // ---------------------------------------------------
        // 0~3: LOADI + STORE 테스트
        // ---------------------------------------------------
        memory[0]  = 32'h50000005; // LOADI 5      -> ACC = 5
        memory[1]  = 32'h10000064; // STORE 100    -> memory[100] = 5
        memory[2]  = 32'h50000003; // LOADI 3      -> ACC = 3
        memory[3]  = 32'h10000065; // STORE 101    -> memory[101] = 3

        // ---------------------------------------------------
        // 4~8: LOAD + ADD + SUB 테스트
        // ---------------------------------------------------
        memory[4]  = 32'h00000064; // LOAD 100     -> ACC = memory[100] = 5
        memory[5]  = 32'h20000065; // ADD 101      -> ACC = 5 + 3 = 8
        memory[6]  = 32'h10000066; // STORE 102    -> memory[102] = 8
        memory[7]  = 32'h30000064; // SUB 100      -> ACC = 8 - 5 = 3
        memory[8]  = 32'h10000067; // STORE 103    -> memory[103] = 3

        // ---------------------------------------------------
        // 9~15: CMP + JZ 테스트
        // ACC = 3, memory[103] = 3 이므로 ZERO_FLAG = 1
        // JZ가 성공해서 14번 주소로 점프해야 함
        // ---------------------------------------------------
        memory[9]  = 32'h40000067; // CMP 103      -> ZERO_FLAG = 1
        memory[10] = 32'h9000000E; // JZ 14        -> jump success
        memory[11] = 32'h50000063; // LOADI 99     -> 실행되면 안 됨
        memory[12] = 32'h10000068; // STORE 104    -> 실행되면 JZ 실패
        memory[13] = 32'h80000010; // JMP 16       -> skip용
        memory[14] = 32'h50000001; // LOADI 1      -> JZ 성공 경로
        memory[15] = 32'h10000068; // STORE 104    -> memory[104] = 1

        // ---------------------------------------------------
        // 16~22: CMPI + JNZ 테스트
        // ACC = 1, CMPI 2 이므로 ZERO_FLAG = 0
        // JNZ가 성공해서 21번 주소로 점프해야 함
        // ---------------------------------------------------
        memory[16] = 32'h70000002; // CMPI 2       -> ZERO_FLAG = 0
        memory[17] = 32'hA0000015; // JNZ 21       -> jump success
        memory[18] = 32'h50000058; // LOADI 88     -> 실행되면 안 됨
        memory[19] = 32'h10000069; // STORE 105    -> 실행되면 JNZ 실패
        memory[20] = 32'h80000017; // JMP 23       -> skip용
        memory[21] = 32'h50000002; // LOADI 2      -> JNZ 성공 경로
        memory[22] = 32'h10000069; // STORE 105    -> memory[105] = 2

        // ---------------------------------------------------
        // 23~25: IN + OUT 테스트
        // in_port[4] = 1로 설정해두고 IN 1 실행
        // ---------------------------------------------------
        memory[23] = 32'hD0000001; // IN 1         -> ACC = in_port[4]
        memory[24] = 32'h1000006C; // STORE 108    -> memory[108] = input value = 1
        memory[25] = 32'hC0000000; // OUT 0        -> out_port = 1 temporarily

        // ---------------------------------------------------
        // 26~31: JMP 테스트
        // 26번에서 30번으로 점프해야 함
        // 27~28번은 실행되면 안 됨
        // ---------------------------------------------------
        memory[26] = 32'h8000001E; // JMP 30       -> jump success
        memory[27] = 32'h5000000F; // LOADI 15     -> 실행되면 안 됨
        memory[28] = 32'h1000006B; // STORE 107    -> 실행되면 JMP 실패
        memory[29] = 32'h80000020; // JMP 32       -> skip용
        memory[30] = 32'h50000003; // LOADI 3      -> JMP 성공 경로
        memory[31] = 32'h1000006B; // STORE 107    -> memory[107] = 3

        // ---------------------------------------------------
        // 32~38: ADDI + CMPI + OUT + NOP 테스트
        // 최종 ACC = 7, ZERO_FLAG = 1, OUT = 7
        // ---------------------------------------------------
        memory[32] = 32'h50000000; // LOADI 0      -> ACC = 0
        memory[33] = 32'h60000007; // ADDI 7       -> ACC = 7
        memory[34] = 32'h1000006A; // STORE 106    -> memory[106] = 7
        memory[35] = 32'h70000007; // CMPI 7       -> ZERO_FLAG = 1
        memory[36] = 32'hC0000000; // OUT 0        -> out_port = 7
        memory[37] = 32'hB0000000; // NOP
        memory[38] = 32'h80000025; // JMP 37       -> loop

        // ---------------------------------------------------
        // 초기 신호 설정
        // ---------------------------------------------------
        reset      = 1'b1;
        clk_enable = 1'b1;

        in_port    = 9'd0;
        in_port[4] = 1'b1; // IN 1 테스트용 입력 버튼 값

        #25;
        reset = 1'b0;

        // 프로그램 실행 대기
        // 약 30개 instruction * 4 cycle * 20ns = 2400ns 이상 필요
        #3500;

        // ---------------------------------------------------
        // 최종 검증 출력
        // ---------------------------------------------------
        $display("========================================");
        $display("Integrated CPU Test Finished.");
        $display("----------------------------------------");
        $display("memory[100] STORE result    Expected 5  : %d", memory[100]);
        $display("memory[101] STORE result    Expected 3  : %d", memory[101]);
        $display("memory[102] ADD result      Expected 8  : %d", memory[102]);
        $display("memory[103] SUB result      Expected 3  : %d", memory[103]);
        $display("memory[104] JZ result       Expected 1  : %d", memory[104]);
        $display("memory[105] JNZ result      Expected 2  : %d", memory[105]);
        $display("memory[106] ADDI result     Expected 7  : %d", memory[106]);
        $display("memory[107] JMP result      Expected 3  : %d", memory[107]);
        $display("memory[108] IN result       Expected 1  : %d", memory[108]);
        $display("----------------------------------------");
        $display("ACC final                   Expected 7  : %d", acc_debug);
        $display("ZERO_FLAG final             Expected 1  : %b", zero_flag_debug);
        $display("OUT final                   Expected 7  : %d", out_port);
        $display("========================================");

        $finish;
    end

    // =======================================================
    // 6. 파형 디버깅용 모니터링
    // =======================================================
    initial begin
        $monitor("Time=%0t | PC=%d | State=%d | ACC=%d | Z_Flag=%b | Out=%d | BRAM_ADDR=%d | BRAM_WE=%b",
                 $time, pc_debug, state_debug, acc_debug, zero_flag_debug, out_port, bram_addr, bram_we);
    end

endmodule
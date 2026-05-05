`timescale 1ns / 1ps
`include "define.vh"

// ===========================================================================
// tb_top_cpu : top_cpu 통합 검증 테스트벤치
//
// 커버리지
//   Happy Path : LOADI/STORE/LOAD, ADD/SUB/ADDI, CMP/CMPI,
//                JZ(taken), JZ(not-taken), JNZ(taken), JNZ(not-taken), JMP,
//                IN, OUT, SHL, SHR, AND
//   Edge Case  : SHL 0 (no-op), SHR→result=0+ZF검증, AND→result=0+ZF검증,
//                AND→non-zero+ZF=0+JNZ검증, CMPI는 ACC를 보존함,
//                LOAD는 ZERO_FLAG를 바꾸지 않음, NOP, RESV1(1110) NOP처럼 동작
//
// 데이터 영역 : mem[200..230] (코드와 겹치지 않도록 분리)
// BRAM 모델  : 동기식 single-port (주소 설정 후 다음 클럭에 데이터 출력)
// ===========================================================================

module tb_top_cpu;

    // =========================================================================
    // 신호 선언
    // =========================================================================
    reg        clk;
    reg        reset;
    reg        clk_enable;
    reg  [8:0] in_port;

    wire [31:0] bram_rdata;
    wire [11:0] bram_addr;
    wire [31:0] bram_wdata;
    wire        bram_we;
    wire [3:0]  out_port;

    wire [11:0] pc_debug;
    wire [31:0] acc_debug;
    wire        zero_flag_debug;
    wire [1:0]  state_debug;

    integer i;

    // =========================================================================
    // DUT
    // =========================================================================
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

    // =========================================================================
    // 동기식 BRAM 모델
    // 주소 입력 후 다음 클럭에 데이터 출력 (FPGA BRAM 동작과 동일)
    // =========================================================================
    reg [31:0] memory [0:4095];
    reg [31:0] bram_rdata_reg;

    always @(posedge clk) begin
        if (bram_we)
            memory[bram_addr] <= bram_wdata;
        bram_rdata_reg <= memory[bram_addr];
    end

    assign bram_rdata = bram_rdata_reg;

    // =========================================================================
    // 클럭 생성 (50MHz, 20ns period)
    // =========================================================================
    initial clk = 0;
    always  #10 clk = ~clk;

    // =========================================================================
    // 검증 유틸리티
    // =========================================================================
    integer pass_count;
    integer fail_count;

    task check;
        input [511:0] name;
        input [31:0]  got;
        input [31:0]  expected;
        begin
            if (got === expected) begin
                $display("  PASS  %0s", name);
                pass_count = pass_count + 1;
            end else begin
                $display("  FAIL  %0s  got=0x%08X (%0d)  expected=0x%08X (%0d)",
                         name, got, got, expected, expected);
                fail_count = fail_count + 1;
            end
        end
    endtask

    // =========================================================================
    // 메모리 초기화 및 테스트 프로그램
    //
    // 명령어 인코딩 규칙:
    //   M-type (LOAD/STORE/ADD/SUB/CMP/AND) : opcode[31:28] + 0[27:12] + addr[11:0]
    //   I-type (LOADI/ADDI/CMPI)            : opcode[31:28] + imm[27:0]
    //   J-type (JMP/JZ/JNZ)                 : opcode[31:28] + 0[27:12] + addr[11:0]
    //   P-type (IN/OUT)                      : opcode[31:28] + 0[27:4] + port[3:0]
    //   EXT    (SHL/SHR/AND)                 : 1111[31:28] + funct[27:24] + 0[23:12] + addr[11:0]
    //
    // 데이터 주소 맵:
    //   200(0xC8) LOADI/STORE/LOAD temp A
    //   201(0xC9) LOADI/STORE/LOAD temp B
    //   202(0xCA) ADD result
    //   203(0xCB) SUB result
    //   204(0xCC) ADDI result
    //   205(0xCD) CMPI/CMP: ACC 보존 확인
    //   206(0xCE) JZ taken 마크
    //   207(0xCF) JZ not-taken 마크
    //   208(0xD0) JNZ taken 마크
    //   209(0xD1) JNZ not-taken 마크
    //   210(0xD2) IN 결과
    //   211(0xD3) SHL happy 결과
    //   212(0xD4) SHR happy 결과
    //   213(0xD5) AND happy mask
    //   214(0xD6) AND happy 결과
    //   215(0xD7) SHL 0 결과
    //   216(0xD8) SHR→0 결과
    //   217(0xD9) SHR ZF=1 JZ taken 마크
    //   218(0xDA) AND→0 mask
    //   219(0xDB) AND→0 결과
    //   220(0xDC) AND ZF=1 JZ taken 마크
    //   221(0xDD) AND non-zero mask
    //   222(0xDE) AND non-zero 결과
    //   223(0xDF) CMPI ACC 보존 확인
    //   224(0xE0) LOAD ZF 보존 확인
    //   225(0xE1) NOP ACC 보존 확인
    //   226(0xE2) RESV1 ACC 보존 확인
    // =========================================================================

    initial begin
        // 코드 영역 NOP 초기화, 데이터 영역 0 초기화
        for (i = 0; i < 128; i = i + 1) memory[i] = 32'hB0000000; // NOP
        for (i = 128; i < 4096; i = i + 1) memory[i] = 32'h00000000;

        // -----------------------------------------------------------------
        // SECTION 1: LOADI / STORE / LOAD
        // -----------------------------------------------------------------
        memory[0]  = 32'h50000005; // LOADI 5        ACC=5
        memory[1]  = 32'h100000C8; // STORE 200      mem[200]=5
        memory[2]  = 32'h50000003; // LOADI 3        ACC=3
        memory[3]  = 32'h100000C9; // STORE 201      mem[201]=3
        memory[4]  = 32'h000000C8; // LOAD 200       ACC=5

        // -----------------------------------------------------------------
        // SECTION 2: ADD / SUB
        // -----------------------------------------------------------------
        memory[5]  = 32'h200000C9; // ADD 201        ACC=5+3=8, ZF=0
        memory[6]  = 32'h100000CA; // STORE 202      mem[202]=8
        memory[7]  = 32'h300000C9; // SUB 201        ACC=8-3=5, ZF=0
        memory[8]  = 32'h100000CB; // STORE 203      mem[203]=5

        // -----------------------------------------------------------------
        // SECTION 3: ADDI
        // -----------------------------------------------------------------
        memory[9]  = 32'h60000005; // ADDI 5         ACC=5+5=10
        memory[10] = 32'h100000CC; // STORE 204      mem[204]=10

        // -----------------------------------------------------------------
        // SECTION 4: CMP / CMPI (ACC 보존 및 ZF 동작 확인)
        // -----------------------------------------------------------------
        memory[11] = 32'h5000000F; // LOADI 15       ACC=15
        memory[12] = 32'h7000000F; // CMPI 15        ZF=1, ACC=15 보존
        memory[13] = 32'h100000CD; // STORE 205      mem[205]=15 (ACC 보존 확인)
        memory[14] = 32'h70000063; // CMPI 99        ZF=0 (15≠99)
        memory[15] = 32'h400000CD; // CMP 205        ZF=1 (15==15)

        // -----------------------------------------------------------------
        // SECTION 5a: JZ taken (ZF=1)
        // -----------------------------------------------------------------
        memory[16] = 32'h90000013; // JZ 19          ZF=1 → jump taken
        memory[17] = 32'h500000FF; //   [TRAP] LOADI 0xFF
        memory[18] = 32'h80000061; //   [TRAP] JMP 97 (halt)
        memory[19] = 32'h50000001; // LOADI 1
        memory[20] = 32'h100000CE; // STORE 206      mem[206]=1

        // -----------------------------------------------------------------
        // SECTION 5b: JZ not-taken (ZF=0)
        // -----------------------------------------------------------------
        memory[21] = 32'h70000063; // CMPI 99        ACC=1, ZF=0
        memory[22] = 32'h9000001A; // JZ 26          ZF=0 → NOT taken
        memory[23] = 32'h50000002; // LOADI 2
        memory[24] = 32'h100000CF; // STORE 207      mem[207]=2
        memory[25] = 32'h8000001B; // JMP 27
        memory[26] = 32'h500000FF; //   [TRAP] LOADI 0xFF

        // -----------------------------------------------------------------
        // SECTION 6a: JNZ taken (ZF=0, ZF는 CMPI 99에서 유지됨)
        // -----------------------------------------------------------------
        memory[27] = 32'hA000001E; // JNZ 30         ZF=0 → jump taken
        memory[28] = 32'h500000EE; //   [TRAP] LOADI 0xEE
        memory[29] = 32'h80000061; //   [TRAP] JMP 97 (halt)
        memory[30] = 32'h50000003; // LOADI 3
        memory[31] = 32'h100000D0; // STORE 208      mem[208]=3

        // -----------------------------------------------------------------
        // SECTION 6b: JNZ not-taken (ZF=1)
        // -----------------------------------------------------------------
        memory[32] = 32'h70000003; // CMPI 3         ACC=3, ZF=1
        memory[33] = 32'hA0000025; // JNZ 37         ZF=1 → NOT taken
        memory[34] = 32'h50000004; // LOADI 4
        memory[35] = 32'h100000D1; // STORE 209      mem[209]=4
        memory[36] = 32'h80000026; // JMP 38
        memory[37] = 32'h500000EE; //   [TRAP] LOADI 0xEE

        // -----------------------------------------------------------------
        // SECTION 7: JMP unconditional
        // (이후 섹션이 정상 동작하면 JMP가 올바르게 동작한 것)
        // -----------------------------------------------------------------
        memory[38] = 32'h80000029; // JMP 41
        memory[39] = 32'h500000DD; //   [TRAP] LOADI 0xDD
        memory[40] = 32'h80000061; //   [TRAP] JMP 97 (halt)
        memory[41] = 32'h50000005; // LOADI 5        ACC=5

        // -----------------------------------------------------------------
        // SECTION 8: IN / OUT
        // in_port[3:0]=7로 고정 (TB 초기화에서 설정)
        // -----------------------------------------------------------------
        memory[42] = 32'hD0000000; // IN 0           ACC=in_port[3:0]=7
        memory[43] = 32'h100000D2; // STORE 210      mem[210]=7
        memory[44] = 32'hC0000000; // OUT 0          out_port=7

        // -----------------------------------------------------------------
        // SECTION 9: SHL happy path
        // SHL 4: ACC=0x05 << 4 = 0x50
        // -----------------------------------------------------------------
        memory[45] = 32'h50000005; // LOADI 5        ACC=0x05
        memory[46] = 32'hF0000004; // SHL 4          ACC=0x50, ZF=0
        memory[47] = 32'h100000D3; // STORE 211      mem[211]=0x50

        // -----------------------------------------------------------------
        // SECTION 10: SHR happy path
        // SHR 4: ACC=0x50 >> 4 = 0x05
        // -----------------------------------------------------------------
        memory[48] = 32'h50000050; // LOADI 0x50     ACC=0x50
        memory[49] = 32'hF1000004; // SHR 4          ACC=0x05, ZF=0
        memory[50] = 32'h100000D4; // STORE 212      mem[212]=5

        // -----------------------------------------------------------------
        // SECTION 11: AND happy path
        // ACC=0xAB, mask=0x0F → 0xAB & 0x0F = 0x0B
        // -----------------------------------------------------------------
        memory[51] = 32'h5000000F; // LOADI 0x0F     ACC=0x0F (mask)
        memory[52] = 32'h100000D5; // STORE 213      mem[213]=0x0F
        memory[53] = 32'h500000AB; // LOADI 0xAB     ACC=0xAB
        memory[54] = 32'hF20000D5; // AND 213        ACC=0xAB&0x0F=0x0B, ZF=0
        memory[55] = 32'h100000D6; // STORE 214      mem[214]=0x0B

        // -----------------------------------------------------------------
        // SECTION 12: Edge - SHL 0 (시프트 없음, ACC 무변화)
        // -----------------------------------------------------------------
        memory[56] = 32'h50000007; // LOADI 7        ACC=7
        memory[57] = 32'hF0000000; // SHL 0          ACC=7 (no-op)
        memory[58] = 32'h100000D7; // STORE 215      mem[215]=7

        // -----------------------------------------------------------------
        // SECTION 13: Edge - SHR 결과=0, ZF=1 → JZ로 검증
        // 1 >> 4 = 0, ZF=1
        // -----------------------------------------------------------------
        memory[59] = 32'h50000001; // LOADI 1        ACC=1
        memory[60] = 32'hF1000004; // SHR 4          ACC=0, ZF=1
        memory[61] = 32'h100000D8; // STORE 216      mem[216]=0
        memory[62] = 32'h90000040; // JZ 64          ZF=1 → taken (SHR이 ZF 갱신했는지 검증)
        memory[63] = 32'h500000BB; //   [TRAP] LOADI 0xBB
        memory[64] = 32'h50000001; // LOADI 1        (JZ 도착)
        memory[65] = 32'h100000D9; // STORE 217      mem[217]=1

        // -----------------------------------------------------------------
        // SECTION 14: Edge - AND 결과=0, ZF=1 → JZ로 검증
        // 0x0F & 0xF0 = 0, ZF=1
        // -----------------------------------------------------------------
        memory[66] = 32'h500000F0; // LOADI 0xF0
        memory[67] = 32'h100000DA; // STORE 218      mem[218]=0xF0
        memory[68] = 32'h5000000F; // LOADI 0x0F
        memory[69] = 32'hF20000DA; // AND 218        ACC=0x0F&0xF0=0, ZF=1
        memory[70] = 32'h100000DB; // STORE 219      mem[219]=0
        memory[71] = 32'h90000049; // JZ 73          ZF=1 → taken
        memory[72] = 32'h500000BB; //   [TRAP] LOADI 0xBB
        memory[73] = 32'h50000001; // LOADI 1        (JZ 도착)
        memory[74] = 32'h100000DC; // STORE 220      mem[220]=1

        // -----------------------------------------------------------------
        // SECTION 15: Edge - AND 결과 non-zero, ZF=0 → JNZ로 검증
        // 0xAB & 0xFF = 0xAB, ZF=0
        // -----------------------------------------------------------------
        memory[75] = 32'h500000FF; // LOADI 0xFF
        memory[76] = 32'h100000DD; // STORE 221      mem[221]=0xFF
        memory[77] = 32'h500000AB; // LOADI 0xAB
        memory[78] = 32'hF20000DD; // AND 221        ACC=0xAB&0xFF=0xAB, ZF=0
        memory[79] = 32'hA0000051; // JNZ 81         ZF=0 → taken
        memory[80] = 32'h500000BB; //   [TRAP] LOADI 0xBB
        memory[81] = 32'h100000DE; // STORE 222      mem[222]=0xAB  (JNZ 도착)

        // -----------------------------------------------------------------
        // SECTION 16: Edge - CMPI는 ACC를 보존함
        // LOADI 42, CMPI 99 → ZF=0, ACC는 여전히 42
        // -----------------------------------------------------------------
        memory[82] = 32'h5000002A; // LOADI 42       ACC=42
        memory[83] = 32'h70000063; // CMPI 99        ZF=0, ACC=42 (보존)
        memory[84] = 32'h100000DF; // STORE 223      mem[223]=42

        // -----------------------------------------------------------------
        // SECTION 17: Edge - LOAD는 ZERO_FLAG를 변경하지 않음
        // CMPI 42 → ZF=1, 이후 LOAD → ACC 바뀌지만 ZF=1 유지
        // -----------------------------------------------------------------
        memory[85] = 32'h7000002A; // CMPI 42        ACC=42, ZF=1
        memory[86] = 32'h000000C9; // LOAD 201       ACC=3, ZF는 1 그대로
        memory[87] = 32'h90000059; // JZ 89          ZF=1 → taken (LOAD가 ZF 안 건드렸으면)
        memory[88] = 32'h500000CC; //   [TRAP] LOADI 0xCC
        memory[89] = 32'h50000001; // LOADI 1        (JZ 도착)
        memory[90] = 32'h100000E0; // STORE 224      mem[224]=1

        // -----------------------------------------------------------------
        // SECTION 18: Edge - NOP은 ACC를 보존함
        // -----------------------------------------------------------------
        memory[91] = 32'h5000004D; // LOADI 77       ACC=77
        memory[92] = 32'hB0000000; // NOP
        memory[93] = 32'h100000E1; // STORE 225      mem[225]=77

        // -----------------------------------------------------------------
        // SECTION 19: Edge - RESV1(1110)은 NOP처럼 동작 (ACC 보존)
        // -----------------------------------------------------------------
        memory[94] = 32'h50000058; // LOADI 88       ACC=88
        memory[95] = 32'hE0000000; // RESV1 0        NOP처럼 → ACC=88 유지
        memory[96] = 32'h100000E2; // STORE 226      mem[226]=88

        // -----------------------------------------------------------------
        // HALT
        // -----------------------------------------------------------------
        memory[97] = 32'h80000061; // JMP 97         무한루프 (halt)

        // =========================================================================
        // 리셋 및 초기화
        // =========================================================================
        pass_count = 0;
        fail_count = 0;

        reset      = 1'b1;
        clk_enable = 1'b1;
        in_port    = 9'b0_0000_0111; // in_port[3:0]=7, 버튼 비활성

        @(posedge clk); #1;
        @(posedge clk); #1;
        reset = 1'b0;

        // 전체 프로그램 완료 대기
        // 97 instructions × 4 cycle × 20ns ≈ 7760ns → 여유있게 15000ns
        #15000;

        // =========================================================================
        // 검증
        // =========================================================================
        $display("");
        $display("=======================================================");
        $display("  CPU Testbench  Young");
        $display("=======================================================");

        $display("[SEC 1] LOADI / STORE / LOAD");
        check("mem[200] = 5",                       memory[200], 32'd5);
        check("mem[201] = 3",                       memory[201], 32'd3);

        $display("[SEC 2] ADD / SUB");
        check("ADD: mem[202] = 8",                  memory[202], 32'd8);
        check("SUB: mem[203] = 5",                  memory[203], 32'd5);

        $display("[SEC 3] ADDI");
        check("ADDI: mem[204] = 10",                memory[204], 32'd10);

        $display("[SEC 4] CMPI ACC 보존");
        check("CMPI ACC preserved: mem[205] = 15",  memory[205], 32'd15);

        $display("[SEC 5] JZ");
        check("JZ taken:     mem[206] = 1",         memory[206], 32'd1);
        check("JZ not-taken: mem[207] = 2",         memory[207], 32'd2);

        $display("[SEC 6] JNZ");
        check("JNZ taken:     mem[208] = 3",        memory[208], 32'd3);
        check("JNZ not-taken: mem[209] = 4",        memory[209], 32'd4);

        $display("[SEC 7] JMP  (이후 섹션 통과로 간접 검증)");

        $display("[SEC 8] IN / OUT");
        check("IN 0:  mem[210] = 7",                memory[210], 32'd7);
        check("OUT 0: out_port = 7",                {28'd0, out_port}, 32'd7);

        $display("[SEC 9] SHL happy (0x05 << 4 = 0x50)");
        check("SHL 4: mem[211] = 0x50",             memory[211], 32'h50);

        $display("[SEC 10] SHR happy (0x50 >> 4 = 0x05)");
        check("SHR 4: mem[212] = 0x05",             memory[212], 32'h05);

        $display("[SEC 11] AND happy (0xAB & 0x0F = 0x0B)");
        check("AND: mem[214] = 0x0B",               memory[214], 32'h0B);

        $display("[SEC 12] Edge: SHL 0 (no-op)");
        check("SHL 0: mem[215] = 7",                memory[215], 32'd7);

        $display("[SEC 13] Edge: SHR -> 0, ZF=1");
        check("SHR result: mem[216] = 0",           memory[216], 32'd0);
        check("SHR ZF=1 (JZ taken): mem[217] = 1",  memory[217], 32'd1);

        $display("[SEC 14] Edge: AND -> 0, ZF=1");
        check("AND result zero: mem[219] = 0",      memory[219], 32'd0);
        check("AND ZF=1 (JZ taken): mem[220] = 1",  memory[220], 32'd1);

        $display("[SEC 15] Edge: AND non-zero, ZF=0, JNZ taken");
        check("AND non-zero: mem[222] = 0xAB",      memory[222], 32'hAB);

        $display("[SEC 16] Edge: CMPI는 ACC를 변경하지 않음");
        check("CMPI ACC=42: mem[223] = 42",         memory[223], 32'd42);

        $display("[SEC 17] Edge: LOAD는 ZERO_FLAG를 변경하지 않음");
        check("LOAD ZF preserved (JZ taken): mem[224] = 1", memory[224], 32'd1);

        $display("[SEC 18] Edge: NOP은 ACC를 보존함");
        check("NOP: mem[225] = 77",                 memory[225], 32'd77);

        $display("[SEC 19] Edge: RESV1(1110)은 NOP처럼 동작");
        check("RESV1: mem[226] = 88",               memory[226], 32'd88);

        $display("-------------------------------------------------------");
        $display("  PASS: %0d  FAIL: %0d  TOTAL: %0d",
                 pass_count, fail_count, pass_count + fail_count);
        $display("=======================================================");
        $display("");

        $finish;
    end

endmodule

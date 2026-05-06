# III. Module 및 IP 구성

## 3-1. CPU

### 1) cpu_fsm.v

cpu_fsm 모듈은 CPU의 명령어 실행 주기를 4단계로 제어하는 유한 상태 기계(FSM)이다. `clk_enable` 신호로 일시정지가 가능하며, 현재 상태(`state`)를 나머지 모든 모듈이 공유한다.

**FSM 전이 구조**

```
FETCH → DECODE → EXECUTE → INCREMENT → FETCH → ...
```

상태는 매 클럭 상승 에지에서 순환 전이하며, `reset` 시 FETCH로 복귀한다. `clk_enable`이 비활성화된 동안에는 현재 상태를 유지함으로써 전체 CPU를 일시 정지시킨다.

```verilog
else if (clk_enable) begin
    case (state)
        FETCH:     state <= DECODE;
        DECODE:    state <= EXECUTE;
        EXECUTE:   state <= INCREMENT;
        INCREMENT: state <= FETCH;
        default:   state <= FETCH;
    endcase
end
```

각 상태의 역할은 다음과 같다.

| 상태 | 역할 |
|---|---|
| `FETCH` | `bram_addr ← pc_out`, BRAM에서 명령어 읽기 시작 |
| `DECODE` | BRAM 출력을 IR에 래치, decoder 조합 논리 확정 |
| `EXECUTE` | 메모리·I/O 명령어의 BRAM 주소 전환, STORE 실행 |
| `INCREMENT` | ACC·ZERO_FLAG·OUT_PORT 갱신, PC 증가 |

---

### 2) pc.v

pc 모듈은 다음에 실행할 명령어의 BRAM 주소를 보관하는 12비트 프로그램 카운터이다. top_cpu에서 분기 로직이 계산한 `pc_next` 값을 받아 INCREMENT 상태에서만 갱신된다.

```verilog
assign pc_write = (state == `ST_INCREMENT);
```

`pc_write`와 `clk_enable`이 동시에 활성화된 클럭 상승 에지에서만 `pc_out ← pc_next`가 일어난다. 그 외 상태에서는 현재 값을 유지하여 FETCH 단계에서 동일한 주소로 BRAM을 읽을 수 있도록 한다.

```verilog
else if (clk_enable && pc_write) begin
    pc_out <= pc_next;
end
```

`reset` 시 `pc_out`은 0으로 초기화되어 BRAM 주소 0번지(프로그램 시작점)부터 실행이 재개된다.

---

### 3) inst_reg.v

inst_reg 모듈은 BRAM에서 읽어온 32비트 명령어를 한 사이클 래치하는 명령어 레지스터이다. FETCH 단계에서 BRAM 출력이 안정화된 후, DECODE 상태 진입 시 `ir_we`가 활성화되어 명령어를 캡처한다.

```verilog
assign ir_we = clk_enable && (state == `ST_DECODE);
```

이후 EXECUTE·INCREMENT 단계 내내 `instr_out`이 고정된 상태로 decoder에 공급되므로, FSM이 다음 상태로 전이하는 동안 제어 신호가 흔들리지 않는다.

```verilog
else if (ir_we) begin
    instr_out <= instr_in;
end
```

`reset` 시 `instr_out`은 `32'hB0000000`으로 초기화된다. 상위 4비트 `4'b1011`은 `OP_NOP`에 해당하여, 리셋 직후 의도치 않은 연산이 실행되는 것을 방지한다.

---

### 4) decoder.v

decoder 모듈은 32비트 명령어를 해석하여 CPU 전체의 데이터패스 제어 신호를 생성하는 순수 조합 논리 블록이다. 클럭이 없으며, inst_reg의 `instr_out`이 변경되는 즉시 출력이 갱신된다.

**필드 분리**

```verilog
wire [3:0] opcode = instruction[31:28];
wire [3:0] funct  = instruction[27:24];  // OP_EXT 전용

assign imm  = instruction[27:0];   // 28비트 즉시값
assign addr = instruction[11:0];   // BRAM/분기 주소
assign port = instruction[3:0];    // I/O 포트 번호
```

**1단계 — opcode 디코딩**

`case (opcode)` 블록에서 16개의 opcode를 분류하여 명령어 종류 플래그(`is_load`, `is_store`, `is_alu_mem`, `is_alu_imm`, `is_ext_imm`, `is_jump`, `is_in`, `is_out`)와 ALU 연산 코드(`alu_ctrl`), zero 플래그 갱신 여부(`zero_we`), 분기 종류(`jump_type`)를 결정한다.

**2단계 — OP_EXT 추가 디코딩**

opcode가 `4'b1111`(`OP_EXT`)인 경우 `funct[27:24]`를 기준으로 2차 디코딩을 수행한다.

```verilog
`OP_EXT: begin
    case (funct)
        `EXT_SHL: begin is_ext_imm = 1'b1; alu_ctrl = `ALU_SHL; zero_we = 1'b1; end
        `EXT_SHR: begin is_ext_imm = 1'b1; alu_ctrl = `ALU_SHR; zero_we = 1'b1; end
        `EXT_AND: begin is_alu_mem = 1'b1; alu_ctrl = `ALU_AND; zero_we = 1'b1; end
        default: ;
    endcase
end
```

래치 생성을 방지하기 위해 `always @(*)` 블록 최상단에서 모든 출력 신호를 안전 기본값으로 초기화한 후 case 문을 실행한다.

---

### 5) accumulator.v

accumulator 모듈은 CPU의 유일한 범용 레지스터인 32비트 누산기(ACC)이다. 연산 결과, LOAD 데이터, IN 포트 값 등 다양한 소스가 top_cpu의 MUX를 거쳐 `acc_in`으로 입력되며, `acc_we`가 활성화된 클럭 상승 에지에서 저장된다.

```verilog
else if (acc_we) begin
    acc_out <= acc_in;
end
```

`acc_we` 활성화 조건은 top_cpu의 조합 논리에서 결정되며, INCREMENT 상태에서만 갱신된다. CMP 명령어는 `zero_flag`만 갱신하고 ACC를 변경하지 않으므로 `acc_we`를 활성화하지 않는다.

```verilog
if (is_alu_imm || is_alu_mem || is_ext_imm) begin
    if (alu_ctrl != `ALU_CMP) begin
        acc_in = alu_result;
        acc_we = 1'b1;
    end
end
```

---

### 6) alu.v

alu 모듈은 `acc_out`과 `operand_in`을 받아 7가지 연산을 수행하는 순수 조합 논리 블록이다. `alu_ctrl`에 따라 `alu_result`와 zero 플래그(`zero_result`)를 즉시 출력한다. top_cpu에서 `alu_operand` MUX를 통해 피연산자 소스(즉시값·시프트량·BRAM 데이터)가 선택된 후 `operand_in`으로 전달된다.

```verilog
assign alu_operand = is_alu_imm ? {4'b0000, imm}  :
                     is_ext_imm ? {20'b0, addr}    :
                                  bram_rdata;
```

지원 연산은 다음과 같다.

| `alu_ctrl` | 연산 | `zero_result` 조건 |
|---|---|---|
| `ALU_ADD` | `acc + operand` | 결과 == 0 |
| `ALU_SUB` | `acc − operand` | 결과 == 0 |
| `ALU_CMP` | acc 변경 없음 | `acc == operand` |
| `ALU_PASS` | `operand` | `operand == 0` |
| `ALU_SHL` | `acc << operand[4:0]` | 결과 == 0 |
| `ALU_SHR` | `acc >> operand[4:0]` | 결과 == 0 |
| `ALU_AND` | `acc & operand` | 결과 == 0 |

CMP는 acc를 그대로 통과시키되 두 값이 같을 때 `zero_result`를 1로 설정하여, 후속 JZ/JNZ 분기의 기준 플래그로 활용된다.

---

### 7) top_cpu.v

top_cpu 모듈은 cpu_fsm, pc, inst_reg, decoder, accumulator, alu 여섯 서브모듈을 통합하는 CPU 최상위 모듈이다. BRAM 인터페이스, 9비트 입력 포트, 4비트 출력 포트, 디버그 출력을 외부에 노출한다.

**데이터패스 전체 흐름**

```
FETCH     : bram_addr ← pc_out  →  BRAM 명령어 출력 대기
DECODE    : ir_we 활성화  →  instr_out ← bram_rdata  →  decoder 신호 확정
EXECUTE   : 메모리/I/O 명령어: bram_addr ← addr, STORE: bram_we 활성화
INCREMENT : ACC·ZERO_FLAG·OUT_PORT 갱신, PC ← pc_next
```

**1단계 — BRAM 주소 및 쓰기 제어**

FETCH·DECODE·INCREMENT에서는 `bram_addr = pc_out`(명령어 페치). EXECUTE에서는 LOAD·STORE·ALU_MEM 명령어일 때 `bram_addr = addr`로 전환하여 데이터 영역에 접근한다.

```verilog
`ST_EXECUTE: begin
    if (is_load || is_store || is_alu_mem)
        bram_addr = addr;
    if (is_store)
        bram_we = clk_enable;
end
```

**2단계 — ACC 및 ZERO_FLAG 갱신**

INCREMENT 상태에서 명령어 종류에 따라 `acc_in` 소스와 `acc_we`를 결정한다.

```verilog
if (is_load)                                   { acc_in = bram_rdata;    acc_we = 1; }
else if (is_in)                                { acc_in = selected_input; acc_we = 1; }
else if (is_alu_imm || is_alu_mem || is_ext_imm)
    if (alu_ctrl != `ALU_CMP)                 { acc_in = alu_result;    acc_we = 1; }
```

`zero_flag`는 `zero_we`가 활성화된 연산에서만 `alu_zero_result`로 갱신된다.

**3단계 — PC next 로직**

기본값은 `pc_out + 1`이며, `is_jump`가 활성화된 경우 `jump_type`과 `zero_flag`에 따라 분기 주소 `addr`로 변경된다.

```verilog
`JMP_UNCOND: pc_next = addr;
`JMP_JZ:     pc_next = zero_flag  ? addr : pc_out + 1;
`JMP_JNZ:    pc_next = !zero_flag ? addr : pc_out + 1;
```

**4단계 — IN 포트 선택**

IN 명령어의 `operand[3:0]`(`port`)에 따라 9비트 `in_port`를 6개의 논리 채널로 매핑한다.

```verilog
`IN_PORT_NUM:     selected_input = {28'd0, in_port[3:0]};  // 숫자 입력
`IN_PORT_BTN_IN:  selected_input = {31'd0, in_port[4]};    // 입력 확정
`IN_PORT_BTN_CFM: selected_input = {31'd0, in_port[5]};    // 전체 확정
`IN_PORT_BTN_CAN: selected_input = {31'd0, in_port[6]};    // 취소
`IN_PORT_BTN_PW:  selected_input = {31'd0, in_port[7]};    // 비밀번호 변경
`IN_PORT_MST_KEY: selected_input = {31'd0, in_port[8]};    // 마스터키
```

OUT 명령어는 INCREMENT에서 `acc_out[3:0]`을 `out_port`에 직접 래치하며, 초기값 `OUT_STATE_CLOSED(4'b0000)`는 도어락 잠김 상태를 의미한다.

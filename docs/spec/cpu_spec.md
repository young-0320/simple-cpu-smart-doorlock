# Simple CPU 기반 스마트 도어락 CPU 설계 최종 정리본

## 1. 제작 모듈 목록

1. `top_cpu.v`

   - CPU 전체 모듈
   - PC, IR, Decoder, FSM, ALU, ACC, ZERO_FLAG 연결
2. `pc.v`

   - Program Counter
   - 현재 실행할 instruction 주소 저장
   - 일반 명령어 실행 후 PC + 1
   - JMP, JZ, JNZ 실행 시 지정 주소로 변경
3. `alu.v`

   - ADD, SUB, CMP, ADDI, CMPI 연산 수행
   - ZERO_FLAG 생성
4. `accumulator.v`

   - ACC 레지스터
   - 연산 결과, LOAD 결과, IN 결과 저장
5. `decoder.v`

   - `instruction[31:28]` opcode 해석
   - `instruction[27:0]` operand 분리
   - opcode별 제어 신호 생성
6. `cpu_fsm.v`

   - CPU 실행 단계 FSM
   - FETCH / DECODE / EXECUTE / INCREMENT 상태 제어
   - 도어락 상태 FSM이 아니라 CPU 실행 단계 FSM임
7. `inst_reg.v`

   - Instruction Register
   - BRAM에서 읽어온 32비트 instruction 저장
8. `define.vh`

   - 프로젝트 상수 정의 파일
   - opcode, CPU state, IN port 번호, OUT code, 기타 상수 정의
9. `debouncer.v`

- 버튼 디바운싱 모듈
- 입력 버튼, 확정 버튼, 취소 버튼, 비밀번호 변경 버튼, 마스터키 입력 등에 사용 가능

---

## 2. 기본 Spec

Instruction width : 32 bit
Opcode width : 4 bit
Operand / Address / Immediate field : 28 bit

메모리:

- BRAM 사용
- 1 word = 32 bit

CPU 기본 레지스터:

- PC
- IR
- ACC
- ZERO_FLAG
- state register

범용 레지스터:

- 없음

명령어 기본 구조:

```verilog
[31:28] opcode
[27:0]  operand
```

operand 28비트는 명령어 종류에 따라 다르게 사용된다.

- LOADI, ADDI, CMPI에서는 즉시값
- LOAD / STORE / ADD / SUB / CMP에서는 BRAM 주소
- JMP / JZ / JNZ에서는 점프할 instruction 주소
- IN / OUT에서는 port 번호
- NOP에서는 사용하지 않음

주의:

- 현재 ISA에는 WAIT 명령어 없음
- 현재 ISA에는 N flag 없음
- 조건 분기는 ZERO_FLAG만 사용
- 예약 opcode 1110, 1111은 NOP처럼 처리

---

## 3. 32비트 명령어를 사용하는 이유

기존에는 16비트 명령어도 고려했지만, 최종적으로는 opcode 4비트 + operand 28비트 구조의 32비트 명령어로 결정한다.

32비트 명령어를 사용하는 이유는 다음과 같다.

1. 입력, 출력, 비교, 점프, 메모리 접근, 상태 표시 등 다양한 동작을 표현해야 한다.
2. 비밀번호 입력 길이가 4자리에서 8자리까지 유동적이고, 데이터 저장 단위를 32비트로 통일하면 CPU와 BRAM 연결이 단순해진다.
3. LOADI 명령어로 최대 28비트 즉시값을 ACC에 바로 넣을 수 있다.
4. 실패 횟수, 입력 길이, 비밀번호 길이, 상태 코드 등을 operand 또는 BRAM 데이터로 처리하기 쉽다.
5. 4비트 opcode만으로 명령어 종류를 구분하고, 나머지 28비트를 넉넉한 operand 영역으로 사용하면 assembly 작성이 단순해진다.

---

## 4. ISA

### 4.1 Opcode 테이블

| opcode | 니모닉   | Type | 동작                                                  |
| ------ | -------- | ---- | ----------------------------------------------------- |
| 0000   | LOAD     | M    | BRAM[addr] → ACC                                     |
| 0001   | STORE    | M    | ACC → BRAM[addr]                                     |
| 0010   | ADD      | M    | ACC + BRAM[addr] → ACC, ZERO_FLAG 업데이트           |
| 0011   | SUB      | M    | ACC - BRAM[addr] → ACC, ZERO_FLAG 업데이트           |
| 0100   | CMP      | M    | ACC와 BRAM[addr] 비교, ZERO_FLAG만 업데이트, ACC 보존 |
| 0101   | LOADI    | I    | immediate → ACC                                      |
| 0110   | ADDI     | I    | ACC + immediate → ACC, ZERO_FLAG 업데이트            |
| 0111   | CMPI     | I    | ACC와 immediate 비교, ZERO_FLAG만 업데이트, ACC 보존  |
| 1000   | JMP      | J    | PC ← addr                                            |
| 1001   | JZ       | J    | ZERO_FLAG = 1이면 PC ← addr                          |
| 1010   | JNZ      | J    | ZERO_FLAG = 0이면 PC ← addr                          |
| 1011   | NOP      | N    | 아무 동작 없음, PC만 증가                             |
| 1100   | OUT      | P    | ACC[3:0] → out_port[3:0]                             |
| 1101   | IN       | P    | 외부 입력 port 값을 ACC에 저장                        |
| 1110   | RESERVED | -    | NOP처럼 처리                                          |
| 1111   | RESERVED | -    | NOP처럼 처리                                          |

---

### 4.2 Type 설명

Type은 문서 설명용이다.
Decoder 구현 시 상위 2비트만 보고 타입을 판단하지 않는다.

Decoder는 반드시 opcode 4비트 전체를 기준으로 case문 처리한다.

예시:

```verilog
case (opcode)
    4'b0000: // LOAD
    4'b0001: // STORE
    4'b0010: // ADD
    4'b0011: // SUB
    4'b0100: // CMP
    4'b0101: // LOADI
    4'b0110: // ADDI
    4'b0111: // CMPI
    4'b1000: // JMP
    4'b1001: // JZ
    4'b1010: // JNZ
    4'b1011: // NOP
    4'b1100: // OUT
    4'b1101: // IN
    default: // RESERVED, NOP처럼 처리
endcase
```

---

## 5. CPU 입출력 포트

### 5.1 CPU 입력 포트

| 신호       | 비트폭 | 설명             |
| ---------- | ------ | ---------------- |
| clk        | 1      | 클럭             |
| reset      | 1      | 동기 리셋        |
| bram_rdata | [31:0] | BRAM 읽기 데이터 |
| in_port    | [8:0]  | 외부 입력 묶음   |

---

### 5.2 in_port 구성

| 비트         | 용도          | 설명                                                           |
| ------------ | ------------- | -------------------------------------------------------------- |
| in_port[3:0] | 숫자값        | input_handler가 PMOD one-hot 입력을 4비트 2진수로 인코딩한 값 |
| in_port[4]   | 입력 버튼     | 숫자 하나를 입력으로 확정                                      |
| in_port[5]   | 확정 버튼     | 전체 입력 완료 후 확인                                         |
| in_port[6]   | 취소 버튼     | 최근 입력 한 자리 취소                                         |
| in_port[7]   | 비밀번호 변경 | 비밀번호 변경 모드 진입                                        |
| in_port[8]   | 마스터키      | 마스터키 조건 만족 신호                                        |

---

### 5.3 CPU 출력 포트

| 신호       | 비트폭 | 설명                  |
| ---------- | ------ | --------------------- |
| bram_addr  | [11:0] | BRAM 주소             |
| bram_wdata | [31:0] | BRAM 쓰기 데이터      |
| bram_we    | 1      | BRAM write enable     |
| out_port   | [3:0]  | 도어락 출력 상태 코드 |

---

### 5.4 out_port 구성

out_port는 bit별 개별 신호가 아니라, 4비트 전체를 하나의 상태 코드로 사용한다.

```text
out_port[3:0] : 도어락 출력 상태 코드
```

출력 상태 코드:

```text
0000 : 닫힘 / 정상 상태
1000 : 열림
0100 : 1회 오답
0010 : 2회 오답
0001 : 3회 오답 + 잠금
```

즉, 1회 오답에서 2회 오답으로 넘어갈 때 기존 bit를 따로 끄는 방식이 아니다.
OUT 명령어가 out_port 전체 4비트를 새 값으로 덮어쓴다.

예시:

```asm
LOADI 4
OUT 0
```

결과:

```text
out_port = 0100
```

그다음 2회 오답이면:

```asm
LOADI 2
OUT 0
```

결과:

```text
out_port = 0010
```

기존 0100은 자동으로 0010으로 덮어써진다.

---

## 6. CPU 내부 레지스터

```text
PC        : 현재 실행할 instruction 주소
IR        : 현재 instruction 저장 레지스터, 32비트
ACC       : 연산 중심 레지스터, 32비트
ZERO_FLAG : 비교/연산 결과가 0 또는 같음인지 저장하는 flag
state R   : FETCH / DECODE / EXECUTE / INCREMENT
```

주의:

- N flag는 현재 사용하지 않는다.
- CARRY flag도 현재 사용하지 않는다.
- 조건 분기는 ZERO_FLAG 기반 JZ, JNZ만 사용한다.
- 도어락 상태값, 실패 횟수, 입력 길이, 비밀번호 등은 CPU 내부 레지스터가 아니라 BRAM data 영역에 저장한다.

---

## 7. 공통 규칙

1. 일반 명령어는 실행 후 PC = PC + 1
2. JMP, JZ, JNZ는 조건에 따라 PC를 직접 변경한다.
3. LOAD, STORE, ADD, SUB, CMP의 operand는 BRAM 주소이다.
4. JMP, JZ, JNZ의 operand는 instruction 주소이다.
5. IN, OUT의 operand는 port 번호이다.
6. IN, OUT에서 사용하는 port 번호는 operand[3:0]만 사용한다.

```verilog
operand[3:0]  = port 번호
operand[27:4] = unused
```

7. BRAM 주소로 사용할 때는 operand[11:0]만 사용한다.

```verilog
bram_addr = operand[11:0]
```

8. operand[27:12]는 현재 BRAM 주소로 사용하지 않는다.
9. ZERO_FLAG는 ADD, SUB, ADDI, CMP, CMPI에서만 업데이트한다.
10. LOAD, STORE, LOADI, IN, OUT, JMP, JZ, JNZ, NOP은 ZERO_FLAG를 변경하지 않는다.
11. 예약 opcode 1110, 1111은 NOP처럼 처리한다.

---

## 8. Instruction Behavior Table 최종안

### opcode 0000 : LOAD

```text
형식:
LOAD addr

동작:
ACC <- BRAM[addr]
PC  <- PC + 1

ZERO_FLAG:
변경 없음

설명:
- operand를 BRAM 주소로 사용한다.
- 실제 BRAM 주소로는 operand[11:0]을 사용한다.
- 해당 주소의 값을 ACC로 읽어온다.

예시:
LOAD 0x200
→ ACC <- BRAM[0x200]
```

---

### opcode 0001 : STORE

```text
형식:
STORE addr

동작:
BRAM[addr] <- ACC
PC <- PC + 1

ZERO_FLAG:
변경 없음

설명:
- ACC 값을 operand가 가리키는 BRAM 주소에 저장한다.
- 실제 BRAM 주소로는 operand[11:0]을 사용한다.

예시:
STORE 0x210
→ BRAM[0x210] <- ACC
```

---

### opcode 0010 : ADD

```text
형식:
ADD addr

동작:
ACC <- ACC + BRAM[addr]
ZERO_FLAG <- 결과가 0이면 1, 아니면 0
PC <- PC + 1

ZERO_FLAG:
업데이트

설명:
- ACC에 BRAM[addr] 값을 더한다.
- 실제 BRAM 주소로는 operand[11:0]을 사용한다.

예시:
ADD 0x2F0
→ ACC <- ACC + BRAM[0x2F0]
```

---

### opcode 0011 : SUB

```text
형식:
SUB addr

동작:
ACC <- ACC - BRAM[addr]
ZERO_FLAG <- 결과가 0이면 1, 아니면 0
PC <- PC + 1

ZERO_FLAG:
업데이트

설명:
- ACC에서 BRAM[addr] 값을 뺀다.
- 취소 버튼 처리처럼 INPUT_LEN을 1 줄일 때 사용할 수 있다.

예시:
LOAD INPUT_LEN
SUB CONST_1
STORE INPUT_LEN
```

---

### opcode 0100 : CMP

```text
형식:
CMP addr

동작:
ZERO_FLAG <- ACC == BRAM[addr] 이면 1, 아니면 0
ACC 변경 없음
PC <- PC + 1

ZERO_FLAG:
업데이트

설명:
- ACC와 BRAM[addr] 값을 비교한다.
- 실제로 ACC - BRAM[addr] 연산을 하더라도 결과를 ACC에 저장하지 않는다.
- 비밀번호 비교의 핵심 명령어이다.

예시:
IN 0
CMP PASSWORD_0
JZ MATCH
```

---

### opcode 0101 : LOADI

```text
형식:
LOADI immediate

동작:
ACC <- immediate
PC <- PC + 1

ZERO_FLAG:
변경 없음

설명:
- operand 값을 그대로 ACC에 넣는다.
- immediate는 28비트 즉시값이다.

예시:
LOADI 4
→ ACC <- 4
```

---

### opcode 0110 : ADDI

```text
형식:
ADDI immediate

동작:
ACC <- ACC + immediate
ZERO_FLAG <- 결과가 0이면 1, 아니면 0
PC <- PC + 1

ZERO_FLAG:
업데이트

설명:
- ACC에 즉시값을 더한다.
- FAIL_COUNT 증가, INPUT_LEN 증가 등에 사용한다.

예시:
LOAD FAIL_COUNT
ADDI 1
STORE FAIL_COUNT
```

---

### opcode 0111 : CMPI

```text
형식:
CMPI immediate

동작:
ZERO_FLAG <- ACC == immediate 이면 1, 아니면 0
ACC 변경 없음
PC <- PC + 1

ZERO_FLAG:
업데이트

설명:
- ACC와 즉시값을 비교한다.
- input button, confirm button, cancel button, master key 같은 0/1 신호 확인에 사용하기 좋다.

예시:
IN 1
CMPI 1
JZ INPUT_RECEIVED
```

---

### opcode 1000 : JMP

```text
형식:
JMP addr

동작:
PC <- addr

ZERO_FLAG:
변경 없음

설명:
- 무조건 점프한다.
- PC + 1을 하지 않는다.
- operand는 instruction 주소이다.
- 실제 PC에는 operand[11:0]을 넣는다.

예시:
JMP 0x100
→ PC <- 0x100
```

---

### opcode 1001 : JZ

```text
형식:
JZ addr

동작:
if ZERO_FLAG == 1:
    PC <- addr
else:
    PC <- PC + 1

ZERO_FLAG:
변경 없음

설명:
- 직전 CMP, CMPI, ADD, SUB, ADDI 결과에서 ZERO_FLAG가 1이면 점프한다.
- operand는 instruction 주소이다.
- 실제 PC에는 operand[11:0]을 넣는다.

예시:
CMP PASSWORD_0
JZ MATCH
```

---

### opcode 1010 : JNZ

```text
형식:
JNZ addr

동작:
if ZERO_FLAG == 0:
    PC <- addr
else:
    PC <- PC + 1

ZERO_FLAG:
변경 없음

설명:
- ZERO_FLAG가 0이면 점프한다.
- 비교 결과가 다를 때 실패 루틴으로 이동하는 데 사용한다.
- operand는 instruction 주소이다.
- 실제 PC에는 operand[11:0]을 넣는다.

예시:
CMP PASSWORD_0
JNZ FAIL
```

---

### opcode 1011 : NOP

```text
형식:
NOP

동작:
아무 동작 없음
PC <- PC + 1

ZERO_FLAG:
변경 없음

설명:
- 빈 instruction 자리 채우기
- 예약 공간 처리
- 테스트용으로 사용 가능
```

---

### opcode 1100 : OUT

```text
형식:
OUT port

동작:
out_port[3:0] <- ACC[3:0]
PC <- PC + 1

ZERO_FLAG:
변경 없음

비트:
operand[3:0] = port 번호
operand[27:4] = unused

현재 사용 방식:
- 현재는 OUT 0만 사용한다.
- OUT 0은 ACC[3:0] 값을 out_port[3:0] 전체에 출력한다.
- out_port는 bit별 개별 제어가 아니라 4비트 상태 코드이다.

출력 코드:
0000 : 닫힘 / 정상 상태
1000 : 열림
0100 : 1회 오답
0010 : 2회 오답
0001 : 3회 오답 + 잠금

예시:
LOADI 0
OUT 0
→ out_port = 0000, 닫힘 / 정상

LOADI 8
OUT 0
→ out_port = 1000, 열림

LOADI 4
OUT 0
→ out_port = 0100, 1회 오답

LOADI 2
OUT 0
→ out_port = 0010, 2회 오답

LOADI 1
OUT 0
→ out_port = 0001, 3회 오답 + 잠금
```

---

### opcode 1101 : IN

```text
형식:
IN port

동작:
port 번호에 따라 외부 입력값을 선택하여 ACC에 저장
PC <- PC + 1

ZERO_FLAG:
변경 없음

비트:
operand[3:0] = port 번호
operand[27:4] = unused

논리적 포트 번호 매핑:
IN 0 → ACC <- {28'b0, in_port[3:0]}
IN 1 → ACC <- {31'b0, in_port[4]}
IN 2 → ACC <- {31'b0, in_port[5]}
IN 3 → ACC <- {31'b0, in_port[6]}
IN 4 → ACC <- {31'b0, in_port[7]}
IN 5 → ACC <- {31'b0, in_port[8]}

의미:
IN 0 : input_handler가 전달한 2진수 숫자값
IN 1 : 입력 버튼
IN 2 : 확정 버튼
IN 3 : 취소 버튼
IN 4 : 비밀번호 변경 신호
IN 5 : 마스터키 신호

예시:
IN 0
→ ACC <- 입력된 숫자값

IN 1
→ ACC <- 입력 버튼 상태

IN 5
→ ACC <- 마스터키 신호
```

---

### opcode 1110: RESERVED

```text
동작:
NOP처럼 처리
PC <- PC + 1

ZERO_FLAG:
변경 없음

설명:
- 추후 확장용 opcode이다.
- 현재는 아무 동작 없이 PC만 증가시킨다.
```

---
### opcode 1111: A

```text
동작:
funct_bin(4비트)을 디코딩하여 지정된 연산을 수행하고 그 결과를 ACC에 저장
PC <- PC + 1


세부 동작 (funct_bin 매핑):
[0000] SHL : ACC <- ACC << MEM[address]  (또는 설계에 따라 ACC << address 즉시값)
[0001] SHR : ACC <- ACC >> MEM[address]  (또는 설계에 따라 ACC >> address 즉시값)
[0010] AND : ACC <- ACC & MEM[address]

ZERO_FLAG:
연산 결과(ACC 갱신 값)가 0이면 1, 아니면 0으로 갱신 (일반적인 ALU 연산 규칙 적용)

비트 할당 (총 32비트 가정):
instruction[31:28] = 1111 (opcode)
instruction[27:24] = funct_bin (0000: SHL, 0001: SHR, 0010: AND)
instruction[23:12] = reserved_bin (추후 확장을 위한 예비 공간, 현재는 0으로 채움)
instruction[11:0]  = address (피연산자 메모리 주소 또는 즉시값)

현재 사용 방식:
- 기존의 opcode 공간이 부족해질 것을 대비해 1111을 확장용(Escape Opcode)으로 사용한다.
- Control Unit은 opcode가 1111일 때 funct_bin 필드를 추가로 디코딩하여 ALU 제어 신호를 생성한다.

예시:
SHL 5
→ funct_bin = 0000, address = 5
→ 동작: ACC <- ACC << MEM[5] 

AND 12
→ funct_bin = 0010, address = 12
→ 동작: ACC <- ACC & MEM[12]

---
## 9. BRAM 관련 주의사항

BRAM이 동기식 read인지 비동기식 read인지에 따라 CPU FSM 구현이 달라질 수 있다.

### 9.1 비동기식 read memory인 경우

주소를 넣으면 같은 cycle에 `bram_rdata`가 바로 바뀐다고 가정할 수 있다.

이 경우 CPU FSM을 단순하게 구성할 수 있다.

```text
FETCH
DECODE
EXECUTE
INCREMENT
```

---

### 9.2 동기식 read BRAM인 경우

FPGA BRAM은 보통 주소를 넣은 다음 클럭에 데이터가 나오는 동기식 read 구조일 수 있다.

이 경우 LOAD, ADD, SUB, CMP처럼 BRAM 데이터를 읽어야 하는 명령어는 한 cycle에 끝나기 어렵다.

따라서 다음과 같은 상태가 추가될 수 있다.

```text
FETCH
DECODE
EXECUTE
MEM_WAIT
WRITE_BACK
INCREMENT
```

예시:

LOAD addr 실행 시

```text
1. EXECUTE 상태에서 bram_addr <- addr 설정
2. MEM_WAIT 상태에서 BRAM 출력 대기
3. WRITE_BACK 상태에서 ACC <- bram_rdata
4. INCREMENT 상태에서 PC <- PC + 1
```

이 부분은 BRAM 담당자와 반드시 맞춰야 한다.

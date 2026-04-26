## 제작 모듈 목록

1. top_cpu.v
2. pc.v               ← Program Counter
3. alu.v
4. accumulator.v
5. decoder.v
6. cpu_fsm.v
7. inst_reg.v         ← Instruction Register
8. define.vh         ← 프로젝트 상수 정의 파일 (ISA, 메모리 맵 등) 코드를 기계어로 변환하는 스크립트
9. debouncer.v        ← 버튼 디바운싱 모듈

## spec

Instruction width : 32 bit
Opcode width : 4 bit
Operand / Address / Immediate field : 28 bit

메모리             BRAM, 1워드 = 32비트
레지스터           PC, IR, ACC, FLAG(Z,N)
범용 레지스터      없음

- operand 28비트는 명령어 종류에 따라 다르게 사용된다.
  - LDI에서는 즉시값
  - LD/ST에서는 메모리 주소
  - JMP/JZ/JNZ에서는 점프 주소
  - IN/OUT에서는 입출력 포트 번호 또는 출력 코드
  - CMP에서는 비교 대상 주소 또는 즉시값
  - WAIT에서는 대기 시간 또는 타이머 코드

기존에는 16비트 명령어를 고려했지만,
이번 프로젝트에서는 opcode 4비트 뒤에 28비트 operand/address 필드를 두는 32비트 명령어로 결정한다.

32비트 명령어를 사용하는 이유는 다음과 같다.

1. 입력, 출력, 비교, 점프, 메모리 접근, 대기, 상태 표시 등 다양한 동작을 표현해야 한다.
2. 비밀번호 입력 길이가 4자리에서 8자리까지 유동적이고 데이터 크기 자체가 32비트이기에 명령어도 32비트로 맞추는 것이 편리하다. (예: LDI 명령어로 최대 28비트 즉시값 로드 가능)
3. 실패 횟수 카운트, 입력 대기 시간, 열림 유지 시간 등의 값을 명령어에 담을 수 있어야 한다.
4. 비밀번호 변경 기능을 위해 메모리 주소와 제어 코드가 필요하다.
5. 4비트 opcode만으로 명령어 종류를 구분하고, 나머지 28비트를 넉넉한 operand 영역으로 사용하면 assembly 작성이 단순해진다.

## ISA

### opcode 테이블

| opcode | 니모닉 | Type | 동작                                   |
| ------ | ------ | ---- | -------------------------------------- |
| 0000   | LOAD   | M    | BRAM[addr] → ACC                      |
| 0001   | STORE  | M    | ACC → BRAM[addr]                      |
| 0010   | ADD    | M    | ACC + BRAM[addr] → ACC, FLAG 업데이트 |
| 0011   | SUB    | M    | ACC - BRAM[addr] → ACC, FLAG 업데이트 |
| 0100   | CMP    | M    | ACC - BRAM[addr], FLAG만 업데이트      |
| 0101   | LOADI  | I    | immediate → ACC                       |
| 0110   | ADDI   | I    | ACC + immediate → ACC, FLAG 업데이트  |
| 0111   | CMPI   | I    | ACC - immediate, FLAG만 업데이트       |
| 1000   | JMP    | J    | PC ← addr                             |
| 1001   | JZ     | J    | Z=1이면 PC ← addr                     |
| 1010   | JNZ    | J    | Z=0이면 PC ← addr                     |
| 1101   | IN     | P    | 외부입력[port] → ACC                  |
| 1100   | OUT    | P    | ACC → 외부출력[port]                  |
| 1011   | NOP    | N    | 아무동작 없음, PC만 증가               |
| 1110   | (예약) | -    | 확장용                                 |
| 1111   | (예약) | -    | 확장용                                 |

## cpu 입출력 포트

입력

- clk
- reset
- bram_rdata  [31:0]
- in_port     [8:0]
  - in_port [3:0] -> 인풋 핸들러가 전달한 2진수 인코딩된 비밀번호 1자리값
  - in_port [4] -> 입력 버튼 (0: 미입력, 1: 입력)
  - in_port [5] -> 확정 버튼 (0: 미확정, 1: 확정)
  - in_port [6] -> 취소 버튼 (0: 미취소, 1: 취소)
  - in_port [7] -> 비밀번호 변경 신호 (0: 미변경, 1: 변경)
  - in_port [8] -> 마스터키 입력 신호 (0: 미입력, 1: 입력)

출력

- bram_addr   [11:0]
- bram_wdata  [31:0]
- bram_we
- out_port    [3:0]
  - out_port[0] → 도어 상태  (0: 닫힘, 1: 열림)
  - out_port[1] → 1회 실패  (0: 정상, 1: 1회 실패)
  - out_port[2] → 2회 실패  (0: 정상, 1: 2회 실패)
  - out_port[3] → 3회 실패  (0: 정상, 1: 3회 실패 + 타이머)

3회 실패 : out_port = 1000  → [3]만 1
2회 실패 : out_port = 0100  → [2]만 1
1회 실패 : out_port = 0010  → [1]만 1
열림     : out_port = 0001  → [0]만 1

## cpu 레지스터

```
PC        : 명령어 주소
IR        : 현재 명령어 (32비트)
ACC       : 연산 레지스터 (32비트)
ZERO_FLAG : Z만 사용, N 없음
state R   : FETCH/DECODE/EXECUTE/INCREMENT
```

**IN/OUT**

```
operand [3:0] : port 번호 (4비트)
operand [27:4] : unused
```


# Instruction Behavior Table 최종안

## 기본 Instruction 구조

```
[31:28] opcode (4비트)
[27:0]  operand (28비트)
```

## 기본 레지스터

| 레지스터  | 설명                                           |
| --------- | ---------------------------------------------- |
| PC        | 현재 instruction 주소                          |
| IR        | 현재 instruction 저장 레지스터                 |
| ACC       | 연산 중심 레지스터 (32비트)                    |
| ZERO_FLAG | 비교/연산 결과가 0 또는 같음인지 저장하는 flag |
| state R   | FETCH / DECODE / EXECUTE / INCREMENT           |

## 공통 규칙

1. 일반 명령어는 실행 후 PC = PC + 1
2. JMP, JZ, JNZ는 조건에 따라 PC를 직접 변경
3. LOAD, STORE, ADD, SUB, CMP의 operand는 BRAM 주소
4. JMP, JZ, JNZ의 operand는 instruction 주소
5. IN, OUT의 operand는 port 번호 [3:0], [27:4]는 unused
6. ZERO_FLAG는 ADD, SUB, ADDI, CMP, CMPI에서만 업데이트
7. 예약 opcode는 NOP처럼 처리 (PC + 1만 수행)

## CPU 입출력 포트

### 입력

| 신호       | 비트폭 | 설명             |
| ---------- | ------ | ---------------- |
| clk        | 1      | 클럭             |
| reset      | 1      | 동기 리셋        |
| bram_rdata | [31:0] | BRAM 읽기 데이터 |
| in_port    | [8:0]  | 외부 입력        |

### in_port 상세

| 비트  | 용도          | 설명                                  |
| ----- | ------------- | ------------------------------------- |
| [3:0] | 숫자값        | input_handler가 인코딩한 4비트 숫자값 |
| [4]   | 입력 버튼     | 0: 미입력, 1: 입력                    |
| [5]   | 확정 버튼     | 0: 미확정, 1: 확정                    |
| [6]   | 취소 버튼     | 0: 미취소, 1: 취소                    |
| [7]   | 비밀번호 변경 | 0: 미변경, 1: 변경                    |
| [8]   | 마스터키      | 0: 미입력, 1: 입력                    |

### 출력

| 신호       | 비트폭 | 설명              |
| ---------- | ------ | ----------------- |
| bram_addr  | [11:0] | BRAM 주소         |
| bram_wdata | [31:0] | BRAM 쓰기 데이터  |
| bram_we    | 1      | BRAM write enable |
| out_port   | [3:0]  | 외부 출력         |

### out_port 상세

| 비트 | 용도      | 설명                          |
| ---- | --------- | ----------------------------- |
| [0]  | 도어 상태 | 0: 닫힘, 1: 열림              |
| [1]  | 1회 실패  | 0: 정상, 1: 1회 실패          |
| [2]  | 2회 실패  | 0: 정상, 1: 2회 실패          |
| [3]  | 3회 실패  | 0: 정상, 1: 3회 실패 + 타이머 |

---

## Opcode 테이블

| opcode | 니모닉 | Type | 동작                                        |
| ------ | ------ | ---- | ------------------------------------------- |
| 0000   | LOAD   | M    | BRAM[addr] → ACC                           |
| 0001   | STORE  | M    | ACC → BRAM[addr]                           |
| 0010   | ADD    | M    | ACC + BRAM[addr] → ACC, FLAG 업데이트      |
| 0011   | SUB    | M    | ACC - BRAM[addr] → ACC, FLAG 업데이트      |
| 0100   | CMP    | M    | ACC - BRAM[addr], FLAG만 업데이트, ACC 보존 |
| 0101   | LOADI  | I    | immediate → ACC                            |
| 0110   | ADDI   | I    | ACC + immediate → ACC, FLAG 업데이트       |
| 0111   | CMPI   | I    | ACC - immediate, FLAG만 업데이트, ACC 보존  |
| 1000   | JMP    | J    | PC ← addr                                  |
| 1001   | JZ     | J    | Z=1이면 PC ← addr, 아니면 PC+1             |
| 1010   | JNZ    | J    | Z=0이면 PC ← addr, 아니면 PC+1             |
| 1011   | NOP    | N    | 아무동작 없음, PC+1                         |
| 1100   | OUT    | P    | out_port[port] ← ACC, PC+1                 |
| 1101   | IN     | P    | ACC ← in_port[port], PC+1                  |
| 1110   | (예약) | -    | NOP처럼 처리, PC+1                          |
| 1111   | (예약) | -    | NOP처럼 처리, PC+1                          |

### Decoder 타입 판단

```
상위 2비트만으로 타입 판단
00xx → M타입 (BRAM 주소)
01xx → I타입 (즉시값)
10xx → J타입 (점프 주소)
11xx → P/N타입 (포트 번호 또는 NOP)
```

---

## 명령어 상세

### opcode 0000 : LOAD

```
형식  : LOAD addr
동작  : ACC <- BRAM[addr]
        PC  <- PC + 1
ZERO FLAG  : 변경 없음
예시  : LOAD 0xF00 → ACC <- BRAM[0xF00]
```

### opcode 0001 : STORE

```
형식  : STORE addr
동작  : BRAM[addr] <- ACC
        PC <- PC + 1
ZERO FLAG  : 변경 없음
예시  : STORE 0xF00 → BRAM[0xF00] <- ACC
```

### opcode 0010 : ADD

```
형식  : ADD addr
동작  : ACC <- ACC + BRAM[addr]
        ZERO_FLAG <- (결과 == 0) ? 1 : 0
        PC <- PC + 1
ZERO FLAG  : 업데이트
예시  : ADD 0xF50 → ACC <- ACC + BRAM[0xF50]
```

### opcode 0011 : SUB

```
형식  : SUB addr
동작  : ACC <- ACC - BRAM[addr]
        ZERO_FLAG <- (결과 == 0) ? 1 : 0
        PC <- PC + 1
ZERO FLAG  : 업데이트
예시  : LOAD INPUT_LEN / SUB CONST_1 / STORE INPUT_LEN
```

### opcode 0100 : CMP

```
형식  : CMP addr
동작  : ZERO_FLAG <- (ACC == BRAM[addr]) ? 1 : 0
        ACC 변경 없음
        PC <- PC + 1
ZERO FLAG  : 업데이트
예시  : CMP 0xF00 / JZ MATCH
```

### opcode 0101 : LOADI

```
형식  : LOADI immediate
동작  : ACC <- immediate (28비트 즉시값)
        PC  <- PC + 1
ZERO FLAG  : 변경 없음
예시  : LOADI 4 → ACC <- 4
```

### opcode 0110 : ADDI

```
형식  : ADDI immediate
동작  : ACC <- ACC + immediate
        ZERO_FLAG <- (결과 == 0) ? 1 : 0
        PC <- PC + 1
ZERO FLAG  : 업데이트
예시  : LOAD FAIL_COUNT / ADDI 1 / STORE FAIL_COUNT
```

### opcode 0111 : CMPI

```
형식  : CMPI immediate
동작  : ZERO_FLAG <- (ACC == immediate) ? 1 : 0
        ACC 변경 없음
        PC <- PC + 1
ZERO FLAG  : 업데이트
예시  : IN 4 / CMPI 1 / JZ INPUT_RECEIVED
```

### opcode 1000 : JMP

```
형식  : JMP addr
동작  : PC <- addr
ZERO FLAG : 변경 없음
예시  : JMP 0x100 → PC <- 0x100
```

### opcode 1001 : JZ

```
형식  : JZ addr
동작  : ZERO_FLAG == 1 이면 PC <- addr
        ZERO_FLAG == 0 이면 PC <- PC + 1
ZERO FLAG  : 변경 없음
예시  : CMP 0xF00 / JZ MATCH
```

### opcode 1010 : JNZ

```
형식  : JNZ addr
동작  : ZERO_FLAG == 0 이면 PC <- addr
        ZERO_FLAG == 1 이면 PC <- PC + 1
ZERO FLAG  : 변경 없음
예시  : CMP 0xF00 / JNZ FAIL
```

### opcode 1011 : NOP

```
형식  : NOP
동작  : 아무동작 없음
        PC <- PC + 1
ZERO FLAG  : 변경 없음
용도  : 빈 자리 채우기, 예약 공간 처리
```

### opcode 1100 : OUT

```
형식  : OUT port
동작  : out_port[port] <- ACC
        PC <- PC + 1
ZERO FLAG  : 변경 없음
비트  : operand[3:0] = port 번호, [27:4] unused
예시  : LOADI 1 / OUT 0 → out_port[0] = 1 (도어 열림)
        LOADI 0 / OUT 0 → out_port[0] = 0 (도어 닫힘)
        LOADI 1 / OUT 1 → out_port[1] = 1 (1회 실패)
```

### opcode 1101 : IN

```
형식  : IN port
동작  : ACC <- in_port[port]
        PC  <- PC + 1
ZERO FLAG  : 변경 없음
비트  : operand[3:0] = port 번호, [27:4] unused

논리적 포트 번호 매핑:
IN 0 → ACC <- in_port[3:0]  (숫자값 4비트, 상위 28비트 0 패딩)
IN 1 → ACC <- in_port[4]    (입력 버튼 1비트)
IN 2 → ACC <- in_port[5]    (확정 버튼 1비트)
IN 3 → ACC <- in_port[6]    (취소 버튼 1비트)
IN 4 → ACC <- in_port[7]    (비밀번호 변경 신호 1비트)
IN 5 → ACC <- in_port[8]    (마스터키 신호 1비트)

예시  : IN 0 → ACC <- 숫자값 4비트
        IN 1 → ACC <- 입력 버튼
        IN 2 → ACC <- 확정 버튼
```

### opcode 1110, 1111 : RESERVED

```
동작  : NOP처럼 처리
        PC <- PC + 1
```

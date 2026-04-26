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


addi loadi storei cmpi


wait

공통

add sub load store in out cmp jum 

loadi 

nope

### 포맷 

| Type | 명령어                     | operand          |
| ---- | -------------------------- | ---------------- |
| M    | LOAD, STORE, ADD, SUB, CMP | [27:0] BRAM 주소 |
| I    | LOADI, ADDI, CMPI          | [27:0] 즉시값    |
| J    | JMP, JZ, JNZ               | [27:0] 점프 주소 |
| P    | IN, OUT                    | [3:0] 포트 번호  |
| N    | NOP                        | 아무동작 없음, PC만 증가|
| -    | (예약)                        | 확장용 |



### opcode 테이블
M: 00
I: 01
J: 10
P: 10
N: 11


| opcode | 니모닉 | Type | 동작 |
|--------|--------|------|------|
| 0000   | LOAD   | M    | BRAM[addr] → ACC |
| 0001   | STORE  | M    | ACC → BRAM[addr] |
| 0010   | ADD    | M    | ACC + BRAM[addr] → ACC, FLAG 업데이트 |
| 0011   | SUB    | M    | ACC - BRAM[addr] → ACC, FLAG 업데이트 |
| 0100   | CMP    | M    | ACC - BRAM[addr], FLAG만 업데이트 |

| 0101   | LOADI  | I    | immediate → ACC |
| 0110   | ADDI   | I    | ACC + immediate → ACC, FLAG 업데이트 |
| 0111   | CMPI   | I    | ACC - immediate, FLAG만 업데이트 |

| 1000   | JMP    | J    | PC ← addr |
| 1001   | JZ     | J    | Z=1이면 PC ← addr |
| 1010   | JNZ    | J    | Z=0이면 PC ← addr |

| 1111   | IN     | P    | 외부입력[port] → ACC |
| 1100   | OUT    | P    | ACC → 외부출력[port] |

| 1101   | NOP    | N    | 아무동작 없음, PC만 증가 |
| 1110   | (예약) | -    | 확장용 |
| 1111   | (예약) | -    | 확장용 |

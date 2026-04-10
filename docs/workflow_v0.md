# 스마트 도어락 설계 워크플로우 초안

## 1. 작업 순서

### 하드웨어 (RTL)

1. 스마트 도어락 기능 정의
2. ISA 확정 (명령어 종류, 비트 구조)
3. 모듈 설계
4. 모듈별 단위 시뮬레이션
5. Top-level 통합 및 통합 시뮬레이션
6. XDC 작성 및 Vivado 합성/구현

### 소프트웨어 (어셈블리)

3. 도어락 동작을 어셈블리어로 작성
4. 어셈블리 → 기계어 변환 (Python 스크립트)
5. 기계어를 BRAM 초기화 파일로 변환 (.coe 또는 .mem)
6. Vivado에서 BRAM에 적재

### 검증

7. FPGA 보드 업로드 및 동작 확인
8. 시연 영상 촬영 및 발표 자료 작성

## 2. 구현 모듈 리스트
```
1. top_cpu.v
2. top_doorlock.v
3. pc.v               ← Program Counter   
4. alu.v
5. accumulator.v
6. decoder.v
7. fsm.v              
8. inst_reg.v         ← Instruction Register
9. bram               ← Vivado IP로 생성
10. input_handler.v   ← PMOD, BCD 등 입력 처리 모듈
11. output_handler.v  ← LED, 잠금 신호 등 출력 처리 모듈 
12. define.vh         ← 프로젝트 상수 정의 파일 (ISA, 메모리 맵 등)
13. doorlock.asm      ← 어셈블리 프로그램으로 도어락 기능을 어셈블리어로 코딩
14. assembler.py      ← doorlock.asm 코드를 기계어로 변환하는 스크립트
15. doorlock.coe      ← Coefficient File로 BRAM 초기화시키는 파일 (assembler.py 출력물)  
```
## 3. 계층 구조

```
top_doorlock.v
├── top_cpu.v
│   ├── pc.v
│   ├── inst_reg.v
│   ├── fsm.v
│   ├── decoder.v
│   ├── alu.v
│   └── accumulator.v
├── bram (Vivado IP)
├── input_handler.v
└── output_handler.v
```

## 4. 업무 분할

모두 함께
- 스마트 도어락 기능 확정
- ISA 설계 (명령어 종류, 비트 구조)
- define.vh 작성(프로젝트 상수 값 정의 파일)
- 모듈 포트(인터페이스) 스펙 확정


### 1안 
A : PC + FSM + Decoder + IR
    - PC 레지스터
    - 4-cycle 상태 전이 구현
    - Instruction Register
    - 명령어 → 제어 신호 변환

B : ALU + Accumulator
    - 기본 연산 (ADD, SUB)
    - 비교 연산 (EQ, GT) 추가
    - MUX 제어

C : BRAM 인터페이스 + 어셈블리
    - BRAM 단일 포트 설계
    - 메모리 맵 정의
    - 어셈블리 프로그램 작성
    - 기계어 변환 스크립트 (Python)
    - .coe 파일 생성

D : 입출력 + Top-level

    - 입력 처리 (PMOD / BCD) 
    - LED / 잠금 출력
    - top 모듈 통합
특징
A : FSM + Decoder가 묶여있어서
    제어 신호 흐름을 한 사람이 끝까지 책임짐
    → 인터페이스 오류 가능성 낮음

B : ALU + Accumulator가 독립적
    다른 모듈 완성 안 돼도 혼자 작업 가능
    → 병렬 작업에 유리

D : Top-level 담당자가 입출력도 맡아서
    외부 신호 흐름을 한 사람이 전부 파악
    → 통합 시 혼란 적음

-> 모듈 경계가 뚜렷하지만 C의 작업량이 상대적으로 많고, A의 구현 난이도가 높음

### 2안 
A : PC + IR + FSM
    - PC 레지스터
    - Instruction Register
    - 4-cycle 상태 전이

B : Decoder + define.vh
    - ISA 기반 제어 신호 생성
    - define.vh 관리 (공용 파일 담당)

C : ALU + Accumulator + BRAM
    - 연산 모듈
    - BRAM 인터페이스
    - 메모리 맵 정의

D : 입출력 + Top-level + 어셈블리
    - PMOD / BCD 입력 처리
    - LED / 잠금 출력
    - top 모듈 통합
    - 어셈블리 프로그램 작성 (doorlock.asm)
    - 기계어 변환 스크립트 (assembler.py)
    - .coe 파일 생성
특징
A ↔ B : FSM이 Decoder 제어 신호를 받으므로 인터페이스가 많음
        → 둘이 가장 긴밀하게 소통해야 함

C     : 연산 + 메모리로 독립성이 높아 혼자 작업하기 좋음

D     : Top-level은 전체를 이해해야 하지만
        어셈블리는 ISA 확정 후 독립적으로 작업 가능
        → 두 작업이 시간적으로 분리되어 부담이 덜함
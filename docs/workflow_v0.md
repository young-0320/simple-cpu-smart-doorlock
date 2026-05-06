# 스마트 도어락 설계 워크플로우 v1

작업일 : 2026-04-26

## 1. 작업 순서

### 하드웨어 (RTL)

1. 스마트 도어락 기능 정의
2. ISA 확정 (명령어 종류, 비트 구조)
3. 모듈 설계
4. 모듈별 단위 시뮬레이션
5. Top-level 통합 및 통합 시뮬레이션
6. XDC 작성 및 Vivado 합성/구현

### 소프트웨어 (어셈블리)

1. 도어락 동작을 어셈블리어로 작성
2. 어셈블리 → 기계어 변환 (Python 스크립트)
3. 기계어를 BRAM 초기화 파일로 변환 (.coe 또는 .mem)
4. Vivado에서 BRAM에 적재

### 검증

1. 각각의 모듈 단위 시뮬레이션으로 기능 검증
2. Top-level 시뮬레이션으로 전체 시스템 검증
3. FPGA 보드 업로드 및 동작 확인
4. 시연 영상 촬영 및 발표 자료 작성

## 2. 구현 모듈 리스트

```
1. top_cpu.v
2. top_doorlock.v
3. pc.v               ← Program Counter   
4. alu.v
5. accumulator.v
6. decoder.v
7. debouncer.v	      ← 버튼 디바운싱 모듈
8. cpu_fsm.v  
9. inst_reg.v         ← Instruction Register
10. bram              ← Vivado IP로 생성
11. input_handler.v   ← PMOD로 입력되는 raw data를 처리하는 모듈
12. output_handler.v  ← LED, 잠금 신호 등 출력 처리 모듈 
13. define.vh         ← 프로젝트 상수 정의 파일 (ISA, 메모리 맵 등)
14. doorlock.asm      ← 도어락 기능을 어셈블리어로 코딩한 파일
15. assembler.py      ← doorlock.asm 코드를 기계어(.coe 혹은 .mem)로 변환하는 스크립트
16. doorlock.coe      ← BRAM을 instruction으로 초기화시키는 파일 (assembler.py 출력물)  
```

## 3. 계층 구조

```
top_doorlock.v
├── top_cpu.v
│   ├── pc.v
│   ├── inst_reg.v
│   ├── cpu_fsm.v
│   ├── decoder.v
│   ├── alu.v
│   └── accumulator.v
├── bram (Vivado IP)
├── input_handler.v
│   └── debouncer.v (×15)
└── output_handler.v
```

## CPU workflow

1. opcode 확정
2. cpu 입출력 포트 확정
3. 명령어 동작표 확정
4. cpu 내부 레지스터 확정
5. FSM 상태 전이 정의
6. top_cpu.v 포트 확정
7. RTL 작성 시작
8. tb 작성 후 모듈 검증

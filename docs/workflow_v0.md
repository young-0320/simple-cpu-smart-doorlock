# 스마트 도어락 설계 워크플로우 v1

작업일 : 2026 04 26

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

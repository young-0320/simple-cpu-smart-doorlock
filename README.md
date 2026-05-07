# Simple CPU Smart Doorlock

> **Simple CPU** 기반 스마트 도어락 — FPGA(Zybo Z7-20) 위에서 직접 설계한 ISA·어셈블러·RTL을 통합해 동작하는 하드웨어 시스템

---

## Table of Contents

- [Simple CPU Smart Doorlock](#simple-cpu-smart-doorlock)
  - [Table of Contents](#table-of-contents)
  - [Overview](#overview)
  - [Features](#features)
  - [System Architecture](#system-architecture)
    - [CPU 파이프라인 (4-state FSM)](#cpu-파이프라인-4-state-fsm)
  - [Repository Structure](#repository-structure)
  - [Team \& Roles](#team--roles)
    - [한영웅 · 허원석 — CPU 설계](#한영웅--허원석--cpu-설계)
    - [유경민 — BRAM IP + 어셈블리](#유경민--bram-ip--어셈블리)
    - [이윤서 — 입출력 + Top-level](#이윤서--입출력--top-level)
  - [ISA Reference](#isa-reference)
    - [Opcode Table](#opcode-table)
    - [Instruction Encoding](#instruction-encoding)
    - [IN/OUT Port Map](#inout-port-map)
  - [Memory Map](#memory-map)
  - [Hardware Setup](#hardware-setup)
    - [보드 및 핀 배치](#보드-및-핀-배치)
    - [빌드 순서](#빌드-순서)
    - [어셈블리 수정 시](#어셈블리-수정-시)
  - [Simulation](#simulation)
  - [Demo Results](#demo-results)

---

## Overview

디지털회로설계및언어 프로젝트 1.

강의에서 제시한 **Simple CPU** 골격을 확장하여, 하나의 BRAM을 명령어 메모리와 데이터 메모리로 함께 쓰는 단일 메모리 구조로 스마트 도어락을 구현했다.

| 항목                | 내용                                   |
| ------------------- | -------------------------------------- |
| **보드**      | Zybo Z7-20 (Zynq-7000)                 |
| **언어**      | Verilog / Python (어셈블러)            |
| **클럭**      | 125 MHz → 10 MHz (Clocking Wizard IP) |
| **명령어 폭** | 32-bit                                 |
| **메모리**    | Single-Port BRAM, 32-bit × 4096 words |

---

## Features

| 기능             | 설명                                                 |
| ---------------- | ---------------------------------------------------- |
| 비밀번호 입력    | 4~8자리, PMOD를 통해 10-bit one-hot 방식으로 입력    |
| 부분 문자열 매칭 | 입력 흐름 중 비밀번호가 연속으로 포함되면 개방       |
| 입력 취소        | 취소 버튼으로 마지막 자리 삭제 (SHR 기반)            |
| 오답 카운터      | 연속 오답 3회 시 LED 표시 + 입력 제한 타이머         |
| 마스터키         | 별도 저장된 번호(9999)로 즉시 개방                   |
| 비밀번호 변경    | 문이 열린 상태에서만 가능, 새 비밀번호 2회 입력 확인 |
| 상태 LED         | 닫힘 / 열림 / 오답 1~3회 상태를 4-bit 코드로 표시    |

---

## System Architecture

```
[물리 입력]
  pmod_key[9:0]  ─┐
  btn_input       │
  btn_confirm     ├──► input_handler ──► in_port[8:0] ─┐
  btn_cancel      │                                     │
  btn_change      │                                     ▼
  btn_master      ┘                              ┌──────────┐
                                                 │          ├──► bram_addr[11:0]
                          bram_rdata[31:0] ◄─────┤ top_cpu  ├──► bram_wdata[31:0]
                                                 │          ├──► bram_we
                                                 └────┬─────┘
                                                      │ out_port[3:0]
                                                      ▼
                                               output_handler
                                                │           │
                                                ▼           ▼
                                            door_open    led[3:0]
```

- **클럭**: 보드 125 MHz → `clk_wiz_0` → **10 MHz** (`clk_cpu`)
- **리셋**: `ext_reset | ~clk_locked` → `sys_reset` (active-high, 동기)

### CPU 파이프라인 (4-state FSM)

```
FETCH → DECODE → EXECUTE → INCREMENT → FETCH → ...
```

| 상태      | 동작                                                            |
| --------- | --------------------------------------------------------------- |
| FETCH     | `bram_addr ← pc_out` — 명령어 요청                          |
| DECODE    | `IR ← bram_rdata` — 명령어 래치, decoder 신호 확정          |
| EXECUTE   | LOAD·ALU_MEM:`bram_addr ← addr` / STORE: `bram_we` 활성화 |
| INCREMENT | ACC · ZERO_FLAG · out_port 갱신,`PC ← pc_next`             |

---

## Repository Structure

```
simple-cpu-smart-doorlock/
├── rtl/
│   ├── top_doorlock.v      # 최상위 모듈 (클럭·BRAM·CPU·I/O 통합)
│   ├── top_cpu.v           # CPU 최상위 (6개 서브모듈 통합)
│   ├── cpu_fsm.v           # 4-state CPU FSM
│   ├── pc.v                # Program Counter
│   ├── inst_reg.v          # Instruction Register (IR)
│   ├── decoder.v           # opcode 해석 → 제어 신호 (조합논리)
│   ├── accumulator.v       # ACC 레지스터
│   ├── alu.v               # 산술·논리 연산 유닛 (조합논리)
│   ├── input_handler.v     # 디바운서 + one-hot 인코더 + 래치
│   ├── output_handler.v    # out_port → door_open / LED 변환
│   ├── debouncer.v         # 2-Stage Sync + 카운터 기반 채터링 제거
│   ├── define.vh           # 전역 상수 (opcode, state, port 번호 등)
│   ├── doorlock.asm        # 도어락 어셈블리 프로그램
│   ├── assembler.py        # 2-pass 어셈블러 (ASM → COE)
│   ├── doorlock.coe        # BRAM 초기화 파일 (배포용)
│   └── clk_wiz_0.xci       # Clocking Wizard IP (125 MHz → 10 MHz)
├── sim/
│   ├── tb_top_cpu.v            # CPU 통합 테스트벤치
│   ├── tb_top_cpu_young.v      # 개인 검증용 테스트벤치
│   └── tb_top_cpu_wonseok.v    # 개인 검증용 테스트벤치
├── constrs/
│   └── top_doorlock.xdc    # 핀 제약 (Zybo Z7-20)
└── docs/
    ├── 보고서.md
    ├── 하드웨어 파이프라인.md
    ├── spec/
    │   ├── cpu_spec.md
    │   └── 도어락 기능 정리.md
    └── ...
```

---

## Team & Roles

> **2조** | 유경민 · 이윤서 · 한영웅 · 허원석

### 한영웅 · 허원석 — CPU 설계

CPU 코어 전체의 RTL 설계와 검증을 담당했다.

| 모듈              | 역할                                                             |
| ----------------- | ---------------------------------------------------------------- |
| `cpu_fsm.v`     | FETCH/DECODE/EXECUTE/INCREMENT 4-state FSM                       |
| `pc.v`          | 12-bit Program Counter                                           |
| `inst_reg.v`    | 32-bit Instruction Register                                      |
| `decoder.v`     | opcode·funct 2단계 디코딩 → 제어 신호 생성 (조합논리)          |
| `accumulator.v` | 32-bit ACC 레지스터                                              |
| `alu.v`         | ADD/SUB/CMP/LOADI/ADDI/CMPI/SHL/SHR/AND 연산 (조합논리)          |
| `top_cpu.v`     | 6개 서브모듈 통합, BRAM 인터페이스 / IN·OUT 포트 / PC next 로직 |

- ISA 설계 (32-bit, 4-bit opcode, 16종 명령어 + EXT 확장)
- 4-state 고정 파이프라인 → BRAM read latency를 추가 wait state 없이 흡수
- 개인 테스트벤치 작성 및 Vivado 시뮬레이션 검증

### 유경민 — BRAM IP + 어셈블리

명령어·데이터 메모리 설계와 소프트웨어 스택 전체를 담당했다.

| 작업물           | 내용                                                            |
| ---------------- | --------------------------------------------------------------- |
| BRAM IP 설정     | Single-Port, 32-bit × 4096 words                               |
| 메모리 맵 정의   | 명령어 영역(0~209) + 데이터 영역(210~) 분리                    |
| `doorlock.asm` | 비밀번호 입력·비교·변경·오답 처리를 어셈블리로 구현          |
| `assembler.py` | 2-pass 알고리즘 기반 어셈블러 (라벨 해석 → 기계어 → COE 생성) |
| `doorlock.coe` | Vivado BRAM IP 초기화 파일 생성                                 |

- AND 마스킹 기반 부분 문자열 비교 알고리즘 설계
- SHL/SHR 명령어를 활용한 자릿수 입력·취소 구현

### 이윤서 — 입출력 + Top-level

물리 인터페이스 계층과 시스템 통합을 담당했다.

| 모듈                 | 역할                                                |
| -------------------- | --------------------------------------------------- |
| `debouncer.v`      | 2-Stage Sync + 20 ms 안정화 카운터 기반 채터링 제거 |
| `input_handler.v`  | one-hot → 4-bit 인코딩, 64-cycle 래치 홀드         |
| `output_handler.v` | out_port 상태 코드 → door_open / LED 변환          |
| `top_doorlock.v`   | Clocking Wizard·BRAM·CPU·I/O 전체 통합           |
| `tb_top_cpu.v`     | 통합 테스트벤치 작성 및 검증                        |

- Zybo Z7-20 핀 배치 및 XDC 제약 파일 작성
- CPU MAIN_WAIT 루프(~28 사이클)를 고려한 래치 홀드 타이밍 설계

---

## ISA Reference

### Opcode Table

| opcode   | 니모닉   | Type | 동작                                           |
| -------- | -------- | ---- | ---------------------------------------------- |
| `0000` | LOAD     | M    | `ACC ← BRAM[addr]`                          |
| `0001` | STORE    | M    | `BRAM[addr] ← ACC`                          |
| `0010` | ADD      | M    | `ACC ← ACC + BRAM[addr]`, ZERO_FLAG 갱신    |
| `0011` | SUB      | M    | `ACC ← ACC − BRAM[addr]`, ZERO_FLAG 갱신   |
| `0100` | CMP      | M    | `ZERO_FLAG ← (ACC == BRAM[addr])`, ACC 보존 |
| `0101` | LOADI    | I    | `ACC ← imm[27:0]`                           |
| `0110` | ADDI     | I    | `ACC ← ACC + imm`, ZERO_FLAG 갱신           |
| `0111` | CMPI     | I    | `ZERO_FLAG ← (ACC == imm)`, ACC 보존        |
| `1000` | JMP      | J    | `PC ← addr`                                 |
| `1001` | JZ       | J    | `PC ← addr` (ZERO_FLAG=1 일 때)             |
| `1010` | JNZ      | J    | `PC ← addr` (ZERO_FLAG=0 일 때)             |
| `1011` | NOP      | N    | `PC ← PC + 1`                               |
| `1100` | OUT      | P    | `out_port ← ACC[3:0]`                       |
| `1101` | IN       | P    | `ACC ← in_port[port]`                       |
| `1110` | RESERVED | —   | NOP처럼 처리                                   |
| `1111` | EXT      | E    | funct[27:24]로 SHL / SHR / AND 디코딩          |

**EXT funct 코드**

| funct    | 니모닉 | 동작                        |
| -------- | ------ | --------------------------- |
| `0000` | SHL    | `ACC ← ACC << addr`      |
| `0001` | SHR    | `ACC ← ACC >> addr`      |
| `0010` | AND    | `ACC ← ACC & BRAM[addr]` |

### Instruction Encoding

| Type | [31:28] | [27:24]    | [23:12]    | [11:0]    |
| ---- | ------- | ---------- | ---------- | --------- |
| M    | opcode  | reserved   | reserved   | addr      |
| I    | opcode  | imm[27:24] | imm[23:12] | imm[11:0] |
| J    | opcode  | reserved   | reserved   | addr      |
| N    | opcode  | reserved   | reserved   | reserved  |
| P    | opcode  | reserved   | reserved   | port[3:0] |
| E    | opcode  | funct      | reserved   | addr      |

### IN/OUT Port Map

| 포트      | 방향 | 신호              | 입력 소스                  |
| --------- | ---- | ----------------- | -------------------------- |
| `IN 0`  | 입력 | `in_port[3:0]`  | PMOD one-hot → 숫자 0~9   |
| `IN 1`  | 입력 | `in_port[4]`    | BTN1 — 자릿수 입력 확정   |
| `IN 2`  | 입력 | `in_port[5]`    | BTN2 — 비밀번호 전체 확정 |
| `IN 3`  | 입력 | `in_port[6]`    | BTN3 — 마지막 자리 취소   |
| `IN 4`  | 입력 | `in_port[7]`    | SW2 — 비밀번호 변경 모드  |
| `IN 5`  | 입력 | `in_port[8]`    | SW3 — 마스터키            |
| `OUT 0` | 출력 | `out_port[3:0]` | 도어락 상태 코드           |

**out_port 상태 코드**

| 코드     | 상태            | LED |
| -------- | --------------- | --- |
| `0000` | 닫힘 (기본)     | —  |
| `1000` | 열림            | LD3 |
| `0100` | 1회 오답        | LD2 |
| `0010` | 2회 오답        | LD1 |
| `0001` | 3회 오답 + 잠금 | LD0 |

---

## Memory Map

| 주소 범위                      | 내용                                       |
| ------------------------------ | ------------------------------------------ |
| `0x000`~`0x0D1` (0~209)   | 명령어 영역 (`.coe` 로드)                |
| `0x0D2` (210)                | 비밀번호 자릿수                            |
| `0x0D3` (211)                | 정답 비밀번호                              |
| `0x0D4` (212)                | 마스터키 비밀번호                          |
| `0x0D5`~`0x0D8` (213~216) | AND 마스크 상수 (`0xFFFF`~`0xFFFFFFF`) |
| `0x0D9` (217)                | `0xFFFFFFFF`                             |
| `0x0DA` (218)                | 현재 마스킹 데이터                         |
| `0x0E6` (230)                | 입력 버퍼 (자릿수 쌓임)                    |
| `0x0E7` (231)                | 직전 PMOD 입력 (4-bit)                     |
| `0x0E8` (232)                | 실패 횟수 카운터                           |
| `0x0E9` (233)                | 현재 모드                                  |
| `0x0EA` (234)                | UNLOCK FLAG (0: 잠김, 1: 열림)             |
| `0x0F1` (241)                | 잠금 타이머용 큰 상수                      |
| `0x0F2` (242)                | 연산용 상수 1                              |
| `0x0F3` (243)                | 비밀번호 변경 재확인 버퍼                  |
| `0x0F4` (244)                | 재입력 FLAG                                |

---

## Hardware Setup

### 보드 및 핀 배치

| 신호              | 핀         | 설명                      |
| ----------------- | ---------- | ------------------------- |
| `clk`           | K17        | 보드 125 MHz 클럭         |
| `ext_reset`     | K18 (BTN0) | 동기 리셋                 |
| `pmod_key[9:0]` | JE/JD      | 숫자 0~9 one-hot (점퍼선) |
| `btn_input`     | P16 (BTN1) | 자릿수 입력 확정          |
| `btn_confirm`   | K19 (BTN2) | 비밀번호 전체 확정        |
| `btn_cancel`    | Y16 (BTN3) | 마지막 자리 취소          |
| `btn_change`    | W13 (SW2)  | 비밀번호 변경 모드        |
| `btn_master`    | T16 (SW3)  | 마스터키                  |
| `door_open`     | V18 (JD10) | 외부 솔레노이드/LED 제어  |
| `led[3:0]`      | LD3~LD0    | 온보드 상태 표시 LED      |

### 빌드 순서

1. Vivado에서 프로젝트 생성 후 `rtl/` 전체 소스 추가
2. `rtl/clk_wiz_0.xci` Clocking Wizard IP 추가 (125 MHz → 10 MHz)
3. Block Memory Generator IP 추가 (32-bit, 4096-depth, Single-Port)— `rtl/doorlock.coe`를 초기화 파일로 설정
4. `constrs/top_doorlock.xdc` 제약 파일 추가
5. Synthesis → Implementation → Generate Bitstream
6. Program Device

### 어셈블리 수정 시

```bash
cd rtl/
python assembler.py doorlock.asm doorlock.coe
```

생성된 `doorlock.coe`를 BRAM IP 초기화 파일로 교체 후 재빌드한다.

---

## Simulation

```bash
# Vivado Simulator (xsim) 기준
# tb_top_cpu.v 를 top 모듈로 설정 후 시뮬레이션 실행
```

- `sim/tb_top_cpu.v`: 전체 기능 통합 검증
- `sim/tb_top_cpu_young.v`, `sim/tb_top_cpu_wonseok.v`: 개발 중 개인 검증용

---

## Demo Results

시연 영상 링크:

시연은 Zybo Z7-20 보드에서 진행하였으며 아래 기능을 모두 확인했다.

| 시나리오                                                      | 결과                              |
| ------------------------------------------------------------- | --------------------------------- |
| 초기 비밀번호(1234) 입력                                      | Open LED 점등                     |
| 입력 흐름 중 비밀번호 포함 (5·6·**1·2·3·4**·7·8) | Open LED 점등                     |
| 취소 버튼으로 마지막 자리 삭제 후 재입력                      | 정상 인식                         |
| 오답 1회 / 2회 / 3회                                          | LD2 → LD1 → LD0 순차 점등       |
| 3회 연속 오답 후 입력 제한 + 타이머 해제                      | 입력 무반응 → 타이머 후 재개     |
| 마스터키(9999) 입력                                           | 즉시 Open LED 점등                |
| 비밀번호 변경 (새 비밀번호 2회 확인)                          | 변경 후 기존 비밀번호 무효화 확인 |

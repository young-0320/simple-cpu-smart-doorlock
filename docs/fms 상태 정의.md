4 사이클 고정 시스템

bram read ratency가 존재 -> 해당 레이턴시가 있는 상태에서 4사이클 고정 시스템을 구현하기 위해선

시스템 클럭을 125MHz보다 낮출 필요가 있음

(1~50Mhz)

Clocking Wizard ip가 필요

## 상태 전이 조건

무조건 상승 엣지마다 다음 상태로 이동함

fetch->decode->execute->increment

단 동기 reset 신호가 들어오면 다음 클럭 상승 에지에 state 00으로 이동

## 상태별 동작 정의

### fetch state 00

PC 값을 bram 주소 포트에 인가하여 령어를 bram에 요청

### decode state 01

1. bram에서 읽어온 32비트 데이터를 IR에 저장
2. decoder를 통해 `IR[31:28]`의 4비트 Opcode를 해독하여 다음 상태에서 쓸 제어 신호 생성

해독한 명령어 별 동작 분기 필요

### execute state 10

* **메모리 읽기 (`LOAD `, `ADD `, `SUB `, `CMP `):** 피연산자 주소(`IR[11:0]`)를 `bram_addr`에 인가하여 BRAM에 데이터를 요청합니다.
* **메모리 쓰기 (`STORE`):** BRAM에 데이터를 써야 하므로, 주소(`IR[11:0]`)와 데이터(`ACC`)를 인가하고 `bram_we`를 1로 켭니다.
* **즉시값 연산 (`LOADI`, `ADDI`, `CMPI`):** BRAM 접근 없이 즉시값(`IR[27:0]`)을 ALU로 보내 연산을 수행합니다.
* **분기 (`JMP`, `JZ`, `JNZ`):** EXECUTE에서는 특별한 동작 없음. pc_next 계산은 조합 논리로 항상 수행되며, PC 실제 갱신은 INCREMENT에서 일어남.
* **입출력 (`IN`, `OUT`):** EXECUTE에서는 특별한 동작 없음. ACC 갱신(IN) 및 out_port 갱신(OUT)은 INCREMENT에서 처리됨.

### increment state 11

모든 레지스터 갱신이 이 상태에서 일어난다.

* **PC 갱신:** 기본 PC+1, 분기 명령어면 jump_type과 ZERO_FLAG에 따라 addr로 변경
* **ACC 갱신:** LOAD(bram_rdata), IN(selected_input), ALU 연산 결과(alu_result). CMP/CMPI는 ACC 보존
* **ZERO_FLAG 갱신:** zero_we=1인 명령어(ADD, SUB, CMP, ADDI, CMPI, SHL, SHR, AND)에서만 업데이트
* **out_port 갱신:** OUT 명령어 시 ACC[3:0] → out_port

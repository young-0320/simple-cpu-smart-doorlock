`timescale 1ns / 1ps
`include "define.vh"

module debouncer #(
    parameter integer COUNT_MAX = `DEBOUNCE_LIMIT
) (
    input wire clk,
    input wire reset,      // 동기 리셋 
    input wire btn_in,     // 외부 비동기 버튼 입력
    output reg btn_level,  // 디바운싱된 안정된 레벨 신호
    output reg btn_pulse   // 상승 에지에서 한 클럭만 튀는 펄스 신호
);

    // 1. 내부 신호 선언
    reg sync_0, sync_1;    // 2-Stage Synchronizer
    reg [31:0] cnt;        // 타이밍 카운터
    reg btn_stable;        // 현재 안정되었다고 판단된 상태
    reg btn_stable_d;      // 펄스 생성을 위한 지연 레지스터

    // 2. 메인 로직 (동기식 리셋)
    always @(posedge clk) begin
        if (reset) begin
            sync_0       <= 1'b0;
            sync_1       <= 1'b0;
            cnt          <= 32'd0;
            btn_stable   <= 1'b0;
            btn_stable_d <= 1'b0;
            btn_level    <= 1'b0;
            btn_pulse    <= 1'b0;
        end else begin
            // [Step 1] 2-Stage Synchronizer
            sync_0 <= btn_in;
            sync_1 <= sync_0;

            // [Step 2] 디바운싱 카운터 로직
            // 현재 관찰되는 버튼 값(sync_1)이 기존 안정 상태(btn_stable)와 다르면 카운트 시작
            if (sync_1 == btn_stable) begin
                cnt <= 32'd0; // 상태가 같으면 카운터 리셋
            end else begin
                // 설정된 COUNT_MAX 동안 변함없이 유지되면 새로운 상태로 인정
                if (cnt == COUNT_MAX - 1) begin
                    btn_stable <= sync_1;
                    cnt <= 32'd0;
                end else begin
                    cnt <= cnt + 1'b1;
                end
            end

            // [Step 3] 출력 생성 및 엣지 검출
            btn_stable_d <= btn_stable;
            btn_level    <= btn_stable;
            // 이전 사이클은 0이었고 현재 사이클은 1일 때만 펄스 발생 (Rising Edge)
            btn_pulse    <= btn_stable & ~btn_stable_d;
        end
    end

endmodule
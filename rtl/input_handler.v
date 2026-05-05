`timescale 1ns / 1ps
`include "define.vh"

module input_handler (
    input  wire        clk,
    input  wire        reset,

    input  wire [9:0]  pmod_key,
    input  wire        btn_input,
    input  wire        btn_confirm,
    input  wire        btn_cancel,
    input  wire        btn_change,
    input  wire        btn_master,

    output wire [8:0]  in_port
);

    // 래치 유지 클럭 수
    // MAIN_WAIT 루프 사이클 수보다 충분히 크게 설정
    localparam LATCH_HOLD = 6'd63; // 64클럭 유지

    // ---------------------------------------------------------
    // 1. pmod_key debounce → key_level 사용
    // ---------------------------------------------------------

    wire [9:0] key_level;
    wire [9:0] key_pulse_nc;

    genvar i;
    generate
        for (i = 0; i < 10; i = i + 1) begin : gen_key_dbnc
            debouncer u_key_dbnc (
                .clk       (clk),
                .reset     (reset),
                .btn_in    (pmod_key[i]),
                .btn_level (key_level[i]),
                .btn_pulse (key_pulse_nc[i])
            );
        end
    endgenerate

    // ---------------------------------------------------------
    // 2. 버튼/스위치 debounce → pulse
    // ---------------------------------------------------------

    wire pulse_input,   level_nc_input;
    wire pulse_confirm, level_nc_confirm;
    wire pulse_cancel,  level_nc_cancel;
    wire pulse_change,  level_nc_change;
    wire pulse_master,  level_nc_master;

    debouncer u_dbnc_input (
        .clk       (clk), .reset (reset),
        .btn_in    (btn_input),
        .btn_level (level_nc_input),
        .btn_pulse (pulse_input)
    );
    debouncer u_dbnc_confirm (
        .clk       (clk), .reset (reset),
        .btn_in    (btn_confirm),
        .btn_level (level_nc_confirm),
        .btn_pulse (pulse_confirm)
    );
    debouncer u_dbnc_cancel (
        .clk       (clk), .reset (reset),
        .btn_in    (btn_cancel),
        .btn_level (level_nc_cancel),
        .btn_pulse (pulse_cancel)
    );
    debouncer u_dbnc_change (
        .clk       (clk), .reset (reset),
        .btn_in    (btn_change),
        .btn_level (level_nc_change),
        .btn_pulse (pulse_change)
    );
    debouncer u_dbnc_master (
        .clk       (clk), .reset (reset),
        .btn_in    (btn_master),
        .btn_level (level_nc_master),
        .btn_pulse (pulse_master)
    );

    // ---------------------------------------------------------
    // 3. 10비트 one-hot → 4비트 우선순위 인코더 (key_level 기반)
    // ---------------------------------------------------------

    reg [3:0] key_num;

    always @(*) begin
        casez (key_level)
            10'b00000000001: key_num = 4'd0;
            10'b00000000010: key_num = 4'd1;
            10'b00000000100: key_num = 4'd2;
            10'b00000001000: key_num = 4'd3;
            10'b00000010000: key_num = 4'd4;
            10'b00000100000: key_num = 4'd5;
            10'b00001000000: key_num = 4'd6;
            10'b00010000000: key_num = 4'd7;
            10'b00100000000: key_num = 4'd8;
            10'b01000000000: key_num = 4'd9;
            default:         key_num = 4'd0;
        endcase
    end

    // ---------------------------------------------------------
    // 4. 카운터 기반 래치
    //    pulse 발생 → 래치 SET, 카운터 시작
    //    LATCH_HOLD 클럭 후 자동 CLR
    //    유지 중 새 pulse 발생 → 카운터 재시작 (갱신)
    // ---------------------------------------------------------

    reg        latch_input;
    reg        latch_confirm;
    reg        latch_cancel;
    reg        latch_change;
    reg        latch_master;

    reg [5:0]  cnt_input;
    reg [5:0]  cnt_confirm;
    reg [5:0]  cnt_cancel;
    reg [5:0]  cnt_change;
    reg [5:0]  cnt_master;

    always @(posedge clk) begin
        if (reset) begin
            latch_input   <= 1'b0; cnt_input   <= 6'd0;
            latch_confirm <= 1'b0; cnt_confirm <= 6'd0;
            latch_cancel  <= 1'b0; cnt_cancel  <= 6'd0;
            latch_change  <= 1'b0; cnt_change  <= 6'd0;
            latch_master  <= 1'b0; cnt_master  <= 6'd0;
        end
        else begin
            // btn_input
            if (pulse_input) begin
                latch_input <= 1'b1;
                cnt_input   <= LATCH_HOLD;
            end
            else if (cnt_input != 6'd0) begin
                cnt_input <= cnt_input - 1'b1;
            end
            else begin
                latch_input <= 1'b0;
            end

            // btn_confirm
            if (pulse_confirm) begin
                latch_confirm <= 1'b1;
                cnt_confirm   <= LATCH_HOLD;
            end
            else if (cnt_confirm != 6'd0) begin
                cnt_confirm <= cnt_confirm - 1'b1;
            end
            else begin
                latch_confirm <= 1'b0;
            end

            // btn_cancel
            if (pulse_cancel) begin
                latch_cancel <= 1'b1;
                cnt_cancel   <= LATCH_HOLD;
            end
            else if (cnt_cancel != 6'd0) begin
                cnt_cancel <= cnt_cancel - 1'b1;
            end
            else begin
                latch_cancel <= 1'b0;
            end

            // btn_change
            if (pulse_change) begin
                latch_change <= 1'b1;
                cnt_change   <= LATCH_HOLD;
            end
            else if (cnt_change != 6'd0) begin
                cnt_change <= cnt_change - 1'b1;
            end
            else begin
                latch_change <= 1'b0;
            end

            // btn_master
            if (pulse_master) begin
                latch_master <= 1'b1;
                cnt_master   <= LATCH_HOLD;
            end
            else if (cnt_master != 6'd0) begin
                cnt_master <= cnt_master - 1'b1;
            end
            else begin
                latch_master <= 1'b0;
            end
        end
    end

    // ---------------------------------------------------------
    // 5. in_port 출력
    // ---------------------------------------------------------

    assign in_port[3:0] = key_num;
    assign in_port[4]   = latch_input;
    assign in_port[5]   = latch_confirm;
    assign in_port[6]   = latch_cancel;
    assign in_port[7]   = latch_change;
    assign in_port[8]   = latch_master;

endmodule

`timescale 1ns / 1ps

// 서보 모터로 선풍기 머리 회전

module Spin(
    input clk, reset_p,
    input btn,
    input [7:0] duty,
    output servo_pwm
    );
    
    // 버튼으로 기능의 on/off 전환(t플립플롭)
    reg mode;
    always @(posedge clk, posedge reset_p) begin
        if(reset_p)
            mode = 0;
        // 전원이 없을 때는 버튼 입력 무시
        else if(!duty)
            mode = 0;
        else if(btn)
            mode = ~mode;
    end
    
    // duty를 입력하면 pwm 생성
    reg [11:0] duty_servo;
    pwm_Nbit #(.target_freq(50), .N(12), .resolution(4096)) servo_control(
        .clk(clk), .reset_p(reset_p),
        .duty(duty_servo), .pwm(servo_pwm)
    );
    
    // 회전 방향
    reg [1:0] state;
    parameter LEFT = 1'b0;
    parameter RIGHT = 1'b1;
    
    // 분주기(카운트와 함께 회전 속도 설정)
    wire clk_div;
    clock_div #(2_000_000) cd_duty_level(
        .clk(clk), .reset_p(reset_p),
        .div_edge(clk_div)
    );
    
    integer count;
    always @(posedge clk, posedge reset_p) begin
        if(reset_p) begin
            duty_servo = 288;
            state = RIGHT;
            count = 0;
        end
        // 모드가 켜져 있고 전원이 있으면 clk_div 간격으로 실행
        else if(mode && duty && clk_div) begin
            case(state)
                // 우로 회전
                RIGHT: begin
                    // 서보 모터 작동 범위 내에서 회전하기
                    if(duty_servo < 400)
                        duty_servo = duty_servo + 1;
                    else begin
                        // 끝까지 회전하면 잠시 대기
                        if(count < 29)
                            count = count + 1;
                        // 카운트 초기화 & 회전 방향 변경
                        else begin
                            count = 0;
                            state = LEFT;
                        end
                    end
                end
                // 좌로 회전
                LEFT: begin
                    if(duty_servo > 176)
                        duty_servo = duty_servo - 1;
                    else begin
                        if(count < 29)
                            count = count + 1;
                        else begin
                            count = 0;
                            state = RIGHT;
                        end
                    end
                end
            endcase
        end
    end
    
endmodule
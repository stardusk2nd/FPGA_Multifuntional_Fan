`timescale 1ns / 1ps

// LED, DC motor, Servo motor PWM 생성 모듈
// 인스턴스화시 bit 수에 따라 N, resolution 수정 필요
// LED: 7-bit / DC Motor: 8-bit / Servo Motor: 12-bit

module pwm_Nbit #(
    // pwm bit 수
    parameter N = 10,
    // 목표 주파수
    // LED: 10,000Hz / DC Motor: 100Hz / Servo Motor: 50Hz
    parameter target_freq = 100,
    // 시스템 클럭 주파수
    parameter clk_freq = 100_000_000,
    // N-bit pwm의 해상도
    // 예를 들어, 해상도가 1024면 duty는 0~1023으로 설정
    parameter resolution = 1024,
    // 분주비
    parameter divide = clk_freq / target_freq / resolution)
    (
    input clk, reset_p, input [N-1:0] duty,
    output reg pwm
    );
    
    // 구한 분주비 값으로 분주
    wire div_edge;
    clock_div #(divide) cd(
        clk, reset_p, div_edge
    );
    
    // pwm 생성
    reg [N-1:0] count;
    always @(posedge clk, posedge reset_p) begin
        if(reset_p) begin
            count = 0;
            pwm = 0;
        end
        else if(div_edge) begin
            count = count + 1;
            if(count < duty) 
                pwm = 1;
            else
                pwm = 0;
        end
    end
    
endmodule

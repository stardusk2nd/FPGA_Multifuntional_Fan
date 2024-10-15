`timescale 1ns / 1ps

// 조명 제어
// 조명은 duty가 0인 상태에서도 동작 가능한 유일한 기능

// 수동 제어
module led_lighting(
    input clk, reset_p,
    input btn, sw,
    output led_pwm
);
    
    // FSM 사용
    parameter IDLE = 4'b0001;
    parameter LED_1 = 4'b0010;
    parameter LED_2 = 4'b0100; 
    parameter LED_3 = 4'b1000;  
    
    reg [3:0] state, next_state;
    reg [6:0] duty_cycle;
    
    // duty 입력하여 led용 pwm 생성
    pwm_Nbit #(.N(7), .resolution(128), .target_freq(10_000)) LED(
        .clk(clk), .reset_p(reset_p), .duty(duty_cycle), .pwm(led_pwm)
    );
    
    // 스위치 clk에 동기화 및 샘플링(버그 방지)
    reg sw_sampled;
    wire clk_div;
    frequency_divider #(16) switch_sampling(
        .clk(clk), .reset_p(reset_p),
        .clk_div(clk_div)
    );
    always @(posedge clk, posedge reset_p) begin
        if(reset_p)
            sw_sampled = 0;
        else if(clk_div)
            sw_sampled = sw;
    end
    
    // state 변경 실행
    // next_state와 state가 동시에 변하면 에러 가능성 존재
    // 하나는 posedge, 다른 하나는 negedge로
    always @(negedge clk or posedge reset_p) begin
        if (reset_p)
            state <= IDLE;  
        else
            state <= next_state;  
    end
    
    // state 변경 조건
    always @(posedge clk or posedge reset_p) begin
        if (reset_p) begin         
            next_state <= IDLE;
            duty_cycle <= 0;
        end
        // 스위치 1번이 내려져 있어야 작동하도록
        // 스위치가 올라가 있으면 자동 모드로 작동
        else if(sw_sampled) begin
            next_state <= IDLE;
            duty_cycle <= 0;
        end
        // 버튼을 누르면 state 변경
        else begin
            case(state)
                // off
                IDLE : begin
                    if (btn) begin
                        next_state <= LED_1;
                    end else begin
                        duty_cycle <= 0;
                    end
                end
                // 1단계
                LED_1 : begin  
                    if (btn) begin        
                        next_state <= LED_2;          
                    end else begin
                        duty_cycle <= 42;
                    end
                end
                // 2단계
                LED_2 : begin  
                    if (btn) begin
                        next_state <= LED_3;
                    end else begin
                        duty_cycle <= 84;
                    end
                end
                // 3단계
                LED_3 : begin
                    if (btn) begin
                        next_state <= IDLE;  
                    end else begin
                        duty_cycle <= 127;
                    end
                end
            endcase
        end
    end

endmodule

// 자동 제어: photo sensor 사용
module led_lighting_auto(
    input clk, reset_p,
    input sw,
    input [6:0] adc_value,
    output led_pwm
);
    
    reg sw_sampled;
    wire clk_div;
    frequency_divider #(16) switch_sampling(
        .clk(clk), .reset_p(reset_p),
        .clk_div(clk_div)
    );
    
    // 자동 제어 on/off 제어용 스위치 입력.
    // sw = 1이면 자동 제어, sw = 0이면 수동 제어
    // sw는 비동기 신호여서 clk로 동기화 및
    // 값이 튀는걸 방지하기 위해 clk_div 주기로 샘플링
    always @(posedge clk, posedge reset_p) begin
        if(reset_p)
            sw_sampled = 0;
        else if(clk_div)
            sw_sampled = sw;
    end
    
    // duty
    reg [6:0] intensity;
    
    always @(posedge clk, posedge reset_p) begin
        if(reset_p)
            intensity = 0;
        // sw가 1일 때 실행
        // 조도가 특정 값보다 낮으면 3단계로 LED가 활성화됨
        // 조도가 낮을수록 밝게 켜진다
        else if(sw_sampled) begin
            if(adc_value[6:0] < 15)
                intensity = 127;
            else if(adc_value[6:0] < 40)
                intensity = 84;
            else if(adc_value[6:0] < 60)
                intensity = 42;
            else
                intensity = 0;
        end
    end
    
    // duty 입력하여 pwm 생성
    pwm_Nbit #(.N(7), .resolution(128), .target_freq(10_000)) LED(
        .clk(clk), .reset_p(reset_p), .duty(intensity), .pwm(led_pwm)
    );
    
endmodule
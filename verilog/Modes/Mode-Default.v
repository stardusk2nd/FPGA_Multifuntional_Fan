`timescale 1ns / 1ps

// local mode 1번
// 기본 모드: 수동으로 풍속 제어

module local_default(
    input clk, reset_p,
    // 버튼 0: power
    // 버튼 1: speed up
    input [1:0] btn,
    input enable,
    output pwm,
    output reg [7:0] duty
    );
    
    // MAX: 최대 풍속 & MIN: 최소 풍속
    parameter MAX = 255;
    parameter MIN = 80;
    
    // determine power & duty ratio
    always @(posedge clk, posedge reset_p) begin
        if(reset_p) begin
            duty = 0;
        end
        // power button (on/off)
        else if(btn[0]) begin
            if(!duty)
                duty = MIN;
            else
                duty = 0;
        end
        // can be processed only when enable == 1
        else if(enable) begin
            // speed button (1~8)
            if(btn[1]) begin
                if(duty) begin
                    if(duty != MAX)
                        duty = duty + 25;
                    else
                        duty = MIN;
                end
            end
        end
        // 다른 모드에서는 enable이 0이므로 이하를 실행한다
        // duty를 MIN으로 초기화하여, Default mode로 진입할 때 항상 최소 풍속이 되도록 
        else if(duty)
            duty = MIN;
    end
    
    // input "duty" to submodule
    // submodule 'pwm_8bit' print out "pwm"
    pwm_Nbit #(.N(8), .resolution(256), .target_freq(100)) DC_motor(
        clk, reset_p, duty, pwm
    );
    
endmodule
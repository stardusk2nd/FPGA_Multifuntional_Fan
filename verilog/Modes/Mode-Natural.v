`timescale 1ns / 1ps

// local mode 3번
// 자연풍 모드(풍속이 정현파의 형태로 변화)

module local_natural(
    input clk, reset_p,
    input btn,
    input enable,
    output pwm,
    output reg [7:0] duty
    );
    
    // FSM 사용
    reg state, next_state;
    parameter INC = 1'b0;  // increase
    parameter DEC = 1'b1;  // decrease
    
    // frequency divider
    // generate clock with 1 second period
    wire clk_1s;
    clock_div #(100_000_000) fd(
        .clk(clk), .reset_p(reset_p),
        .div_edge(clk_1s)
    ); 
    
    parameter MAX = 255;
    parameter MIN = 80;
    
    // state 전환
    always @(negedge clk, posedge reset_p) begin
        if(reset_p)
            state = INC;
        else
            state = next_state;
    end
    
    // state 전환 조건
    // determine power & duty ratio
    always @(posedge clk, posedge reset_p) begin
        if(reset_p) begin
            duty = 0;
            next_state = INC;
        end
        // power button (on/off)
        else if(btn) begin
            if(!duty)
                duty = MIN;
            else
                duty = 0;
        end
        // speed change
        // if power on, period: 1s
        else if(enable) begin
            if(clk_1s && (duty != 0)) begin
                case(state)
                    // fan speed increasing until MAX
                    INC: begin
                        if(duty != MAX)
                            duty = duty + 25;
                        else begin
                            duty = duty - 25;
                            next_state = DEC;
                        end
                    end
                    // fan speed decreasing until MIN
                    DEC: begin
                        if(duty != MIN)
                            duty = duty - 25;
                        else begin
                            duty = duty + 25;
                            next_state = INC;
                        end
                    end
                endcase
            end
        end
        // 다른 모드에서는 enable이 0이므로 이하를 실행한다
        // duty를 MIN으로 초기화하여, Natural mode로 진입할 때 항상 최소 풍속이 되도록 
        else if(duty)
            duty = MIN;
    end
    
    // input "duty" to submodule
    // submodule 'pwm_8bit' print out "pwm"
    pwm_Nbit #(.N(8), .resolution(256), .target_freq(100)) DC_motor(
        clk, reset_p, duty, pwm
    );
    
endmodule

`timescale 1ns / 1ps

// 시간이 경과하면 duty를 강제로 0으로 한다

module fan_timer(
    input clk, reset_p,
    input btn,          // 타이머 시간 셋업 버튼
    input [7:0] duty,
    output [2:0] led,   // 타이머 시간 출력 LED
    output reg timeout  // duty를 0으로
    );
    
    // 분주기(1ms)
    wire clk_div;
    clock_div #(100_000) second(
        .clk(clk), .reset_p(reset_p),
        .div_edge(clk_div)
    );
    
    integer count, timer;
    always @(posedge clk, posedge reset_p) begin
        if(reset_p) begin
            count = 0;
            timer = 0;
        end
        // 전원이 꺼진 상태에서는 셋업 불가
        else if(!duty) begin
            count = 0;
            timer = 0;
        end
        // 전원이 있고 버튼이 눌리면
        else if(btn && duty) begin
            case(timer)
                // off
                0: timer = 10_000;
                // 10초
                10_000: begin
                    timer = 30_000;
                    count = 0;
                end
                // 30초
                30_000: begin
                    timer = 50_000;
                    count = 0;
                end
                // 50초
                50_000: begin
                    timer = 0;
                    count = 0;
                end
            endcase
        end
        else if(timer) begin
            if(clk_div) begin
                if(count < timer - 1)
                    count = count + 1;
                else begin
                    count = 0;
                    timeout = 1;    // timeout edge 검출
                end
            end
        end
        else timeout = 0;   // 엣지 검출 후 다음 clk에 timeout 초기화
    end
    
    // LED로 현재 세팅된 시간 출력
    // 10초: 1개 / 30초: 2개 / 50초: 3개
    assign led = (timer == 50_000)? 3'b111 :
                 (timer == 30_000)? 3'b011 : 
                 (timer == 10_000)? 3'b001 : 3'b000;
    
endmodule
`timescale 1ns / 1ps

// 버튼 입력 및 스위칭할 때 buzzer로 beep 출력 
// 조도가 낮으면 출력하지 않음

module beep(
    input clk, reset_p,
    input [6:0] btn, [1:0] sw,
    input [7:0] duty,
    // 조도값
    input [6:0] adc_value,
    output buzz_passive
    );
    
    // 스위치 사용 시 beep 출력 위해 엣지 검출
    // 버튼은 top 모듈에서 엣지 검출이 되어 있어 불필요. 값만 받아오면 됨
    wire [3:0] sw_edge;
    // 스위치 올릴 때 beep
    edge_detector_p sw_sound_1(
        .clk(clk), .reset_p(reset_p), .cp(sw[0]), .pedge(sw_edge[0])
    );
    // 스위치 내릴 때 beep
    edge_detector_n sw_sound_2(
        .clk(clk), .reset_p(reset_p), .cp(sw[0]), .nedge(sw_edge[1])
    );
    edge_detector_p sw_sound_3(
        .clk(clk), .reset_p(reset_p), .cp(sw[1]), .pedge(sw_edge[2])
    );
    edge_detector_n sw_sound_4(
        .clk(clk), .reset_p(reset_p), .cp(sw[1]), .nedge(sw_edge[3])
    );
    
    reg buzz; integer count;
    always @(posedge clk or posedge reset_p) begin
        if(reset_p) begin
            buzz = 0; count = 0;
        end
        // 조도가 40보다 낮으면 전체 음소거
        else if(adc_value < 40) begin
            buzz = 0; count = 0;
        end
        // power 버튼은 0인 상태에서도 beep 출력 
        else if(btn[0])
            buzz = 1;
        // 조명 버튼도 duty가 0인 상태에서도 beep 출력
        // 단, 자동 조명 모드에서는 출력하지 않음
        else if(btn[4] && !sw[1])
            buzz = 1;
        // 그 외는 duty가 있어야(팬이 돌아가는 상태에서만) 출력
        else if((btn[1] || btn[2] || btn[3] || btn[5] || btn[6] || sw_edge) && duty)
            buzz = 1;
        // 0.2초간 출력
        else if(buzz) begin
            if(count < 19_999_999)
                count = count + 1;
            else begin
                buzz = 0; count = 0;
            end
        end
    end
    
    // 분주기
    // passive buzzer 사용하여 별도로 주파수 입력 필요
    wire clk_div;
    frequency_divider #(16) freq_sound(
        clk, reset_p, clk_div
    );
    
    assign buzz_passive = buzz? clk_div : 0;
    
endmodule

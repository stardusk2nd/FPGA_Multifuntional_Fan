`timescale 1ns / 1ps

// 버튼 입력 디바운싱 & 롱버튼 제어

// long button module
// 이 모듈은 팬 스피드 제어에만 사용됨(길게 누르면 빠르게 스피드 전환)
module btn_cntr_long(
    input clk, reset_p, btn,
    output btn_pedge,       // 숏 버튼 output
    output reg held_pedge   // 롱 버튼 output
    );
    
    // 디바운싱 위한 분주기
    wire clk_ms;
    clock_div #(100_000) debouncing(
        .clk(clk), .reset_p(reset_p),
        .div_edge(clk_ms)
    );
    
    reg btn_sampled;
    integer wait_count;
    integer count;

    always @(posedge clk or posedge reset_p) begin
        if(reset_p) begin 
            btn_sampled = 0; 
            wait_count = 0; 
            count = 0; 
            held_pedge = 0;
        end
        // clk_ms 주기로 버튼 입력 샘플링하여 디바운싱
        else if(clk_ms) begin
            btn_sampled = btn;
            // 버튼이 눌려 있으면
            if(btn_sampled) begin
                // 0.7초 대기
                if(wait_count < 699)
                    wait_count = wait_count + 1;
                else begin
                    // 0.1초에 한 번 입력받음
                    if(count < 99)
                        count = count + 1;
                    else begin
                        count = 0;
                        held_pedge = 1; // 롱버튼 엣지 검출
                    end 
                end
            end
            // 버튼이 떼지면 카운트 초기화
            else begin
                wait_count = 0;
                count = 0;
            end
        end
        else held_pedge = 0;    // 엣지 검출 후 다음 clk에서 바로 0으로 초기화
    end
	
	// 숏버튼 엣지 검출
    edge_detector_p ed0(
        .clk(clk), .reset_p(reset_p), .cp(btn_sampled),
        .pedge(btn_pedge)
    );
    
endmodule

// 숏 버튼만
// 하강 엣지 동작(버튼에서 손이 떼질 때 동작)
// 대부분의 모듈이 사용
module btn_cntr_n(
    input clk, reset_p, btn,
    output btn_nedge
    );
    
    wire clk_ms;
    clock_div #(100_000) debouncing(
        .clk(clk), .reset_p(reset_p),
        .div_edge(clk_ms)
    );
    
    reg btn_sampled;

    always @(posedge clk or posedge reset_p) begin
        if(reset_p) begin 
            btn_sampled = 0; 
        end
        else if(clk_ms) begin
            btn_sampled = btn;
        end
    end
	
    edge_detector_n ed0(
        .clk(clk), .reset_p(reset_p), .cp(btn_sampled),
        .nedge(btn_nedge)
    );
        
endmodule

// local mode 변경 모듈에만 사용
// 짧게 누르면 auto mode, 길게 누르면 natural mode로 이동하도록
module btn_cntr_long_short (
    input  clk,
    input  reset_p,
    input  button,
    output reg short_press, // 숏버튼
    output reg long_press   // 롱버튼
);

    parameter LONG_PRESS_COUNT = 27'd50_000_000;

    reg button_prev;
    reg [27:0] counter;

    wire btn_pedge;

    button_cntr_long long( .btn(button), .clk(clk), .reset_p(reset_p), .btn_long(btn_pedge));

    always @(posedge clk or posedge reset_p) begin
        if (reset_p) begin
            counter <= 0;
            short_press <= 0;
            long_press <= 0;
            button_prev <= 0;
        end 
        else begin
            button_prev <= btn_pedge;
            if (btn_pedge == 1 && button_prev == 0) begin
                counter <= 0;
            end 
            else if (btn_pedge && button_prev) begin
                counter <= counter + 1;
            end 
            else if (btn_pedge == 0 && button_prev == 1) begin
                if (counter > LONG_PRESS_COUNT) begin
                    counter <= 0;
                    short_press <= 0;
                    long_press <= 1;
                end 
                else begin
                    counter <=0;
                    short_press <= 1;
                    long_press <= 0;
                end
            end 
            else begin
                short_press <= 0;
                long_press <= 0;
            end
        end
    end

endmodule

// 상단의 module btn_cntr_long_short를 위한 하위 모듈
module button_cntr_long(
    input btn, clk, reset_p,
    output btn_long
);

    wire  btn_clk;
    
    reg [16:0] clk_div;
    
    reg debounced_btn;
    
    always @ (posedge clk) clk_div = clk_div  + 1; 
    
    edge_detector_p  ed1 (.clk(clk), .reset_p(reset_p), .cp(clk_div[16]), .pedge(btn_clk));
    
    
    always @(posedge clk, posedge reset_p) begin
        if(reset_p) debounced_btn = 0;
        else if (btn_clk) debounced_btn = btn;
    end
    
    assign btn_long = debounced_btn;

endmodule
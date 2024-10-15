`timescale 1ns / 1ps

// 분주기

// 엣지 검출 방식
// system clock을 N배 분주
module clock_div #(parameter N = 100)(
    input clk, reset_p,
    output reg div_edge
    );
    
    integer count;
    
    always @(posedge clk, posedge reset_p) begin
        if(reset_p) begin
            count = 0; div_edge = 0;
        end
        else if(count < (N-1)) begin
            count = count + 1;
            div_edge = 0;   // 엣지 검출
        end
        else begin
            count = 0; div_edge = 1;    // 다음 clk에 초기화
        end
    end
    
endmodule

// 카운터 방식
// system clock을 2^N배 분주
module frequency_divider #(parameter N = 15)(
    input clk, reset_p,
    output clk_div
);
    reg [N-1:0] count;
    always @(posedge clk, posedge reset_p) begin
        if(reset_p)
            count = 0;
        else begin
            count = count + 1;
        end
    end
    edge_detector_p ed(
        .clk(clk), .reset_p(reset_p), .cp(count[N-1]),
        .pedge(clk_div)
    );
endmodule
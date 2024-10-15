`timescale 1ns / 1ps

// T 플립플롭
// 버튼에 따른 토글에 사용됨

module flipflop_t_p(
    input t, clk, reset_p,
    output reg q
    );

    always @(posedge clk, posedge reset_p) begin
        if(reset_p) q = 0;
        else if(t) q = ~q;
    end
endmodule
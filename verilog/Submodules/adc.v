`timescale 1ns / 1ps

// analog to digital converter
// 포토 센서의 값을 읽는다
// 버튼 사운드 자동 off / LED 자동 점등에 사용

module adc(
    input clk, reset_p,
    input vauxp6, vauxn6,   // analog 입력 포트
    output reg [6:0] adc_value // digital로 변환한 입력값
);

    // XADC IP 인스턴스화
    wire eoc_out;
    wire [15:0] do_out;
    wire [4:0] channel_out;
    xadc_wiz_0 adc(
        .daddr_in({2'b00, channel_out}),
        .dclk_in(clk),
        .den_in(eoc_out),
        .reset_in(reset_p),
        .vauxp6(vauxp6),
        .vauxn6(vauxn6),
        .channel_out(channel_out),
        .do_out(do_out),
        .eoc_out(eoc_out)
    );
    
    // 변환 완료 sign 검출
    wire read;
    edge_detector_p eoc_edge(
        .clk(clk), .reset_p(reset_p),
        .cp(eoc_out), .pedge(read)
    );
    
    always @(posedge clk or posedge reset_p) begin
        if (reset_p) begin
            adc_value = 0;
        end
        // 하위 9-bit는 버리고 7-bit 값을 받는다
        // 해상도: 0~127
        else if(read) begin
            adc_value = do_out[15:9];
        end
    end
    
endmodule
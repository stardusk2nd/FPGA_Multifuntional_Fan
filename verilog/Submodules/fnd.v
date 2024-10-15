`timescale 1ns / 1ps

// fnd에 온도 출력 용도

// an(=com) 시프트
// 온도는 최대 두자리므로 2개의 fnd만 사용
module counter_ring_fnd(
    input clk, reset_p,
    output reg [1:0] shift  // 2자리 온도를 출력하기 때문에 하위 2-bit만 사용
);
    
    // 분주기
    wire clk_div;
    frequency_divider #(17) fd(
        .clk(clk), .reset_p(reset_p), .clk_div(clk_div)
    );
    
    always @(posedge clk, posedge reset_p) begin
        if(reset_p) shift = 0;
        else if(clk_div) begin
            if(shift == 2'b01)
                shift = 2'b10;
            else shift = 2'b01;
        end
    end
endmodule

// fnd 숫자 출력
// decimal 출력하므로 A~는 비활성화
// dp(소숫점) 사용하지 않아 seg 최상위 1비트 비활성화
module seven_segment(
    input [3:0] value,
    output reg [6:0] seg
    );
    
    always @(*) begin
        case(value)
                            // gfe_dcba
            4'b0000 : seg = 7'b100_0000; // 0
            4'b0001 : seg = 7'b111_1001; // 1
            4'b0010 : seg = 7'b010_0100; // 2
            4'b0011 : seg = 7'b011_0000; // 3
            4'b0100 : seg = 7'b001_1001; // 4
            4'b0101 : seg = 7'b001_0010; // 5
            4'b0110 : seg = 7'b000_0010; // 6
            4'b0111 : seg = 7'b111_1000; // 7
            4'b1000 : seg = 7'b000_0000; // 8
            4'b1001 : seg = 7'b001_0000; // 9
//            4'b1010 : seg = 7'b000_1000; // A
//            4'b1011 : seg = 7'b000_0011; // b
//            4'b1100 : seg = 7'b100_0110; // C
//            4'b1101 : seg = 7'b010_0001; // d
//            4'b1110 : seg = 7'b000_0110; // E
//            4'b1111 : seg = 7'b000_1110; // F
            default : seg = 7'b111_1111; // Default (All segments off)
        endcase
    end
endmodule

// an에 따른 출력값 제어
module fnd_4digit_cntr(
    input clk, reset_p,
    // 2자리(8-bit) 출력
    input [7:0] value,
    output [3:0] an, output [6:0] seg
);  
    
    // 두 자리만 사용하므로 an 상위 2-bit 비활성화
    // ring counter: shift anode
    assign an[3:2] = 2'b11;
    counter_ring_fnd rc(
        .clk(clk), .reset_p(reset_p),
        .shift(an[1:0])
    );
    
    reg [3:0] temp;
    always @(posedge clk, posedge reset_p) begin
        if(reset_p) begin
            temp = 0;
        end
        else begin
            case(an)
                4'b1110 : temp = value[3:0];    // 첫째 자리
                4'b1101 : temp = value[7:4];    // 둘째 자리
            endcase
        end
    end
    // 값을 seven segment 코드로 변환
    seven_segment fnd(.value(temp), .seg(seg));
    
endmodule

// binary to decimal
module bin_to_dec(
    input [7:0] bin,
    output reg [7:0] bcd  // BCD를 8-bit 크기로 설정
);

    reg [3:0] i;

    always @(bin) begin
        bcd = 0;
        // 8-bit 처리 위해 8번 반복
        for (i = 0; i < 8; i = i + 1) begin
            // bcd 레지스터를 왼쪽으로 한 비트 시프트하고
            // 현재 이진 입력의 비트를 bcd의 최하위 비트에 추가
            bcd = {bcd[6:0], bin[7 - i]};
            if (i < 7 && bcd[3:0] > 4) bcd[3:0] = bcd[3:0] + 3;
            if (i < 7 && bcd[7:4] > 4) bcd[7:4] = bcd[7:4] + 3;
        end
    end
endmodule
`timescale 1ns / 1ps

// 자동 pause 기능
// 초음파 센서로 전방에 물체가 감지되지 않으면 pwm = 0으로 한다
// duty를 건드리면 풍속이 변하므로, pwm을 0으로 하여 임시로 팬만 정지한다
// 물체가 감시되면 원래의 풍속으로 다시 pwm이 생성된다

module auto_pause(
    input clk, reset_p, sw,
    input [7:0] duty,
    input pwm,  // 입력
    output pwm_onoff,   // MUX를 거친 출력
    input echo, output trig
    );
    
    // 센서로 읽어온 거리 값
    // 0.1cm 단위로 읽어온다
    wire [11:0] distance;
    ultrasonic_sensing uls(
        .clk(clk), .reset_p(reset_p),
        .distance(distance),
        .echo(echo), .trig(trig)
    );
    
    // 거리가 50cm보다 작으면 일시정지
    wire fan_off;
    assign fan_off = (sw && duty && (distance > 500))? 1 : 0;
    // pause 모드가 켜져 있고, 전원이 켜져 있고, 센서와의 거리가 50cm보다 크면 일시 정지
    // 그 외의 경우 pwm 출력
    assign pwm_onoff = fan_off? 0: pwm;
    
endmodule

// 초음파 센서 제어 모듈
module ultrasonic_sensing(
    input clk, reset_p,
    input echo,
    output reg trig,
    output reg [11:0] distance
);
    
    parameter IDLE = 3'b001,
              TRIGGER = 3'b010,
              CALC_DISTANCE = 3'b100;
              
    reg [2:0] state, next_state;
    
    always @(negedge clk, posedge reset_p) begin
        if(reset_p)
            state = IDLE;
        else
            state = next_state;
    end
    
    wire div_580;
    clock_div #(580) clock_divider(
        .clk(clk), .reset_p(reset_p),
        .div_edge(div_580)
    );
    
    wire echo_nedge;
    edge_detector_n echo_edge_detection(
        .clk(clk), .reset_p(reset_p),
        .cp(echo),
        .nedge(echo_nedge)
    );
    
    integer counter, distance_counter;

    always @(posedge clk, posedge reset_p) begin
        if(reset_p) begin
            trig = 0;
            distance = 0;
            next_state = IDLE;
            counter = 0;
            distance_counter = 0;
        end
        else begin
            case(state)
                IDLE: begin
                    if(counter < 30_000_000) begin
                        counter = counter + 1;
                    end
                    else begin
                        counter = 0;
                        distance_counter = 0;
                        next_state = TRIGGER;
                    end
                end
                
                TRIGGER: begin
                    if(counter < 1000) begin
                        trig = 1;
                        counter = counter + 1;
                    end
                    else begin
                        counter = 0;
                        trig = 0;
                        next_state = CALC_DISTANCE;
                    end
                end
                
                CALC_DISTANCE: begin
                    if(echo) begin
                        if(div_580)
                            distance_counter = distance_counter + 1;
                    end
                    else if(echo_nedge) begin
                        distance = distance_counter;
                        next_state = IDLE;
                    end
                end
                default: next_state = IDLE;
            endcase
        end
    end
    
endmodule
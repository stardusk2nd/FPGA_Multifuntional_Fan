`timescale 1ns / 1ps

module top_fan(
    input clk, reset_p,
    input [5:0] btn, input [1:0] sw,
    input vauxp6, vauxn6,
    inout dht11_data,
    input echo, output trig,
    output motor_pwm, led_pwm, servo_pwm,
    output [13:0] led,
    output buzz,
    output [3:0] an, [6:0] seg
    );
    
    //////////////////////////////////////////////
    // generate debounced button input
    wire [8:0] btn_edge;
    // 전원 버튼
    btn_cntr_n btn_power(
        .clk(clk), .reset_p(reset_p), .btn(btn[0]), .btn_nedge(btn_edge[0])
    );
    // 모드 변경 버튼 (숏,롱버튼)
    // 숏버튼: auto mode로 번경 / 롱버튼: natural 모드로 변경
    btn_cntr_long_short local_mode_change(
        .clk(clk), .reset_p(reset_p), .button(btn[1]),
        .short_press(btn_edge[1]), .long_press(btn_edge[2])
    );
    // 타이머 셋업 버튼
    btn_cntr_n btn_timer( 
        .clk(clk), .reset_p(reset_p), .btn(btn[2]), .btn_nedge(btn_edge[3])
    );
    // led 밝기 제어 버튼
    btn_cntr_n btn_led_manual( 
        .clk(clk), .reset_p(reset_p), .btn(btn[3]), .btn_nedge(btn_edge[4])
    );
    // 서보 모터 회전 버튼
    btn_cntr_n btn_servo_spin( 
        .clk(clk), .reset_p(reset_p), .btn(btn[4]), .btn_nedge(btn_edge[5])
    );
    // default mode 풍속 제어 버튼 (숏,롱버튼)
    // 짧게 누르면 1번 입력, 길게 누르면 지속적으로 입력
    btn_cntr_long btn_fan_speed( 
        .clk(clk), .reset_p(reset_p), .btn(btn[5]), .btn_pedge(btn_edge[6]), .held_pedge(btn_edge[7])
    );
    assign btn_edge[8] = btn_edge[6] || btn_edge[7];
    
    //////////////////////////////////////////////
    // mode change function
    reg [2:0] mode;
    // duty는 각 기능 모듈에 입력으로 넣는다. 전원이 있는지 없는지 알기 위해
    // !duty면 전원은 꺼져 있고, 기능들은 (led 점등 제외) 작동하지 않는다
    wire [7:0] duty;
    
    parameter DEFAULT   = 3'b001;
    parameter AUTO      = 3'b010;
    parameter NATURAL   = 3'b100;
    
    // mode change
    always @(posedge clk, posedge reset_p) begin
        if(reset_p) begin
            mode = DEFAULT;
        end
        // duty가 0이면(=전원이 꺼지면) 기본으로 초기화
        else if(!duty) begin
            mode = DEFAULT;
        end
        else if(mode == DEFAULT) begin
            if(btn_edge[1])
                mode = AUTO;
            else if(btn_edge[2])
                mode = NATURAL;
        end
        else if(btn_edge[1])
            mode = DEFAULT;
    end
    
    //////////////////////////////////////////////
    // submodule instance
    wire pwm, pwm_d, pwm_a, pwm_n;
    wire [7:0] duty_d, duty_a, duty_n;
    // DEMUX
    assign pwm = (mode == DEFAULT)? pwm_d : (mode == AUTO)? pwm_a : pwm_n;
    assign duty = (mode == DEFAULT)? duty_d : (mode == AUTO)? duty_a : duty_n;
    
    // 버튼으로도 전원이 꺼지고, 또는 타이머로도 끌 수 있도록
    wire timeout, turn_off;
    assign turn_off = btn_edge[0] || timeout;
    
    // local mode
    local_default normal_mode(
        .clk(clk), .reset_p(reset_p), .btn({btn_edge[8], turn_off}),    // speed up, power button
        .enable(mode[0]),
        .pwm(pwm_d), .duty(duty_d)
    );
    local_natural natural_wind_mode(
        .clk(clk), .reset_p(reset_p), .btn(turn_off),
        .enable(mode[2]),
        .pwm(pwm_n), .duty(duty_n)
    );
    local_auto auto_mode(
        .clk(clk), .reset_p(reset_p), .btn(turn_off),
        .enable(mode[1]),
        .dht11_data(dht11_data),
        .motor_pwm(pwm_a), .duty_value(duty_a),
        .seg(seg), .an(an)
    );
    
    // 초음파 모듈
    auto_pause UltraSonic(
        .clk(clk), .reset_p(reset_p), .sw(sw[0]),
        .trig(trig), .echo(echo),
        .duty(duty), .pwm(pwm), .pwm_onoff(motor_pwm)
    );
    // 타이머 모듈
    fan_timer shut_off(
        .clk(clk), .reset_p(reset_p),
        .btn(btn_edge[3]), .timeout(timeout),
        .duty(duty),
        .led(led[10:8])
    );
    // led 모듈
    wire led_pwm_a, led_pwm_p;
    assign led_pwm = sw[1]? led_pwm_p : led_pwm_a;
    // led 수동
    led_lighting lamp(
        .clk(clk), .reset_p(reset_p), .sw(sw[1]),
        .btn(btn_edge[4]), .led_pwm(led_pwm_a)
    );
    // 조도 센서 값 읽기
    wire [6:0] adc_value;
    adc XADC(
        .clk(clk), .reset_p(reset_p),
        .vauxp6(vauxp6), .vauxn6(vauxn6),
        .adc_value(adc_value)
    );
    // led 자동
    led_lighting_auto automatic_lamp(
        .clk(clk), .reset_p(reset_p), .sw(sw[1]),
        .adc_value(adc_value),
        .led_pwm(led_pwm_p)
    );
    // 서보 모터 모듈
    Spin servo_motor(
        .clk(clk), .reset_p(reset_p), .btn(btn_edge[5]),
        .duty(duty), .servo_pwm(servo_pwm)
    );
    // 버저 모듈
    beep buzzer_output(
        .clk(clk), .reset_p(reset_p), .btn(btn_edge[6:0]), .sw(sw), 
        .adc_value(adc_value), .duty(duty), .buzz_passive(buzz)
    );
    
    //////////////////////////////////////////////
    // assign LEDs
    // fan speed led
    assign led[0] = (duty >= 80)? 1 : 0; assign led[1] = (duty >= 105)? 1 : 0;
    assign led[2] = (duty >= 130)? 1 : 0; assign led[3] = (duty >= 155)? 1 : 0;
    assign led[4] = (duty >= 180)? 1 : 0; assign led[5] = (duty >= 205)? 1 : 0;
    assign led[6] = (duty >= 230)? 1 : 0; assign led[7] = (duty == 255)? 1 : 0;
    // led for printing current mode
    assign led[13:11] = ((mode == DEFAULT) && duty)? 3'b001 :
                        (mode == AUTO)? 3'b010 : 
                        (mode == NATURAL)? 3'b100 : 3'b000;
endmodule

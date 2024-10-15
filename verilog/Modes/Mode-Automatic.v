`timescale 1ns / 1ps

// local mode 2
// 온도에 따라 자동으로 팬 스피드를 제어

module local_auto(
	input clk, reset_p, enable,
	input btn,
	inout dht11_data,				// 온도 센서 데이터 in/out
	output motor_pwm,				// PWM 출력
	output [3:0] an, output [6:0] seg,
	output reg [7:0] duty_value
);
	
	wire [7:0] temp;		// 온도 인스턴스에서 값 받아옴 
	dht11_cntr dht11(
	   .clk(clk), .reset_p(reset_p), .dht11_data(dht11_data), .temperature(temp)
	);	// 온습도 센서 인스턴스
	
	// 출력 위해 10진수로 변환 
	wire [7:0] bcd_temp;
	bin_to_dec	b2d_temp(.bin(temp), .bcd(bcd_temp));
	// FND에 온도 출력
	fnd_4digit_cntr fnd(
	   .clk(clk), .reset_p(reset_p),
	   .value(bcd_temp),
	   .seg(seg), .an(an)
	);
	
	// 버튼으로 파워 on/off
	wire power;
	flipflop_t_p(
	   .clk(clk), .reset_p(reset_p),
	   .t(btn), .q(power)
	);
	
	// MUX
    always @(*) begin
        // local mode가 2번이면 & 파워가 켜지면
        if (enable && power) begin
            // 온도가 낮으면 duty를 1로
            // 팬은 돌아가지 않지만 전원은 on으로 유지
            if (temp <= 20) begin
                duty_value = 1;
            end else if (temp <= 22) begin
                duty_value = 80;
            end else if (temp <= 24) begin
                duty_value = 105;
            end else if (temp <= 26) begin
                duty_value = 130;
            end else if (temp <= 27) begin
                duty_value = 155;
            end else if (temp <= 28) begin
                duty_value = 180;
            end else if (temp <= 29) begin
                duty_value = 205;
            end else if (temp <= 30) begin
                duty_value = 230;
            end else begin
                duty_value = 255;
            end
        end
        // local 모드가 다를 때는 기능 off
        else begin
            duty_value = 0;
    end
end
	
//	always @(*) begin
//	   if(enable && power) begin
//	       case(temp)
//	           8'd15, 8'd16, 8'd17, 8'd18, 8'd19 : duty_value = 0;		//duty 40%
//	           8'd20, 8'd21, 8'd22, 8'd23, 8'd24 : duty_value = 105;	//duty 60%
//	           8'd25, 8'd26, 8'd27, 8'd28, 8'd29 : duty_value = 155;	//duty 80%
//	           default 						     : duty_value = 255;	//duty 100%
//	       endcase
//	   end
//	   else duty_value = 0;
//	end

	// duty_value로 받아온 값을 motor_pwm으로 최종 출력
	pwm_Nbit #(.N(8), .resolution(256), .target_freq(100)) DC_motor(
        .clk(clk), .reset_p(reset_p), .duty(duty_value), .pwm(motor_pwm)
    );
	
endmodule

// dht11 센서로 온도 값을 읽어온다
module dht11_cntr(
    input clk, reset_p,
    inout dht11_data,
    output reg [7:0] temperature
);

    parameter S_IDLE        = 6'b00_0001;
    parameter S_LOW_18MS    = 6'b00_0010;
    parameter S_HIGH_20US   = 6'b00_0100;
    parameter S_LOW_80US    = 6'b00_1000;
    parameter S_HIGH_80US   = 6'b01_0000;
    parameter S_READ_DATA   = 6'b10_0000;
    
    parameter S_WAIT_PEDGE  = 2'b01;
    parameter S_WAIT_NEDGE  = 2'b10;
    
    reg [21:0] count_usec;
    wire clk_usec;
    reg count_enable;
    
    clock_div #(100) us_clk(
        .clk(clk), .reset_p(reset_p), .div_edge(clk_usec)
    );
    
    always @(negedge clk or posedge reset_p) begin
        if (reset_p)
            count_usec <= 0;
        else if (clk_usec && count_enable)
            count_usec <= count_usec + 1;
        else if (count_enable == 0)
            count_usec <= 0;
    end
    
    wire dht_nedge, dht_pedge;
    
    edge_detector_p ed0(
        .clk(clk), .reset_p(reset_p), .cp(dht11_data), 
        .pedge(dht_pedge)
    );
    edge_detector_n ed1(
        .clk(clk), .reset_p(reset_p), .cp(dht11_data), 
        .nedge(dht_nedge)
    );
    
    reg [5:0] state, next_state;
    reg [1:0] read_state;
    
    always @(negedge clk or posedge reset_p) begin
        if (reset_p)
            state <= S_IDLE;
        else
            state <= next_state;
    end
    
    reg [39:0] temp_data;
    reg [5:0] data_count;
    reg dht11_buffer;
    
    assign dht11_data = dht11_buffer;
    
    always @(posedge clk or posedge reset_p) begin
        if (reset_p) begin
            count_enable <= 0;
            next_state <= S_IDLE;
            read_state <= S_WAIT_PEDGE;
            data_count <= 0;
            dht11_buffer <= 'bz;
            temp_data <= 0;
        end else begin
            case (state)
                S_IDLE: begin
                    if (count_usec < 22'd3_000_000) begin
                        count_enable <= 1;
                        dht11_buffer <= 'bz;
                    end else begin
                        next_state <= S_LOW_18MS;
                        count_enable <= 0;
                    end
                end
                S_LOW_18MS: begin
                    if (count_usec < 22'd18_000) begin
                        dht11_buffer <= 0;
                        count_enable <= 1;
                    end else begin
                        next_state <= S_HIGH_20US;
                        count_enable <= 0;
                        dht11_buffer <= 'bz;
                    end
                end
                S_HIGH_20US: begin
                    count_enable <= 1;
                    if (count_usec > 22'd100) begin
                        next_state <= S_IDLE;
                        count_enable <= 0;
                    end
                    if (dht_nedge) begin
                        next_state <= S_LOW_80US;
                        count_enable <= 0;
                    end
                end
                S_LOW_80US: begin
                    count_enable <= 1;
                    if (count_usec > 22'd100) begin
                        next_state <= S_IDLE;
                        count_enable <= 0;
                    end
                    if (dht_pedge) begin
                        next_state <= S_HIGH_80US;
                    end
                end
                S_HIGH_80US: begin
                    if (dht_nedge) begin
                        next_state <= S_READ_DATA;
                    end
                end
                S_READ_DATA: begin
                    case (read_state)
                        S_WAIT_PEDGE: begin
                            if (dht_pedge)
                                read_state <= S_WAIT_NEDGE;
                            count_enable <= 0;
                        end
                        S_WAIT_NEDGE: begin
                            if (dht_nedge) begin
                                if (count_usec < 45) begin
                                    temp_data <= {temp_data[38:0], 1'b0};
                                end else begin
                                    temp_data <= {temp_data[38:0], 1'b1};
                                end
                                data_count <= data_count + 1;
                                read_state <= S_WAIT_PEDGE;
                            end else
                                count_enable <= 1;
                            if (count_usec > 22'd700) begin
                                next_state <= S_IDLE;
                                count_enable <= 0;
                                data_count <= 0;
                                read_state <= S_WAIT_PEDGE;
                            end
                        end
                    endcase
                    if (data_count >= 40) begin
                        data_count <= 0;
                        next_state <= S_IDLE;
                        if ((temp_data[39:32] + temp_data[31:24] + temp_data[23:16] + temp_data[15:8]) == temp_data[7:0]) begin
                            temperature <= temp_data[23:16];
                        end
                    end
                end
                default: next_state <= S_IDLE;
            endcase
        end
    end

endmodule
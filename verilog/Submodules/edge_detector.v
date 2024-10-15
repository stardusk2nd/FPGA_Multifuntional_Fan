`timescale 1ns / 1ps

// 엣지 검출기

// cp 입력의 rising edge 검출
module edge_detector_p(
    input clk, reset_p, cp,
    output pedge
    );
    
    // master & slave flip-flops 
    reg ff_slave, ff_master;
    always @(posedge clk, posedge reset_p)
    begin
        if(reset_p) begin
            ff_master <= 0;
            ff_slave <= 0;
        end
        else begin
            ff_master <= cp;
            ff_slave <= ff_master;
        end
    end
    assign pedge = ({ff_master, ff_slave} == 2'b10)? 1:0;
    
endmodule

// cp 입력의 falling edge 검출
module edge_detector_n(
    input clk, reset_p, cp,
    output nedge
    );

    reg ff_slave, ff_master;
    always @(negedge clk, posedge reset_p)
    begin
        if(reset_p) begin
            ff_master <= 0;
            ff_slave <= 0;
        end
        else begin
            ff_master <= cp;
            ff_slave <= ff_master;
        end
    end
    assign nedge = ({ff_master, ff_slave} == 2'b01)? 1:0;
    
endmodule
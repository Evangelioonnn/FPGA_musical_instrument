// Digital post-ADC processing only. A 32-cycle restoring divider avoids a large
// combinational variable divide. Gain is unsigned Q16, with exact 0 and 65536.
module pressure_expression #(parameter RAW_W=12,FILTER_SHIFT=3,TIMEOUT_CYCLES=5000000,
    parameter TIME_W=(TIMEOUT_CYCLES>1?$clog2(TIMEOUT_CYCLES+1):1))(
    input wire clk,rst,raw_valid,
    input wire [RAW_W-1:0] raw,cal_low,cal_high,dead_zone,
    output wire raw_ready,
    output reg [16:0] gain,normalized,
    output reg updated,calibration_error,stale
);
    reg busy;
    reg [5:0] count;
    reg [31:0] dividend,quotient;
    reg [RAW_W:0] remainder,denominator;
    reg [TIME_W-1:0] age;
    wire [RAW_W:0] floor_level={1'b0,cal_low}+{1'b0,dead_zone};
    wire [RAW_W:0] trial=(remainder<<1) | dividend[31];
    wire ge=trial>=denominator;
    wire [31:0] quotient_next={quotient[30:0],ge};
    function [16:0] smooth;
        input [16:0] cur,target;
        reg [16:0] delta;
        begin
            delta=cur<target ? target-cur : cur-target;
            if(delta!=0) begin delta=delta>>FILTER_SHIFT;if(delta==0) delta=1;end
            smooth=cur<target ? cur+delta : cur-delta;
        end
    endfunction
    assign raw_ready=!rst && !busy;
    always @(posedge clk) begin
        if(rst) begin
            busy<=0;count<=0;dividend<=0;quotient<=0;remainder<=0;denominator<=1;
            age<=0;gain<=0;normalized<=0;updated<=0;calibration_error<=0;stale<=1;
        end else begin
            updated<=0;
            if(age<TIMEOUT_CYCLES) age<=age+1'b1;
            else begin stale<=1;gain<=0;end
            if(raw_valid && raw_ready) begin
                age<=0;stale<=0;calibration_error<=0;
                if({1'b0,cal_high}<=floor_level) begin
                    gain<=0;normalized<=0;updated<=1;calibration_error<=1;
                end else if({1'b0,raw}<=floor_level) begin
                    normalized<=0;gain<=smooth(gain,0);updated<=1;
                end else if(raw>=cal_high) begin
                    normalized<=65536;gain<=smooth(gain,65536);updated<=1;
                end else begin
                    busy<=1;count<=0;quotient<=0;remainder<=0;
                    dividend<=({1'b0,raw}-floor_level)<<16;
                    denominator<={1'b0,cal_high}-floor_level;
                end
            end else if(busy) begin
                dividend<=dividend<<1;quotient<=quotient_next;
                remainder<=ge ? trial-denominator : trial;
                if(count==31) begin
                    busy<=0;normalized<=quotient_next[16:0];
                    gain<=smooth(gain,quotient_next[16:0]);updated<=1;
                end else count<=count+1'b1;
            end
        end
    end
endmodule

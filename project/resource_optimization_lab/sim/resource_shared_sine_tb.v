`timescale 1ns/1ps
module resource_shared_sine_tb;
    reg clk=0,rst=1,sample_ce=0,event_valid=0,event_off=0,pedal=0;
    reg [31:0] token=0; reg [6:0] note=60; reg [1:0] timbre=0;
    reg [15:0] reference_release=16'd3; reg [2:0] fm_release=3'd3;
    wire event_ready,accepted,rejected,out_valid,clipped,deadline;
    wire [7:0] occupied,held; wire signed [15:0] sample;
    wire [31:0] rejected_count,unmatched_off_count;
    resource_shared_sine_bank bank(clk,rst,sample_ce,event_valid,event_ready,event_off,token,note,timbre,
        pedal,reference_release,fm_release,accepted,rejected,rejected_count,unmatched_off_count,
        occupied,held,out_valid,sample,clipped,deadline);
    integer cycles=0,frames=0,accepted_count=0,errors=0;
    always #5 clk=~clk;
    always @(posedge clk) begin
        cycles<=cycles+1; sample_ce<=(!rst && cycles>20 && cycles%80==0);
        if(out_valid) begin frames<=frames+1; if(^sample===1'bx) errors<=errors+1; end
        if(accepted) accepted_count<=accepted_count+1;
        if(cycles==5) rst<=0;
        if(!rst) begin
            event_valid<=0; event_off<=0;
            if(accepted_count<8 && event_ready && cycles%17==0) begin
                event_valid<=1; token<=accepted_count+1; note<=60+accepted_count; timbre<=0;
            end
            if(cycles==900) begin
                if(accepted_count<8 || frames<7 || errors!=0 || deadline || rejected_count!=0) begin
                    $display("RESOURCE_SHARED_SINE_TB_FAIL accepted=%0d frames=%0d errors=%0d deadline=%0d rejected=%0d",accepted_count,frames,errors,deadline,rejected_count);
                    $finish(1);
                end
                $display("RESOURCE_SHARED_SINE_TB_PASS accepted=%0d frames=%0d",accepted_count,frames);
                $finish;
            end
        end
    end
endmodule

`timescale 1ns/1ps
module resource_mult_tb;
    reg clk=0,rst=1,sample_ce=0;
    reg [255:0] a_bus=0,b_bus=0;
    wire sv,dv; wire [511:0] sp,dp;
    shared_mult8_probe shared(clk,rst,sample_ce,a_bus,b_bus,sv,sp);
    duplicated_mult8_probe duplicate(clk,rst,sample_ce,a_bus,b_bus,dv,dp);
    reg [511:0] expected=0;
    integer cycles=0,frames=0,errors=0;
    always #5 clk=~clk;
    always @(posedge clk) begin
        cycles<=cycles+1;
        if(!rst && cycles>20 && cycles%100==0) begin
            sample_ce<=1;
            a_bus<=a_bus+256'h0000000100000002000000030000000400000005000000060000000700000008;
            b_bus<=b_bus+256'h0000001100000012000000130000001400000015000000160000001700000018;
        end else sample_ce<=0;
        if(dv) expected<=dp;
        if(sv) begin
            if(sp!==expected) begin $display("MULT_MISMATCH frame=%0d",frames);errors=errors+1;end
            frames<=frames+1;
        end
        if(cycles==650) begin
            if(frames<5 || errors!=0) begin
                $display("RESOURCE_SHARED_MULT_TB_FAIL frames=%0d errors=%0d",frames,errors);
                $finish(1);
            end
            $display("RESOURCE_SHARED_MULT_TB_PASS frames=%0d",frames);$finish;
        end
        if(cycles==5) rst<=0;
    end
endmodule

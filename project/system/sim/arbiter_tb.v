`timescale 1ns/1ps
module arbiter_tb;
    reg clk=0,rst=1,av=0,bv=0,ready=0;
    reg [15:0] ad=16'h1000,bd=16'h8000;
    wire ar,br,valid,which;wire [15:0] data;
    reg stalled=0;reg [15:0] held_data;reg held_source;
    integer na=0,nb=0,seed=325,n;
    always #10 clk=~clk;
    stream_arbiter2 #(.WIDTH(16)) dut(clk,rst,1'b0,av,ad,ar,bv,bd,br,valid,data,which,ready);
    always @(posedge clk) if(!rst) begin
        if(stalled && (!valid || data!==held_data || which!==held_source)) $fatal(1,"Arbiter unstable");
        if(valid && ready) begin
            if(which) begin if(!bv || !br || ar || data!==bd) $fatal(1,"B routing");nb=nb+1;end
            else begin if(!av || !ar || br || data!==ad) $fatal(1,"A routing");na=na+1;end
        end
        stalled=valid && !ready;held_data=data;held_source=which;
    end
    initial begin
        repeat(3) @(negedge clk);rst=0;av=1;
        repeat(3) @(negedge clk);bv=1;repeat(3) @(negedge clk);ready=1;
        for(n=0;n<4000;n=n+1) begin
            @(posedge clk);#1;@(negedge clk);
            if(ar) ad=ad+1;if(br) bd=bd+1;
            ready=($random(seed)&3)!=0;
        end
        if(na<1000 || nb<1000 || na-nb>1 || nb-na>1) $fatal(1,"Arbitration fairness");
        $display("ARBITER_TB_PASS a=%0d b=%0d",na,nb);$finish;
    end
endmodule

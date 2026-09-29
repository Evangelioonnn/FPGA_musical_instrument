`timescale 1ns/1ps
module streams_tb;
    reg clk=0,rst=1,flush=0,iv=0,oready=0;
    reg [15:0] idata=0;
    wire iready,ov;wire [15:0] odata;wire [2:0] level;
    reg [15:0] expected[0:50000];
    integer w=0,r=0,checks=0,full_swaps=0,stall=0,seed=918;
    integer cycles;
    always #10 clk=~clk;
    stream_fifo #(.WIDTH(16),.DEPTH(5)) fifo(clk,rst,flush,iv,idata,iready,ov,odata,oready,level);
    always @(posedge clk) begin
        if(rst || flush) begin w=0;r=0;end
        else begin
            if(level!=w-r || ov!=(w!=r)) $fatal(1,"FIFO occupancy");
            if(ov && oready) begin
                if(odata!==expected[r]) $fatal(1,"FIFO order");r=r+1;checks=checks+1;
            end
            if(iv && iready) begin
                if(level==5) full_swaps=full_swaps+1;
                expected[w]=idata;w=w+1;
            end
            if(iv && !iready) stall=stall+1;
        end
    end
    initial begin
        repeat(4) @(negedge clk);rst=0;
        for(cycles=0;cycles<20000;cycles=cycles+1) begin
            // Accepted data changes only after its sampling edge.
            @(posedge clk);#1;
            @(negedge clk);
            if(iready || !iv || flush) begin iv=($random(seed)&3)!=0;idata=$random(seed);end
            oready=($random(seed)&7)<3;
            flush=cycles%997==996;
        end
        iv=0;flush=0;oready=1;repeat(10) @(negedge clk);
        if(checks<4000 || full_swaps<500 || stall<500 || level!=0) $fatal(1,"FIFO coverage");
        $display("STREAMS_TB_PASS checked=%0d full_swaps=%0d stalls=%0d",checks,full_swaps,stall);$finish;
    end
endmodule

`timescale 1ns/1ps
module pluck_equivalence_tb;
    reg clk=0,rst=1;reg [5:0] tick=0;wire ce=!rst && tick==0;
    reg valid=0;reg [1:0] kind=0;
    reg [6:0] note=48;reg [8:0] velocity=256;reg [31:0] seed=32'h12345678;
    wire ready0,ready1,reject0,reject1,active0,active1,v0,v1;
    wire signed [15:0] sample0,sample1;
    integer frames=0,k,checked=0;
    always #10 clk=~clk;
    always @(posedge clk)if(rst)tick<=0;else tick<=tick+1'b1;
    pluck_voice #(.LOGIC_SCALE(0)) old(clk,rst,ce,valid,kind,note,velocity,seed,ready0,reject0,active0,sample0,v0);
    pluck_voice #(.LOGIC_SCALE(1)) optimized(clk,rst,ce,valid,kind,note,velocity,seed,ready1,reject1,active1,sample1,v1);
    always @(posedge clk)begin
        #1;
        if(!rst && {ready0,reject0,active0,sample0,v0}!=={ready1,reject1,active1,sample1,v1})
            $fatal(1,"DSP/fabric variants differ");
        if(v0)begin frames=frames+1;checked=checked+1;end
    end
    task send;input [1:0] cmd;begin
        @(negedge clk);kind=cmd;
        while(!ready0 || ce)@(negedge clk);
        valid=1;@(negedge clk);valid=0;
    end endtask
    task wait_frames;input integer n;integer end_at;begin end_at=frames+n;wait(frames>=end_at);@(negedge clk);end endtask
    initial begin
        repeat(5)@(negedge clk);rst=0;
        for(k=0;k<4;k=k+1)begin
            note=k==0?48:k==1?60:k==2?84:55;velocity=k==3?127:256;
            seed=k==0?1:k==1?32'hffffffff:k==2?32'h80000000:32'h12345678;
            send(0);wait_frames(3000);send(1);wait_frames(7500);
            if(active0 || sample0)$fatal(1,"Equivalent tails not silent");
        end
        $display("PLUCK_EQUIVALENCE_TB_PASS samples=%0d dsp_vs_shift_exact=1 low_mid_high=1",checked);$finish;
    end
endmodule

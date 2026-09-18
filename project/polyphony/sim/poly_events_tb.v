`timescale 1ns/1ps
module poly_events_tb;
    reg clk=0,rst=1,valid=0,on=0,panic=0;
    reg [6:0] note=0;
    reg [2:0] tick=0;
    wire ce=!rst && tick==0;
    wire ready,sv,clip,stolen,ignored;
    wire signed [15:0] sample;
    wire [3:0] busy,held;
    wire [27:0] notes;
    wire [63:0] samples,envs;
    wire [11:0] states;
    always #10 clk=~clk;
    always @(posedge clk) if(rst) tick<=0; else tick<=tick+1'b1;
    poly_synth4 #(.ATTACK_STEP(65535),.DECAY_STEP(65535),.RELEASE_STEP(32768)) dut(
        clk,rst,ce,valid,on,note,panic,ready,sample,sv,clip,busy,held,notes,samples,envs,states,stolen,ignored);
    task push;
        input [6:0] n; input kind;
        begin @(negedge clk); valid=1;note=n;on=kind; end
    endtask
    task settle;
        begin @(negedge clk); valid=0; repeat(32) @(negedge clk); end
    endtask
    initial begin
        repeat(4) @(negedge clk); rst=0;
        push(60,1);push(64,1);push(67,1);push(72,1);settle;
        if(busy!=15 || held!=15 || notes!=={7'd72,7'd67,7'd64,7'd60}) $fatal(1,"Four-note allocation");
        push(76,1);push(60,0);settle;
        if(held!=15 || notes[6:0]!=76 || envs[15:0]==0) $fatal(1,"Stale off released replacement");
        push(67,0);settle;
        if(busy!=11 || held!=11 || envs[47:32]!=0) $fatal(1,"Independent release/retirement");
        if(envs[15:0]!=32768 || envs[31:16]!=32768 || envs[63:48]!=32768) $fatal(1,"Other envelopes changed");
        push(79,1);push(64,1);settle;
        if(busy!=15 || notes[20:14]!=79 || notes[13:7]!=64) $fatal(1,"Reuse or retrigger failed");
        @(negedge clk);panic=1; valid=1;on=1;note=90;
        @(posedge clk);#1; if(ready || held!=0) $fatal(1,"Panic priority");
        @(negedge clk);panic=0;valid=0;
        repeat(40) @(negedge clk);
        if(busy!=0 || sample!==0 || envs!==0) $fatal(1,"Panic stuck voice");
        push(80,1);push(80,0);settle;
        if(busy!=0 || sample!==0) $fatal(1,"Very short note stuck");
        if(clip) $fatal(1,"Unexpected clipping");
        $display("POLY_EVENTS_TB_PASS four_on,stale_off,independent_release,reuse,retrigger,panic,short_note");
        $finish;
    end
endmodule

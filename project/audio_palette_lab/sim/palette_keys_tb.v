`timescale 1ns/1ps
module palette_keys_tb;
    reg clk=0;always #10 clk=~clk;
    reg rst=1,panic=0,changed=0,ghost=0,ready=1;
    reg [24:0] keys=0;reg [6:0] lb=48,rb=60;reg [1:0] tone=0;
    wire ev,off,fault,blocked;wire [31:0] token;wire [6:0] note;wire [1:0] timbre;
    wire exhausted,overflow;wire [31:0] faults;
    palette_keys #(.KEYS(25),.SPLIT(12),.DEPTH(4)) dut(clk,rst,panic,changed,ghost,keys==0,
        keys,tone,lb,rb,ev,ready,off,token,note,timbre,fault,blocked,overflow,exhausted,faults);
    integer count=0;reg [31:0] tokens[0:255];reg [6:0] notes[0:255];reg offs[0:255];reg [1:0] tones[0:255];
    reg stall=0;reg [41:0] held_event;
    always @(posedge clk) if(!rst) begin
        if(ev && ready) begin tokens[count]=token;notes[count]=note;offs[count]=off;tones[count]=timbre;count=count+1;end
        if(ev && !ready) begin
            if(stall && held_event!=={off,token,note,timbre}) $fatal;
            held_event={off,token,note,timbre};stall=1;
        end else stall=0;
    end
    task snapshot;input [24:0] k;begin @(negedge clk);keys=k;changed=1;@(negedge clk);changed=0;end endtask
    task settle;begin repeat(240) @(negedge clk);end endtask
    integer i;integer before_count;reg [31:0] first,last;
    initial begin
        repeat(5) @(negedge clk);rst=0;settle;
        // Complete two chromatic octaves plus upper C in one snapshot.
        snapshot(25'h1ffffff);settle;
        if(count!=25) $fatal;
        for(i=0;i<25;i=i+1) if(notes[i]!==48+i || offs[i] || tokens[i]!==i+1) $fatal;
        // Move BOTH bases while held; no extra strike. Off keeps old token.
        lb=36;rb=72;settle;if(count!=25) $fatal;
        snapshot(0);settle;
        for(i=0;i<25;i=i+1) if(!offs[25+i] || tokens[25+i]!==i+1) $fatal;
        // Same pitch in two zones: separate tokens and independent offs.
        lb=60;rb=60;snapshot(25'h1001);settle;
        first=tokens[50];last=tokens[51];
        if(notes[50]!=60 || notes[51]!=60 || first==last) $fatal;
        snapshot(25'h1000);settle;
        if(!offs[52] || tokens[52]!=first) $fatal;
        snapshot(0);settle;if(tokens[53]!=last) $fatal;
        // Queue captures config even with backpressure and later changes.
        ready=0;lb=36;tone=1;snapshot(1);settle;
        lb=72;tone=0;settle;
        if(!ev || note!=36 || timbre!=1) $fatal;
        ready=1;settle;snapshot(0);settle;
        // Upper endpoint and a deliberately illegal external base: no wrap.
        rb=72;snapshot(25'h1000000);settle;
        if(notes[count-1]!=84) $fatal;
        snapshot(0);settle;rb=127;snapshot(25'h1000000);settle;
        if(notes[count-1]!=127) $fatal;
        snapshot(0);settle;
        // Ghost flush/recovery and queue overflow fail closed.
        ghost=1;settle;if(!blocked || faults!=1) $fatal;
        ghost=0;settle;if(blocked) $fatal;
        ready=0;
        for(i=0;i<12;i=i+1) snapshot(i%2 ? 25'd1 : 25'd2);
        settle;if(!overflow || !blocked) $fatal;
        ready=1;snapshot(0);settle;if(blocked) $fatal;
        $display("PALETTE_KEYS_TB_PASS full25, config snapshot, same-pitch identity, boundaries, stalls, ghost/overflow");$finish;
    end
    initial begin #10000000;$fatal;end
endmodule

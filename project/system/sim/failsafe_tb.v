`timescale 1ns/1ps
module failsafe_tb;
    reg clk=0,rst=1,panic=0,changed=0,ghost=0,up=1,ready=0;
    reg [3:0] keys=0;
    wire ev,fault,blocked,overflow;wire [1:0] kind;wire [6:0] note;wire [8:0] vel;wire [31:0] count;
    integer received=0;
    always #10 clk=~clk;
    key_pipeline #(.KEYS(4),.DEPTH(2)) dut(clk,rst,panic,changed,ghost,up,keys,
        {7'd67,7'd64,7'd62,7'd60},9'd256,ev,kind,note,vel,ready,fault,blocked,overflow,count);
    always @(posedge clk) if(!rst && ev && ready) received=received+1;
    task update;input [3:0] value;begin
        @(negedge clk);keys=value;up=0;changed=1;@(negedge clk);changed=0;
    end endtask
    initial begin
        repeat(4) @(negedge clk);rst=0;repeat(4) @(negedge clk);
        update(1);repeat(15) @(negedge clk);
        update(0);update(1);update(0);repeat(8) @(negedge clk);
        if(!blocked || !overflow || count!=1 || ev) $fatal(1,"Overflow did not fail safe");
        ready=1;repeat(10) @(negedge clk);if(received!=0) $fatal(1,"Stale event after flush");
        up=1;keys=0;repeat(5) @(negedge clk);if(blocked) $fatal(1,"Re-arm");
        update(1);repeat(20) @(negedge clk);if(received!=1) $fatal(1,"Recovered note-on");
        ghost=1;repeat(5) @(negedge clk);if(!blocked || count!=2) $fatal(1,"Ghost fail-safe");
        ghost=0;repeat(10) @(negedge clk);if(!blocked) $fatal(1,"Re-armed with held key");
        keys=0;up=1;repeat(5) @(negedge clk);panic=1;@(negedge clk);panic=0;
        $display("FAILSAFE_TB_PASS overflow=1 ghost=1 rearm=1 stale_events=0");$finish;
    end
endmodule

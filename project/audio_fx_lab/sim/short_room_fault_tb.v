`timescale 1ns/1ps
module short_room_fault_tb;
    reg clk=0;
    always #10 clk=~clk;
    reg rst=1,in_valid=0,fx_enable=1;
    reg signed [15:0] in_sample=1234;
    reg [8:0] wet_q8=128;
    wire out_valid,clip,ready,busy,overrun;
    wire signed [15:0] out_left,out_right;
    wire [8:0] wet_applied;
    short_room_reverb dut(clk,rst,in_valid,in_sample,fx_enable,wet_q8,
        out_valid,out_left,out_right,clip,ready,busy,overrun,wet_applied);
    integer outputs=0;
    always @(negedge clk) if(out_valid) outputs=outputs+1;
    initial begin
        repeat(4) @(negedge clk);
        rst=0;
        repeat(4100) @(negedge clk);
        if(!ready) begin $display("FX_FAULT_FAIL init");$finish;end
        in_valid=1;
        @(negedge clk);in_valid=0;
        repeat(3) @(negedge clk);
        in_valid=1;in_sample=-20000;
        @(negedge clk);in_valid=0;
        repeat(30) @(negedge clk);
        if(!overrun || outputs!=1 || busy) begin
            $display("FX_FAULT_FAIL busy rejection");$finish;
        end
        in_valid=1;
        @(negedge clk);in_valid=0;
        repeat(7) @(negedge clk);
        rst=1;
        repeat(2) @(negedge clk);
        rst=0;in_sample=-12345;fx_enable=1;in_valid=1;
        @(negedge clk);in_valid=0;
        repeat(24) @(negedge clk);
        #1;
        if(!out_valid || out_left!=-12345 || out_right!=-12345 ||
           ready || overrun || wet_applied!=0 || clip) begin
            $display("FX_FAULT_FAIL reset/warmup L=%0d ready=%0d valid=%0d",out_left,ready,out_valid);$finish;
        end
        $display("SHORT_ROOM_FAULT_TB_PASS busy rejection, in-flight reset, dry warmup");
        $finish;
    end
endmodule

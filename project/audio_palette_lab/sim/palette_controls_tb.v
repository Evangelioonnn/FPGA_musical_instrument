`timescale 1ns/1ps
module palette_controls_tb;
    reg clk=0;always #10 clk=~clk;
    reg rst=1,sv=0,fault=0;reg [2:0] buttons=7;reg signed [1:0] step=0;
    wire [1:0] timbre,mode;wire sustain,release_mode,panic;
    wire [6:0] lb,rb;wire [4:0] volume;wire [2:0] release_index;
    wire [16:0] target;wire [15:0] release_step;
    integer panic_count=0;
    palette_controls #(.BUTTON_CYCLES(2),.LONG_CYCLES(40)) dut(clk,rst,buttons,sv,step,fault,
        timbre,sustain,release_mode,mode,lb,rb,panic,volume,release_index,target,release_step);
    always @(posedge clk) if(panic) panic_count=panic_count+1;
    task click;input integer key;begin @(negedge clk);buttons[key]=0;repeat(12) @(negedge clk);buttons[key]=1;repeat(12) @(negedge clk);end endtask
    task rotate;input integer dir;begin @(negedge clk);step=dir;sv=1;@(negedge clk);sv=0;repeat(2) @(negedge clk);end endtask
    integer j;
    initial begin
        repeat(5) @(negedge clk);rst=0;repeat(8) @(negedge clk);
        if(mode!=0 || volume!=24 || lb!=48 || rb!=60) $fatal;
        rotate(-1);if(volume!=23) $fatal;
        click(0);rotate(-1);if(mode!=1 || lb!=36 || rb!=60 || volume!=23) $fatal;
        for(j=0;j<8;j=j+1) rotate(-1);if(lb!=36) $fatal;
        for(j=0;j<8;j=j+1) rotate(1);if(lb!=72) $fatal;
        click(0);rotate(1);if(mode!=2 || rb!=72 || lb!=72) $fatal;
        click(0);rotate(1);if(mode!=3 || !release_mode || release_index!=6) $fatal;
        click(0);if(mode!=0 || release_mode) $fatal;
        click(2);if(timbre!=1) $fatal;click(2);if(timbre!=0) $fatal;
        click(1);if(!sustain) $fatal;
        buttons[0]=0;repeat(60) @(negedge clk);buttons[0]=1;repeat(20) @(negedge clk);
        if(panic_count!=1 || sustain || mode!=0) $fatal;
        $display("PALETTE_CONTROLS_TB_PASS volume/left/right/release, clamps, timbre, sustain, panic");$finish;
    end
endmodule

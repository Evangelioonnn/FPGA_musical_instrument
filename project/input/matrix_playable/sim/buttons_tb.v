`timescale 1ns/1ps
module buttons_tb;
    reg clk=0,rst=1;reg [2:0] buttons=7;reg step_valid=0,fault=0;reg signed [1:0] step=0;
    wire [1:0] tone;wire pedal,mode,panic;wire [4:0] vi;wire [2:0] ri,fi;wire [16:0] vol;wire [15:0] r;
    integer panics=0,i;
    always #10 clk=~clk;
    playable_controls #(.BUTTON_CYCLES(4),.LONG_CYCLES(40)) dut(clk,rst,buttons,step_valid,step,fault,
        tone,pedal,mode,panic,vi,ri,fi,vol,r);
    always @(posedge clk)if(panic)panics=panics+1;
    task tick;input integer n;begin repeat(n)@(negedge clk);end endtask
    task click;input integer b;begin buttons[b]=0;tick(12);buttons[b]=1;tick(12);end endtask
    task rotate;input integer direction;begin step=direction;step_valid=1;tick(1);step_valid=0;tick(2);end endtask
    initial begin
        tick(5);rst=0;tick(10);
        if(tone || pedal || mode || vi!=24 || ri!=5 || fi!=3 || r!=3)$fatal(1,"Defaults changed");
        for(i=0;i<5;i=i+1)begin buttons[2]=0;tick(1);buttons[2]=1;tick(2);end
        tick(10);if(tone)$fatal(1,"Bounce toggled timbre");
        click(2);if(tone!=1)$fatal(1,"First tone");
        click(0);if(!mode)$fatal(1,"Short press mode");
        rotate(1);if(ri!=5 || fi!=3)$fatal(1,"Pluck changed release");
        click(2);if(tone!=2)$fatal(1,"FM selection");
        rotate(1);if(fi!=4 || ri!=5)$fatal(1,"Separate release settings");
        click(2);rotate(-1);if(tone!=0 || ri!=4 || r!=6 || fi!=4)$fatal(1,"Reference release");
        click(1);if(!pedal)$fatal(1,"Sustain toggle");
        buttons[0]=0;tick(100);buttons[0]=1;tick(15);
        if(panics!=1 || !mode || pedal)$fatal(1,"Long press retrigger/short action");
        click(0);if(mode)$fatal(1,"Mode return");
        for(i=0;i<30;i=i+1)rotate(-1);
        if(vi || vol)$fatal(1,"Mute floor");
        for(i=0;i<30;i=i+1)rotate(1);
        if(vi!=24 || vol!=65536)$fatal(1,"Volume ceiling");
        click(1);fault=1;tick(1);fault=0;tick(1);if(pedal)$fatal(1,"Fault left pedal on");
        $display("BUTTONS_TB_PASS debounce=1 cycle3=1 separate_release=1 long_once=1 volume_bounds=1");$finish;
    end
    initial begin #1000000;$fatal(1,"buttons timeout");end
endmodule

`timescale 1ns/1ps
module custom_fader_tb;
    reg clk=0;always #10 clk=~clk;
    reg rst=1,active=0,step_valid=0;
    reg signed [1:0] step=0;
    reg [2:0] channel=0;
    wire adc_valid;
    wire [11:0] adc_ch0,adc_ch1,adc_ch2,adc_ch3,adc_ch4;
    custom_fader_emulator dut(clk,rst,active,step_valid,step,channel,
        adc_valid,adc_ch0,adc_ch1,adc_ch2,adc_ch3,adc_ch4);
    task click;
        input [2:0] ch;
        input signed [1:0] direction;
        begin
            @(negedge clk);channel=ch;step=direction;step_valid=1;
            @(negedge clk);
            if(!adc_valid) $fatal(1,"valid control step was not captured");
            step_valid=0;step=0;
            @(negedge clk);
            if(adc_valid) $fatal(1,"ADC snapshot valid should be a single-cycle pulse");
        end
    endtask
    initial begin
        repeat(4) @(negedge clk);rst=0;
        if(adc_ch0!=4095 || adc_ch1!=4095 || adc_ch2!=1024 || adc_ch3!=512 || adc_ch4!=256)
            $fatal(1,"simulated fader defaults do not match the accepted piano");
        step_valid=1;step=1;channel=2;@(negedge clk);step_valid=0;step=0;
        if(adc_valid || adc_ch2!=1024) $fatal(1,"inactive timbre accepted an EC11 change");
        active=1;
        click(0,-1);
        if(adc_ch0!=4031) $fatal(1,"CH0 volume decrement failed");
        click(3,1);
        if(adc_ch3!=576) $fatal(1,"CH3 third-harmonic increment failed");
        click(3,-1);
        if(adc_ch3!=512) $fatal(1,"CH3 third-harmonic decrement failed");
        click(4,-1);
        if(adc_ch4!=192) $fatal(1,"CH4 fourth-harmonic decrement failed");
        @(negedge clk);channel=5;step=1;step_valid=1;
        @(negedge clk);
        if(adc_valid) $fatal(1,"invalid fader channel asserted ADC valid");
        step_valid=0;step=0;
        if(adc_ch0!=4031 || adc_ch1!=4095 || adc_ch2!=1024 || adc_ch3!=512 || adc_ch4!=192)
            $fatal(1,"invalid channel changed a fader value");
        $display("CUSTOM_FADER_TB_PASS EC11 surrogate maps channels, saturates and snapshots");
        $finish;
    end
endmodule

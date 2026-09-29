`timescale 1ns/1ps
module custom_volume_audio_tb;
    reg clk=0;always #10 clk=~clk;
    reg rst=1,sample_ce=0,adc_valid=0,bank_valid=0;
    reg [11:0] adc_ch0=4095,adc_ch1=4095,adc_ch2=1024,adc_ch3=512,adc_ch4=256;
    reg signed [15:0] bank_sample=16'sd12000;
    wire [15:0] volume_gain,volume_target;
    wire [8:0] coeff0,coeff1,coeff2,coeff3;
    wire [8:0] coeff0_target,coeff1_target,coeff2_target,coeff3_target;
    wire params_updated,params_busy,adc_overrun;
    wire [16:0] audio_gain;
    wire audio_valid;
    wire signed [15:0] audio_sample;
    custom_harmonic_params params(clk,rst,sample_ce,adc_valid,
        adc_ch0,adc_ch1,adc_ch2,adc_ch3,adc_ch4,
        volume_gain,coeff0,coeff1,coeff2,coeff3,volume_target,
        coeff0_target,coeff1_target,coeff2_target,coeff3_target,params_updated,
        params_busy,adc_overrun);
    knob_gain gain(clk,rst,bank_valid,bank_sample,{1'b0,volume_gain},
        audio_valid,audio_sample,audio_gain);
    integer i;
    task frame;
        begin
            @(negedge clk);sample_ce=1;bank_valid=1;
            @(negedge clk);sample_ce=0;bank_valid=0;
            repeat(2) @(negedge clk);
        end
    endtask
    task scan_volume;
        input [11:0] value;
        begin
            @(negedge clk);adc_ch0=value;adc_valid=1;
            @(negedge clk);adc_valid=0;
        end
    endtask
    initial begin
        repeat(5) @(negedge clk);rst=0;
        for(i=0;i<8;i=i+1) frame();
        if(audio_sample<11998 || audio_sample>12000)
            $fatal(1,"full master gain did not pass the mixed sample cleanly: %0d",audio_sample);
        if(coeff0!=256 || coeff1!=64 || coeff2!=32 || coeff3!=16)
            $fatal(1,"CH0 changed harmonic ratios");

        scan_volume(0);
        for(i=0;i<600;i=i+1) frame();
        if(volume_gain!=0 || audio_gain!=0 || audio_sample!=0)
            $fatal(1,"CH0 failed to mute the post-mix sample");
        if(coeff0!=256 || coeff1!=64 || coeff2!=32 || coeff3!=16)
            $fatal(1,"CH0 sweep changed harmonic ratios");

        scan_volume(4095);
        for(i=0;i<600;i=i+1) frame();
        if(volume_gain!=16'hffff || audio_gain<65534 || audio_sample<11998)
            $fatal(1,"CH0 failed to restore post-mix level");
        $display("CUSTOM_VOLUME_AUDIO_TB_PASS independent post-mix volume");
        $finish;
    end
endmodule

`timescale 1ns/1ps
module baseline_mixer_tb;
    reg clk=0,rst=1,valid=0;
    reg [127:0] voices=0;
    reg [16:0] gain=0;
    wire signed [15:0] sample;
    wire sv,clip;
    integer i,j,value,total,seed=18918,clips=0;
    reg signed [63:0] product,expected;
    reg expected_clip;
    always #10 clk=~clk;
    baseline_mixer dut(clk,rst,valid,voices,gain,sample,sv,clip);
    initial begin
        repeat(4) @(negedge clk);rst=0;
        for(i=0;i<2000;i=i+1) begin
            total=0;
            for(j=0;j<8;j=j+1) begin
                value=$random(seed)%32768;
                if(i==0) value=32767;
                if(i==1) value=-32768;
                if(i==2) value=j%2 ? 32767 : -32768;
                if(i==3) value=0;
                voices[j*16 +: 16]=value;total=total+value;
            end
            gain=i<4 ? 65536 : ($random(seed)&17'h1ffff);
            product=total;product=product*gain;
            expected=product>=0 ? product/65536 : -((-product+65535)/65536);
            expected_clip=expected>32767 || expected < -32768;
            if(expected>32767) expected=32767;
            if(expected < -32768) expected=-32768;
            valid=1;
            @(negedge clk);valid=0;gain=0;voices=0;
            @(negedge clk);if(sv) $fatal(1,"Early mixer output");
            @(negedge clk);
            if(!sv || clip!==expected_clip || $signed(sample)!==expected)
                $fatal(1,"Mixer mismatch vector=%0d sample=%0d expected=%0d clip=%0d",i,sample,expected,clip);
            if(clip) clips=clips+1;
            @(negedge clk);if(sv) $fatal(1,"Duplicate mixer output");
        end
        if(clips<2) $fatal(1,"Missing saturation coverage");
        $display("BASELINE_MIXER_TB_PASS vectors=2000 saturations=%0d",clips);$finish;
    end
endmodule

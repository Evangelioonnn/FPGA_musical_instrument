`timescale 1ns/1ps
module mixer_meter_tb;
    parameter N=8;
    reg clk=0,rst=1,valid=0;
    reg [N*16-1:0] samples=0;
    reg [16:0] gain=0;
    wire signed [15:0] out0,out6;
    wire v0,v6,c0,c6;
    integer i,j,signed_value,total,average,count=0,seed=1809,saturations=0;
    reg signed [63:0] product,reference0,reference6;
    expression_mixer #(.N(N),.MONITOR_SHIFT(0)) fullmix(clk,rst,valid,samples,gain,out0,v0,c0);
    expression_mixer #(.N(N)) lowmix(clk,rst,valid,samples,gain,out6,v6,c6);
    reg mvalid=0,mclip=0;
    reg signed [15:0] msample=0;
    wire snap,clip;
    wire [15:0] peak;
    wire signed [15:0] last;
    integer expected_peak=0,absvalue,window_count=0;
    reg expected_clip=0;
    audio_meter #(.WINDOW(7),.COUNT_W(3)) meter(clk,rst,mvalid,mclip,msample,snap,peak,last,clip);
    always #10 clk=~clk;
    function integer divide_floor;
        input integer x,divisor;
        begin divide_floor=x>=0 ? x/divisor : -((-x+divisor-1)/divisor);end
    endfunction
    initial begin
        repeat(4) @(negedge clk);rst=0;
        for(i=0;i<5000;i=i+1) begin
            total=0;
            for(j=0;j<N;j=j+1) begin
                signed_value=$random(seed)%32768;
                if(i==0) signed_value=-32768;
                if(i==1) signed_value=32767;
                if(i==2) signed_value=j%2 ? 32767 : -32768;
                samples[j*16 +: 16]=signed_value;total=total+signed_value;
            end
            gain=i<3 ? 131071 : (i%3==0 ? 65536 : $random(seed)&17'h1ffff);
            average=divide_floor(total,N);product=average;
            product=product*gain;
            reference0=product>=0 ? product/65536 : -((-product+65535)/65536);
            reference6=product>=0 ? product/4194304 : -((-product+4194303)/4194304);
            valid=1;
            @(negedge clk);valid=0;
            @(negedge clk);if(v0 || v6) $fatal(1,"Early valid");
            @(negedge clk);
            if(!v0 || !v6) $fatal(1,"Missing valid");
            if(c0!== (reference0>32767 || reference0 < -32768)) $fatal(1,"Clip flag");
            if(c0) saturations=saturations+1;
            if(reference0>32767) reference0=32767;
            if(reference0 < -32768) reference0=-32768;
            if(out0!==reference0[15:0] || out6!==reference6[15:0] || c6) $fatal(1,"Mix math i=%0d",i);
            @(negedge clk);if(v0 || v6) $fatal(1,"Held valid");count=count+1;
        end
        for(i=0;i<1000;i=i+1) begin
            msample=i==0 ? -32768 : $random(seed);mvalid=i%5!=4;mclip=i%19==0;
            if(mvalid) begin
                absvalue=msample<0 ? -msample : msample;
                if(absvalue>expected_peak) expected_peak=absvalue;
                expected_clip=expected_clip|mclip;window_count=window_count+1;
            end
            @(posedge clk);#1;
            if(snap!== (mvalid && window_count==7)) $fatal(1,"Meter valid");
            if(snap) begin
                if(peak!==expected_peak || last!==msample || clip!==expected_clip) $fatal(1,"Meter snapshot");
                expected_peak=0;expected_clip=0;window_count=0;
            end
            @(negedge clk);
        end
        if(saturations<2) $fatal(1,"No saturation coverage");
        $display("MIXER_METER_TB_PASS N=%0d vectors=%0d saturations=%0d meter_cycles=1000",N,count,saturations);$finish;
    end
endmodule

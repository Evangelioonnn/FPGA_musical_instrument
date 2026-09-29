`timescale 1ns/1ps
module observability_tb;
    reg clk=0,rst=1,valid=0,clipped=0;reg signed [15:0] sample=0;
    wire sv,mc,wv;wire [15:0] peak;wire signed [15:0] last,ws;wire [31:0] wi;
    integer n=0,window_n=0,expected_peak=0,mag,seed=312,i,snaps=0,waves=0;reg expected_clip=0;
    audio_meter meter(clk,rst,valid,clipped,sample,sv,peak,last,mc);
    waveform_tap tap(clk,rst,valid,sample,wv,ws,wi);
    always #10 clk=~clk;
    initial begin
        repeat(4)@(negedge clk);rst=0;
        for(i=0;i<25000;i=i+1)begin
            @(negedge clk);valid=($random(seed)&3)!=0;sample=$random(seed);clipped=($random(seed)&127)==0;
            if(i%200==0)sample=-32768;
            if(valid)begin
                mag=sample<0 ? -$signed(sample) : sample;
                if(mag>expected_peak)expected_peak=mag;
                expected_clip=expected_clip || clipped;
                window_n=window_n+1;
            end
            @(posedge clk);#1;
            if(sv!==(valid && window_n==1024))$fatal(1,"meter cadence");
            if(sv)begin
                if(peak!==expected_peak[15:0] || mc!==expected_clip || last!==sample)$fatal(1,"meter numeric result");
                window_n=0;expected_peak=0;expected_clip=0;snaps=snaps+1;
            end
            if(wv!==(valid && n%48==0))$fatal(1,"tap cadence");
            if(wv)begin if(wi!==n || ws!==sample)$fatal(1,"tap payload");waves=waves+1;end
            if(valid)n=n+1;
        end
        $display("OBSERVABILITY_TB_PASS samples=%0d meter_windows=%0d wave_samples=%0d min_signed=1",n,snaps,waves);$finish;
    end
endmodule

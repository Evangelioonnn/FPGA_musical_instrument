`timescale 1ns/1ps
module pitch_tb;
    reg clk=0,rst=1,ce=0,on=0,off=0,fresh=0;
    reg [31:0] base=0;reg [17:0] bend=65536;reg [30:0] glide=0;
    wire [31:0] step;
    wire signed [15:0] sample;wire valid;wire [15:0] env;wire [2:0] state;
    reg [31:0] expected_step=0,previous_phase,previous_step;
    reg [63:0] scaled;
    integer n,delta,file,outputs=0;
    reg recording=1;
    always #10 clk=~clk;
    knob_pitch control(clk,rst,ce,fresh,base,bend,glide,step);
    synth_voice voice(clk,rst,ce,on,off,1'b1,step,sample,valid,env,state);
    function [31:0] musical;input integer midi;real f;begin
        f=440.0*(2.0**((midi-69)/12.0));musical=$rtoi(f*4294967296.0*1040.0/50000000.0+0.5);
    end endfunction
    always @(posedge clk)if(valid && recording)begin $fwrite(file,"%0d\n",sample);outputs=outputs+1;end
    initial begin
        file=$fopen("pitch_samples.txt","w");
        repeat(5)@(negedge clk);rst=0;base=musical(60);
        for(n=0;n<240385;n=n+1)begin
            on=n==4807;off=n==192308;fresh=n==4807;
            if(n==48077)begin base=musical(67);glide=700;end
            if(n==96154)begin bend=73562;glide=0;end
            if(n==144231)bend=65536;
            repeat(4)@(negedge clk);on=0;off=0;fresh=0;
            scaled=base;scaled=scaled*(bend<32768?32768:bend>131072?131072:bend)/65536;
            if(scaled>2147483647)scaled=2147483647;
            if(glide==0 || n==4807)expected_step=scaled;
            else if(expected_step<scaled)expected_step=scaled-expected_step<=glide?scaled:expected_step+glide;
            else expected_step=expected_step-scaled<=glide?scaled:expected_step-glide;
            previous_phase=voice.phase;previous_step=step;
            ce=1;@(negedge clk);ce=0;
            if(step!==expected_step || voice.phase!==previous_phase+previous_step)
                $fatal(1,"Pitch/glide failed actual oscillator n=%0d step=%0d expected=%0d",n,step,expected_step);
            repeat(11)@(negedge clk);
        end
        if(sample || state || outputs!=240385)$fatal(1,"Pitch audio did not release");
        recording=0;$fclose(file);
        // Arithmetic boundary checks outside the listening segment.
        base=32'hffffffff;bend=262143;repeat(4)@(negedge clk);ce=1;@(negedge clk);ce=0;
        if(step!=32'h7fffffff)$fatal(1,"Nyquist clamp");
        base=100000;bend=0;repeat(4)@(negedge clk);ce=1;@(negedge clk);ce=0;
        if(step!=50000)$fatal(1,"Lower bend clamp");
        $display("PITCH_TB_PASS samples=240385 glide=1 bend=1 oscillator_phase=1 bounds=1 release=1");$finish;
    end
endmodule

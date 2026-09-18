`timescale 1ns/1ps
module voice_tb;
    reg clk=0,rst=1,ce=0,on=0,off=0,fresh=0;
    reg [31:0] base=32'h02000000;
    reg [17:0] ratio=65536;
    reg [30:0] glide=0;
    reg [8:0] velocity=256;
    reg [14:0] w2=0,w3=0;
    reg [15:0] a=65535,d=65535,s=32768,r=32768;
    wire signed [15:0] sample;
    wire valid;
    wire [15:0] env;
    wire [2:0] state;
    wire [31:0] step,phase;
    integer i,outputs=0;
    reg [31:0] oldstep,oldphase;
    expressive_voice dut(clk,rst,ce,on,off,fresh,base,ratio,glide,velocity,w2,w3,a,d,s,r,
        sample,valid,env,state,step,phase);
    always #10 clk=~clk;
    always @(posedge clk) begin #1;if(valid) outputs=outputs+1;end
    task tick;
        begin
            oldphase=phase;ce=1;@(negedge clk);ce=0;
            if(phase!==oldphase+step) $fatal(1,"Phase discontinuity");
            repeat(5) @(negedge clk);if(valid) $fatal(1,"Voice valid early");
            @(negedge clk);if(!valid) $fatal(1,"Voice valid late");
            repeat(9) @(negedge clk);
        end
    endtask
    initial begin
        repeat(4) @(negedge clk);rst=0;on=1;fresh=1;
        @(negedge clk);on=0;fresh=0;repeat(3) @(negedge clk);
        repeat(4) tick;
        if(step!=base || env!=32768) $fatal(1,"Fresh note or envelope");
        s=123;repeat(3) tick;if(env!=32768) $fatal(1,"ADSR snapshot changed during held note");
        glide=1024;base=32'h02002000;repeat(3) @(negedge clk);
        for(i=0;i<8;i=i+1) begin oldstep=step;tick;if(step!=oldstep+1024) $fatal(1,"Up glide");end
        tick;if(step!=base) $fatal(1,"Target overshoot");
        base=32'h02000101;repeat(3) @(negedge clk);
        for(i=0;i<8;i=i+1) begin oldstep=step;tick;if(step>oldstep || oldstep-step>1024) $fatal(1,"Down glide");end
        if(step!=base) $fatal(1,"Endpoint residue");
        glide=0;ratio=131072;repeat(3) @(negedge clk);tick;
        if(step!=(base<<1)) $fatal(1,"Pitch ratio");
        base=32'h70000000;repeat(3) @(negedge clk);tick;
        if(step!=32'h7fffffff || dut.allow2 || dut.allow3) $fatal(1,"Nyquist clamp");
        base=32'h30000000;ratio=65536;repeat(3) @(negedge clk);tick;
        if(!dut.allow2 || dut.allow3) $fatal(1,"Harmonic gate");
        off=1;@(negedge clk);off=0;repeat(5) tick;
        if(env || state || sample) $fatal(1,"Release not zero");
        on=1;fresh=1;velocity=0;@(negedge clk);on=0;fresh=0;repeat(5) tick;
        if(sample) $fatal(1,"Zero velocity output");
        $display("VOICE_TB_PASS outputs=%0d glide,pitch,phase,envelope_snapshot,nyquist,release,velocity",outputs);$finish;
    end
endmodule

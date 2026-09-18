`timescale 1ns/1ps
module core_tb;
    reg clk=0, rst=1, ce=0, on=0, off=0, pitch_we=0;
    reg [6:0] note=69;
    wire [31:0] step;
    wire signed [15:0] sample;
    wire valid;
    wire [15:0] envelope;
    wire [2:0] state;
    integer i,j,k,first_cross,last_cross,crosses,previous,value,expected;
    real freq,ideal_step,angle=0.0,measured;
    always #10 clk=~clk;
    note_table nt(note,step);
    synth_voice #(.ATTACK_STEP(65535),.DECAY_STEP(65535),
        .SUSTAIN_LEVEL(65535),.RELEASE_STEP(65535)) dut(
        clk,rst,ce,on,off,pitch_we,step,sample,valid,envelope,state);
    task tick;
        begin
            @(negedge clk); ce=1;
            @(posedge clk); #1; if(valid) $fatal(1,"Early valid at sample edge");
            @(negedge clk); ce=0;
            repeat(2) begin @(posedge clk); #1; if(valid) $fatal(1,"Early pipeline valid"); end
            @(posedge clk); #1; if(!valid) $fatal(1,"Missing valid at +3 cycles");
            if(^sample===1'bx || sample < -512 || sample > 511)
                $fatal(1,"Invalid or excessive output %d",sample);
            @(posedge clk); #1; if(valid) $fatal(1,"Valid is not a pulse");
        end
    endtask
    initial begin
        repeat(4) @(negedge clk); rst=0;
        for(i=0;i<128;i=i+1) begin
            note=i; #1;
            freq=440.0*(2.0**((i-69)/12.0));
            ideal_step=freq*4294967296.0/(50000000.0/1040.0);
            if(step-ideal_step > 0.5001 || ideal_step-step > 0.5001)
                $fatal(1,"Note table error note=%0d step=%0d ideal=%f",i,step,ideal_step);
        end
        note=60;
        @(negedge clk); on=1;
        @(negedge clk); on=0;
        // Event arrives away from sample_ce. All subsequent samples must match
        // an analytic sine, not the DUT phase/ROM implementation.
        for(j=0;j<4;j=j+1) begin
            case(j) 0:note=60; 1:note=64; 2:note=67; 3:note=72; endcase
            value=note;
            freq=440.0*(2.0**((value-69)/12.0));
            @(negedge clk); pitch_we=1;
            @(negedge clk); pitch_we=0;
            first_cross=-1; last_cross=-1; crosses=0; previous=0;
            for(k=0;k<8192;k=k+1) begin
                tick;
                angle=angle+6.283185307179586*freq/(50000000.0/1040.0);
                if(angle>=6.283185307179586) angle=angle-6.283185307179586;
                expected=$rtoi(32767.0*65535.0/4194304.0*$sin(angle));
                value=sample;
                if(value-expected>5 || expected-value>5)
                    $fatal(1,"Sine/phase mismatch note=%0d index=%0d got=%0d ideal=%0d",note,k,value,expected);
                if(envelope!=65535) $fatal(1,"Pitch write reset envelope");
                if(k>0 && previous<0 && value>=0) begin
                    if(first_cross<0) first_cross=k;
                    last_cross=k; crosses=crosses+1;
                end
                previous=value;
            end
            measured=(crosses-1)*(50000000.0/1040.0)/(last_cross-first_cross);
            if(crosses<20 || measured/freq<0.999 || measured/freq>1.001)
                $fatal(1,"Frequency error %f vs %f",measured,freq);
            $display("FREQUENCY_PASS note=%0d measured=%f target=%f",note,measured,freq);
        end
        @(negedge clk); off=1;
        @(negedge clk); off=0;
        repeat(4) begin tick; if(sample!==0 || envelope!==0) $fatal(1,"Release not silent"); end
        rst=1; @(negedge clk); @(negedge clk);
        if(sample!==0 || valid!==0) $fatal(1,"Reset failed");
        $display("CORE_TB_PASS"); $finish;
    end
    initial begin #20000000; $fatal(1,"Core timeout"); end
endmodule

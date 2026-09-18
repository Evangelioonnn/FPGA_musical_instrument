`timescale 1ns/1ps
module quality_core_tb;
    reg clk=0,rst=1,ce=0,on=0,off=0,pitch_we=0;
    reg [6:0] note=60;
    wire [31:0] step;
    wire signed [15:0] sample;
    wire valid;
    wire [15:0] env;
    wire [2:0] state;
    integer j,k,n;
    real angle=0.0,freq,ideal,error,max_error=0.0;
    always #10 clk=~clk;
    note_table notes(note,step);
    quality_voice #(.ATTACK_STEP(65535),.DECAY_STEP(65535),
        .SUSTAIN_LEVEL(65535),.RELEASE_STEP(65535)) dut(
        clk,rst,ce,on,off,pitch_we,step,sample,valid,env,state);
    task tick;
        begin
            @(negedge clk); ce=1;
            @(posedge clk); #1; if(valid) $fatal(1,"Early valid E0");
            @(negedge clk); ce=0;
            repeat(4) begin @(posedge clk); #1; if(valid) $fatal(1,"Early valid E1..E4"); end
            @(posedge clk); #1;
            if(!valid || ^sample===1'bx || sample < -512 || sample > 512)
                $fatal(1,"Missing E5 valid or invalid sample");
            @(posedge clk); #1; if(valid) $fatal(1,"Valid not a pulse");
        end
    endtask
    initial begin
        repeat(4) @(negedge clk); rst=0;
        @(negedge clk); on=1;
        @(negedge clk); on=0;
        // Analytic reference, independent of the ROM/interpolation implementation.
        // Live pitch changes exercise phase continuity and both phase-wrap signs.
        for(j=0;j<7;j=j+1) begin
            case(j) 0:note=60; 1:note=64; 2:note=67; 3:note=72;
                4:note=69; 5:note=0; 6:note=127; endcase
            n=note; freq=440.0*(2.0**((n-69)/12.0));
            @(negedge clk); pitch_we=1;
            @(negedge clk); pitch_we=0;
            for(k=0;k<16384;k=k+1) begin
                tick;
                angle=angle+6.283185307179586*freq/(50000000.0/1040.0);
                if(angle>=6.283185307179586) angle=angle-6.283185307179586;
                ideal=32767.0*65535.0/4194304.0*$sin(angle);
                error=sample-ideal; if(error<0.0) error=-error;
                if(error>max_error) max_error=error;
                if(error>0.55 || env!=65535)
                    $fatal(1,"Analytic mismatch note=%0d sample=%0d ideal=%f error=%f",note,sample,ideal,error);
            end
        end
        @(negedge clk); off=1;
        @(negedge clk); off=0;
        repeat(4) begin tick; if(sample!==0 || env!==0) $fatal(1,"Release not silent"); end
        rst=1; repeat(2) @(negedge clk);
        if(sample!==0 || valid!==0) $fatal(1,"Reset failed");
        $display("QUALITY_CORE_TB_PASS samples=%0d max_error=%f",7*16384,max_error);
        $finish;
    end
    initial begin #30000000; $fatal(1,"Core timeout"); end
endmodule

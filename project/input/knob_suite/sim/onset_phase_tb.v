`timescale 1ns/1ps
// Sweep a new strike across every clock position of the real 1040-clock
// sample interval, while another voice continues. Two isolated original
// voices check the sum; separate assertions bound/count start commands.
module onset_phase_tb;
    reg clk=0,rst=1,request=0;
    reg [10:0] tick=0;
    wire ce=!rst && tick==0;
    reg [6:0] note=60;
    wire ready,accepted,rejected,out_valid,clipped,deadline,slot;
    wire [31:0] rejects;
    wire [1:0] busy,gated,captured;
    wire signed [15:0] sample,solo0,solo1;
    wire valid0,valid1;
    wire [15:0] env0,env1;
    wire [2:0] state0,state1;
    reg [31:0] step0,step1;
    integer offset,cycle=0,frame=0,expected,checked=0,cases=0;
    integer accepted_at0,accepted_at1,starts0=0,starts1=0;
    integer before_start0,before_start1,target_frame;
    always #10 clk=~clk;
    always @(posedge clk) begin
        cycle=cycle+1;
        if(rst)tick<=0;
        else tick<=tick==1039 ? 0 : tick+1'b1;
    end
    knob_bank #(.N(2)) dut(clk,rst,ce,request,ready,note,2'd0,24'd31250,
        16'd68,16'd6,16'd32768,16'd3,1'b0,1'b0,1'b0,
        accepted,rejected,slot,rejects,busy,gated,captured,out_valid,sample,clipped,deadline);
    wire start0=dut.slots[0].slot.on_cmd;
    wire start1=dut.slots[1].slot.on_cmd;
    synth_voice isolated0(clk,rst,ce,start0,1'b0,1'b0,step0,solo0,valid0,env0,state0);
    synth_voice isolated1(clk,rst,ce,start1,1'b0,1'b0,step1,solo1,valid1,env1,state1);
    function [31:0] musical; input integer midi; real frequency; begin
        frequency=440.0*(2.0**((midi-69)/12.0));
        musical=$rtoi(frequency*4294967296.0*1040.0/50000000.0+0.5);
    end endfunction
    always @(posedge clk) if(!rst)begin
        if(request && ready)begin
            if(!busy[0])accepted_at0=cycle;
            else accepted_at1=cycle;
        end
        if(start0)begin
            if(ce || cycle-accepted_at0<3 || cycle-accepted_at0>5)$fatal(1,"Start0 latency/alignment");
            starts0=starts0+1;
        end
        if(start1)begin
            if(ce || cycle-accepted_at1<3 || cycle-accepted_at1>5)$fatal(1,"Start1 latency/alignment");
            starts1=starts1+1;
        end
        if(rejected || clipped || deadline)$fatal(1,"Unexpected bank fault at phase %0d",offset);
        if(out_valid)begin
            frame=frame+1;expected=$signed(solo0)+$signed(solo1);
            if(sample!==expected)$fatal(1,"Start disturbed audio phase=%0d frame=%0d got=%0d want=%0d",offset,frame,sample,expected);
            checked=checked+1;
        end
    end
    task send;begin
        if(!ready)$fatal(1,"Unexpected backpressure");
        request=1;@(negedge clk);request=0;
    end endtask
    initial begin
        step0=musical(60);step1=musical(67);
        for(offset=0;offset<1040;offset=offset+1)begin
            @(negedge clk);rst=1;request=0;
            repeat(5)@(negedge clk);
            before_start0=starts0;before_start1=starts1;
            note=60;step1=musical(48+offset%37);rst=0;
            repeat(10)@(negedge clk);send;
            target_frame=frame+12;wait(frame>=target_frame);@(negedge clk);
            while(tick!=offset)@(negedge clk);
            note=48+offset%37;send;
            target_frame=frame+24;wait(frame>=target_frame);@(negedge clk);
            if(starts0-before_start0!=1 || starts1-before_start1!=1 || busy!=3)
                $fatal(1,"Duplicated/lost strike at phase %0d",offset);
            cases=cases+1;
        end
        $display("ONSET_PHASE_TB_PASS phases=%0d checked_frames=%0d real_sample_cycles=1040 isolated_sum_exact=1 single_start=1",cases,checked);
        $finish;
    end
endmodule

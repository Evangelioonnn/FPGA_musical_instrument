`timescale 1ns/1ps
// Requests land at every possible phase within a real 1040-clock sample frame.
// The independent original voice follows the actual accepted instance onset;
// it checks pitch/envelope/sample preservation through the whole slot wrapper.
module event_phase_tb;
    reg clk=0,rst=1;integer tick=0;
    wire ce=!rst && tick==0;
    reg start=0,stop=0,pedal=0;wire busy,held;wire signed [15:0] sample;
    wire [31:0] step;wire signed [15:0] reference;wire rv;wire [15:0] env;wire [2:0] es;
    integer phase,frames=0,checks=0,end_at;
    always #10 clk=~clk;
    always @(posedge clk)if(rst)tick<=0;else tick<=tick==1039?0:tick+1;
    playable_slot dut(clk,rst,ce,start,stop,7'd60,2'd0,pedal,16'd3,3'd3,busy,held,sample);
    note_table notes(7'd60,step);
    synth_voice original(clk,dut.voice_rst,ce,dut.on_cmd,dut.off_cmd,1'b0,step,reference,rv,env,es);
    always @(posedge clk)if(!rst)begin
        if(ce)frames=frames+1;
        if(tick==64 && busy)begin
            if(sample!==reference)$fatal(1,"Phase-dependent voice mismatch phase=%0d sample=%0d expected=%0d",phase,sample,reference);
            checks=checks+1;
        end
    end
    task clock_count;input integer n;begin repeat(n)@(negedge clk);end endtask
    initial begin
        for(phase=0;phase<1040;phase=phase+1)begin
            rst=1;start=0;stop=0;clock_count(5);rst=0;clock_count(phase+1);
            start=1;clock_count(1);start=0;
            end_at=frames+4;wait(frames>=end_at);@(negedge clk);clock_count(phase);
            stop=1;clock_count(1);stop=0;
            end_at=frames+6;wait(frames>=end_at);@(negedge clk);
            if(held)$fatal(1,"Off not delivered");
        end
        $display("EVENT_PHASE_TB_PASS real_sample_phases=1040 exact_reference_checks=%0d",checks);$finish;
    end
    initial begin #400000000;$fatal(1,"event phase timeout");end
endmodule

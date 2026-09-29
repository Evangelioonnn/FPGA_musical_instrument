`timescale 1ns/1ps
module activity_gate_tb;
    reg clk=0,rst=1,sample_ce=0,start=0,stop=0,pedal=0;
    reg [6:0] note=60;
    reg [1:0] timbre=0;
    reg [15:0] release_step=3;
    reg [2:0] fm_release_index=3;
    wire busy_ref,held_ref,busy_gate,held_gate;
    wire signed [15:0] sample_ref,sample_gate;
    integer nonzero_samples=0,tone;
    always #10 clk=~clk;
    playable_slot #(.GATE_UNUSED(0)) reference_slot(
        clk,rst,sample_ce,start,stop,note,timbre,pedal,release_step,
        fm_release_index,busy_ref,held_ref,sample_ref);
    playable_slot #(.GATE_UNUSED(1)) gated_slot(
        clk,rst,sample_ce,start,stop,note,timbre,pedal,release_step,
        fm_release_index,busy_gate,held_gate,sample_gate);

    always @(posedge clk) if(!rst) begin
        if(sample_ref!==sample_gate || busy_ref!==busy_gate || held_ref!==held_gate)
            $fatal(1,"activity gate changed observable voice behavior timbre=%0d",timbre);
        if(sample_ref!=0) nonzero_samples=nonzero_samples+1;
    end

    task sample_frame;
        begin
            @(negedge clk);sample_ce=1;
            @(negedge clk);sample_ce=0;
            repeat(38) @(negedge clk);
        end
    endtask

    task test_tone;
        input [1:0] selected_timbre;
        begin
            rst=1;sample_ce=0;start=0;stop=0;pedal=0;
            repeat(4) @(negedge clk);rst=0;repeat(3) @(negedge clk);
            timbre=selected_timbre;note=7'd60+selected_timbre;nonzero_samples=0;
            start=1;@(negedge clk);start=0;
            repeat(80) sample_frame();
            stop=1;@(negedge clk);stop=0;
            repeat(160) sample_frame();
            if(nonzero_samples<10 || !busy_ref)
                $fatal(1,"timbre %0d did not produce a comparable active signal",selected_timbre);
        end
    endtask

    initial begin
        for(tone=0;tone<3;tone=tone+1) test_tone(tone[1:0]);
        $display("ACTIVITY_GATE_TB_PASS three_timbres_pcm_busy_held_cycle_exact=1");
        $finish;
    end
    initial begin #4000000;$fatal(1,"activity gate timeout");end
endmodule

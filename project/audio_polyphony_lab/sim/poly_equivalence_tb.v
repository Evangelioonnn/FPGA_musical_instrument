`timescale 1ns/1ps
module poly_equivalence_tb;
    reg clk=0;always #10 clk=~clk;
    reg rst=1,ce=0;
    reg [31:0] phase=0;
    reg [15:0] level=0;
    wire valid,reference_valid,deadline;
    wire signed [31:0] raw;
    wire signed [19:0] reference_sample;
    reg signed [19:0] reference_hold;
    piano_poly_core #(.N(8),.OUTPUT_SHIFT(0)) dut(
        .clk(clk),.rst(rst),.sample_ce(ce),.event_valid(1'b0),.event_off(1'b0),
        .event_token(32'd0),.event_note(7'd60),.attack_step(16'd68),.decay_step(16'd6),
        .sustain_level(16'd32768),.release_step(16'd3),.sustain(1'b0),.sostenuto(1'b0),
        .out_valid(valid),.mixed_q4(raw),.deadline_missed(deadline));
    gallery_shared_tone #(.PROFILE(6),.N(1)) reference_renderer(
        clk,rst,ce,phase,level,16'hffff,7'd60,3'd0,
        reference_sample,reference_valid,);
    always @(negedge clk) if(reference_valid)reference_hold=reference_sample;
    integer i;
    reg [31:0] seed=32'h891237ac;
    initial begin
        repeat(5) @(negedge clk);rst=0;
        for(i=0;i<4096;i=i+1) begin
            seed=seed^ (seed<<13);seed=seed^ (seed>>17);seed=seed^ (seed<<5);
            phase=seed;level=seed[15:0];
            dut.phases[0]=phase;dut.steps[0]=0;dut.levels[0]=level;
            dut.env_states[0]=3;dut.sustains[0]=level;dut.occupied[0]=1;dut.held[0]=1;
            ce=1;@(negedge clk);ce=0;
            repeat(132) @(negedge clk);
            if(raw!=={{12{reference_hold[19]}},reference_hold} || deadline) begin
                $display("renderer mismatch phase=%h env=%d q4=%0d legacy=%0d",phase,level,raw,reference_hold);$fatal;
            end
        end
        $display("POLY_EQUIVALENCE_TB_PASS 4096 default piano phase/envelope vectors exact Q4");$finish;
    end
endmodule

`timescale 1ns/1ps
module looper_custom_bound_tb #(parameter N=8,FULL=1);
    reg clk=0;always #10 clk=~clk;
    reg rst=1,event_valid=0;integer divider=0,frames=0;
    wire sample_ce=divider==1039;
    always @(negedge clk) if(rst) divider=0;else divider=(divider+1)%1040;
    reg [31:0] token=1;wire ready,accepted,valid,clip,deadline,rejected;
    wire [N-1:0] occupied;wire signed [15:0] pcm;
    audio_v2_bank #(.N(N),.PLUCK_N(1)) dut(
        .clk(clk),.rst(rst),.sample_ce(sample_ce),.event_valid(event_valid),.event_ready(ready),
        .event_off(1'b0),.event_token(token),.event_note(7'd60),.event_timbre(3'd5),
        .event_is_loop(1'b0),.event_track(3'd4),.event_patch(136'd0),.track_gains({4{17'd65536}}),
        .pedal(1'b0),.sostenuto(1'b0),.reference_release(16'd3),.glide_index(3'd0),.lead_attack_index(2'd2),
        .bend_factor(17'd65536),.lead_bend_factor(17'd65536),.envelope_override(1'b1),.custom_hold(1'b1),
        .adsr_attack(16'd65535),.adsr_decay(16'd0),.adsr_sustain(16'd65535),.adsr_release(16'd3),
        .coeff0(9'd256),.coeff1(FULL ? 9'd256 : 9'd64),.coeff2(FULL ? 9'd256 : 9'd32),.coeff3(FULL ? 9'd256 : 9'd16),
        .accepted(accepted),.rejected(rejected),.occupied(occupied),.out_valid(valid),.out_sample(pcm),.clipped(clip),.deadline_missed(deadline));
    integer clips=0,peak=0,magnitude=0,render_cycles=0,max_render=0,i;
    always @(posedge clk) begin #1;if(!rst) begin
        if(sample_ce) begin frames=frames+1;render_cycles=0;end else render_cycles=render_cycles+1;
        if(deadline || rejected) $fatal(1,"bound deadline/rejection");
        if(clip) clips=clips+1;
        if(valid) begin
            if(render_cycles>max_render) max_render=render_cycles;
            magnitude=pcm<0 ? -pcm : pcm;if(magnitude>peak) peak=magnitude;
            if(N==8 && FULL && magnitude>16384) $fatal(1,"eight-full conservative bound");
            if(N==32 && !FULL && magnitude>23552) $fatal(1,"32-default conservative bound");
        end
    end end
    initial begin repeat(4) @(negedge clk);rst=0;
        for(i=0;i<N;i=i+1) begin
            @(negedge clk);#2;while(!ready) begin @(negedge clk);#2;end
            token=i+1;event_valid=1;@(negedge clk);#2;event_valid=0;
            wait(accepted);@(negedge clk);
        end
        wait(frames>=1200);
        if(occupied!={N{1'b1}}) $fatal(1,"bound allocation");
        if((N==8 || !FULL) && clips!=0) $fatal(1,"safe combination clipped");
        if(N==32 && FULL && clips==0) $fatal(1,"pathological clipping not detected");
        $display("LOOPER_CUSTOM_BOUND_TB_PASS N=%0d full=%0d same_pitch=1 peak=%0d clip_frames=%0d max_render=%0d",N,FULL,peak,clips,max_render);$finish;
    end
    initial begin #100000000;$fatal(1,"bound watchdog");end
endmodule

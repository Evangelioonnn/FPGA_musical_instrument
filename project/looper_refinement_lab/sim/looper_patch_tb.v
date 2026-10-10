`timescale 1ns/1ps
module looper_patch_tb;
    reg clk=0;always #10 clk=~clk;
    reg rst=1,sample_ce=0,event_valid=0,event_off=0;
    reg [31:0] event_token=11;reg [6:0] event_note=60;reg [2:0] event_timbre=5,event_track=1;
    reg event_is_loop=1;reg [135:0] event_patch=0;
    wire ready_a,ready_b,accepted_a,accepted_b,valid_a,valid_b,deadline_a,deadline_b;
    wire signed [15:0] sample_a,sample_b;wire [0:0] held_a,gated_a,occupied_a;
    wire [31:0] rejects_a,rejects_b;
    audio_v2_bank #(.N(1),.PLUCK_N(1)) frozen(
        .clk(clk),.rst(rst),.sample_ce(sample_ce),.event_valid(event_valid),.event_ready(ready_a),
        .event_off(event_off),.event_token(event_token),.event_note(event_note),.event_timbre(event_timbre),
        .event_is_loop(event_is_loop),.event_track(event_track),.event_patch(event_patch),.track_gains({4{17'd65536}}),
        .pedal(1'b1),.sostenuto(1'b1),.reference_release(16'd1),.glide_index(3'd4),.lead_attack_index(2'd0),
        .bend_factor(17'd73562),.lead_bend_factor(17'd73562),.envelope_override(1'b0),.custom_hold(1'b0),
        .adsr_attack(16'd1),.adsr_decay(16'd1),.adsr_sustain(16'd0),.adsr_release(16'd1),
        .coeff0(9'd0),.coeff1(9'd0),.coeff2(9'd0),.coeff3(9'd0),
        .accepted(accepted_a),.rejected_count(rejects_a),.out_valid(valid_a),.out_sample(sample_a),
        .held(held_a),.gated(gated_a),.occupied(occupied_a),.deadline_missed(deadline_a));
    audio_v2_bank #(.N(1),.PLUCK_N(1)) constant_reference(
        .clk(clk),.rst(rst),.sample_ce(sample_ce),.event_valid(event_valid),.event_ready(ready_b),
        .event_off(event_off),.event_token(event_token),.event_note(event_note),.event_timbre(event_timbre),
        .event_is_loop(1'b0),.event_track(3'd4),.event_patch(136'd0),.track_gains({4{17'd65536}}),
        .pedal(1'b0),.sostenuto(1'b0),.reference_release(16'd3),.glide_index(3'd0),.lead_attack_index(2'd2),
        .bend_factor(17'd65536),.lead_bend_factor(17'd65536),.envelope_override(1'b1),.custom_hold(1'b1),
        .adsr_attack(16'd65535),.adsr_decay(16'd0),.adsr_sustain(16'd65535),.adsr_release(16'd512),
        .coeff0(9'd256),.coeff1(9'd0),.coeff2(9'd0),.coeff3(9'd0),
        .accepted(accepted_b),.rejected_count(rejects_b),.out_valid(valid_b),.out_sample(sample_b),.deadline_missed(deadline_b));
    integer cycle=0,frames=0,nonzero=0;
    always @(negedge clk) begin
        if(rst) begin cycle=0;sample_ce=0;end
        else begin sample_ce=cycle==1039;cycle=(cycle+1)%1040;end
    end
    always @(posedge clk) begin #1;if(!rst && valid_a) begin
        frames=frames+1;
        if(valid_b!==1 || sample_a!==sample_b) $fatal(1,"frozen patch PCM mismatch frame=%0d actual=%0d reference=%0d",frames,sample_a,sample_b);
        if(sample_a!=0) nonzero=nonzero+1;
        if(deadline_a || deadline_b || rejects_a!=0 || rejects_b!=0) $fatal(1,"patch/deadline fault");
    end end
    task command;
        input off;
        begin
            @(negedge clk);#2;while(!ready_a || !ready_b) begin @(negedge clk);#2;end
            event_off=off;event_valid=1;
            @(negedge clk);#2;event_valid=0;
            // Poison upstream metadata while the bank is still scanning.
            event_is_loop=0;event_track=3;event_patch=0;
            wait(accepted_a && accepted_b);
            @(negedge clk);
        end
    endtask
    initial begin
        event_patch[2:0]=5;event_patch[11:3]=256;
        event_patch[66:51]=65535;event_patch[82:67]=0;event_patch[98:83]=65535;
        event_patch[114:99]=512;event_patch[117:115]=5;event_patch[119:118]=2;
        event_patch[123]=1;event_patch[124]=1;
        repeat(4) @(negedge clk);rst=0;command(0);
        if(frozen.tracks[0]!=1 || !frozen.loop_mask[0]) $fatal(1,"command metadata was not locked");
        wait(frames>=1200);
        command(1);wait(frames>=1400);
        if(held_a || gated_a || occupied_a || nonzero<100) $fatal(1,"loop release/patch failed");
        $display("LOOPER_PATCH_TB_PASS frozen_custom=PCM_equal upstream_poison=ignored loop_off=ignores_live_pedal frames=%0d",frames);
        $finish;
    end
    initial begin #100000000;$fatal(1,"patch watchdog");end
endmodule

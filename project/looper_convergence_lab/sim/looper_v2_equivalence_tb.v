`timescale 1ns/1ps
// Original accepted V2 bank is independently compiled under a renamed module.
// Compare by sample index, not by different implementation latency.
module looper_v2_equivalence_tb;
    reg clk=0;always #10 clk=~clk;
    reg rst=1,event_valid=0,event_off=0;integer divider=0;
    wire sample_ce=divider==1039;
    always @(negedge clk) if(rst) divider=0;else divider=(divider+1)%1040;
    reg [2:0] preset=0;reg [135:0] patch=0;
    wire ra,rb,rc,aa,ab,ac,va,vb,vc,da,db,dc;
    wire signed [15:0] sa,sb,sc;
    audio_v2_bank #(.N(1),.PLUCK_N(1)) live_bank(
        .clk(clk),.rst(rst),.sample_ce(sample_ce),.event_valid(event_valid),.event_ready(ra),.event_off(event_off),
        .event_token(32'd1),.event_note(7'd60),.event_timbre(preset),.event_is_loop(1'b0),.event_track(3'd4),.event_patch(136'd0),
        .track_gains({4{17'd65536}}),.pedal(1'b0),.sostenuto(1'b0),.reference_release(16'd3),.glide_index(3'd0),
        .lead_attack_index(2'd2),.bend_factor(17'd65536),.lead_bend_factor(17'd65536),.envelope_override(1'b0),.custom_hold(1'b1),
        .adsr_attack(16'd68),.adsr_decay(16'd6),.adsr_sustain(16'd32768),.adsr_release(16'd3),
        .coeff0(9'd256),.coeff1(9'd64),.coeff2(9'd32),.coeff3(9'd16),.accepted(aa),.out_valid(va),.out_sample(sa),.deadline_missed(da));
    audio_v2_bank #(.N(1),.PLUCK_N(1)) loop_bank(
        .clk(clk),.rst(rst),.sample_ce(sample_ce),.event_valid(event_valid),.event_ready(rc),.event_off(event_off),
        .event_token(32'd1),.event_note(7'd60),.event_timbre(preset),.event_is_loop(1'b1),.event_track(3'd0),.event_patch(patch),
        .track_gains({4{17'd65536}}),.pedal(1'b0),.sostenuto(1'b0),.reference_release(16'd3),.glide_index(3'd0),
        .lead_attack_index(2'd2),.bend_factor(17'd65536),.lead_bend_factor(17'd65536),.envelope_override(1'b0),.custom_hold(1'b1),
        .adsr_attack(16'd68),.adsr_decay(16'd6),.adsr_sustain(16'd32768),.adsr_release(16'd3),
        .coeff0(9'd256),.coeff1(9'd64),.coeff2(9'd32),.coeff3(9'd16),.accepted(ac),.out_valid(vc),.out_sample(sc),.deadline_missed(dc));
    reference_v2_bank #(.N(1),.PLUCK_N(1)) original(
        .clk(clk),.rst(rst),.sample_ce(sample_ce),.event_valid(event_valid),.event_ready(rb),.event_off(event_off),
        .event_token(32'd1),.event_note(7'd60),.event_timbre(preset),.pedal(1'b0),.sostenuto(1'b0),.reference_release(16'd3),.glide_index(3'd0),
        .lead_attack_index(2'd2),.bend_factor(17'd65536),.lead_bend_factor(17'd65536),.envelope_override(1'b0),.custom_hold(1'b1),
        .adsr_attack(16'd68),.adsr_decay(16'd6),.adsr_sustain(16'd32768),.adsr_release(16'd3),
        .coeff0(9'd256),.coeff1(9'd64),.coeff2(9'd32),.coeff3(9'd16),.accepted(ab),.out_valid(vb),.out_sample(sb),.deadline_missed(db));
    integer na=0,nb=0,nc=0,compared=0,total=0,frames=0,nonzero=0;
    reg signed [15:0] la,lb,lc;
    always @(posedge clk) begin #1;
        if(rst) begin na=0;nb=0;nc=0;compared=0;frames=0;end
        else begin
            if(sample_ce) frames=frames+1;
            if(va) begin na=na+1;la=sa;end
            if(vb) begin nb=nb+1;lb=sb;end
            if(vc) begin nc=nc+1;lc=sc;end
            if(na==nb && nb==nc && na>compared) begin
                if(la!==lb || lc!==lb) $fatal(1,"V2 equivalence preset=%0d frame=%0d live=%0d loop=%0d original=%0d",preset,na,la,lc,lb);
                compared=na;total=total+1;if(lb!=0) nonzero=nonzero+1;
            end
            if(da || db || dc) $fatal(1,"equivalence deadline");
        end
    end
    task command;
        input off;
        begin @(negedge clk);#2;while(!ra || !rb || !rc) begin @(negedge clk);#2;end
            event_off=off;event_valid=1;@(negedge clk);#2;event_valid=0;
            wait(ra && rb && rc);@(negedge clk);end
    endtask
    task check;
        input [2:0] p;
        begin @(negedge clk);rst=1;repeat(4) @(negedge clk);
            preset=p;patch=0;patch[2:0]=p;patch[11:3]=256;patch[23:15]=64;patch[35:27]=32;patch[47:39]=16;
            patch[66:51]=68;patch[82:67]=6;patch[98:83]=32768;patch[114:99]=3;
            patch[117:115]=5;patch[119:118]=2;patch[124]=1;rst=0;
            command(0);wait(frames>=400);command(1);wait(frames>=800);repeat(100) @(negedge clk);
            if(compared<799) $fatal(1,"not enough comparison frames");end
    endtask
    initial begin check(0);check(2);check(3);check(4);check(5);
        if(nonzero<1000) $fatal(1,"silent oracle");
        $display("LOOPER_V2_EQUIVALENCE_TB_PASS live_and_frozen_default_bit_exact_with_original_V2 presets=0_2_3_4_5 comparisons=%0d",total);$finish;end
    initial begin #500000000;$fatal(1,"equivalence watchdog");end
endmodule

`timescale 1ns/1ps
module v2_bank_tb #(parameter P=8,MODE=0);
    reg clk=0;always #10 clk=~clk;
    reg rst=1,ce=0,ev=0,off=0,pedal=0,sost=0,override_env=0;
    reg [31:0] token=0;reg [6:0] note=60;reg [2:0] preset=0,glide=0;
    reg [16:0] bend=65536,lead_bend=65536;
    reg [15:0] release_step=3,attack=68,decay=6,sustain_level=32768;
    reg [8:0] c0=256,c1=64,c2=32,c3=16;
    wire ready,old_ready,accepted,rejected,valid,clip,deadline;
    wire [31:0] occupied,held,gated,rejects,unmatched;
    wire signed [15:0] sample;
    wire [639:0] old_samples;
    wire signed [15:0] old_sample;wire old_valid;
    audio_v2_bank #(.PLUCK_N(P)) dut(.clk(clk),.rst(rst),.sample_ce(ce),.event_valid(ev),
        .event_ready(ready),.event_off(off),.event_token(token),.event_note(note),.event_timbre(preset),
        .pedal(pedal),.sostenuto(sost),.reference_release(release_step),.glide_index(glide),
        .lead_attack_index(2'd2),.bend_factor(bend),.lead_bend_factor(lead_bend),
        .envelope_override(override_env),.custom_hold(1'b0),.adsr_attack(attack),.adsr_decay(decay),
        .adsr_sustain(sustain_level),.adsr_release(release_step),.coeff0(c0),.coeff1(c1),.coeff2(c2),.coeff3(c3),
        .accepted(accepted),.rejected(rejected),.rejected_count(rejects),.unmatched_off_count(unmatched),
        .occupied(occupied),.held(held),.gated(gated),.out_valid(valid),.out_sample(sample),
        .clipped(clip),.deadline_missed(deadline));
    audio_voice_bank #(.PROFILE(6),.N(8)) reference(.clk(clk),.rst(rst),.sample_ce(ce),.event_valid(ev),
        .event_ready(old_ready),.event_off(off),.event_token(token),.event_note(note),.event_timbre(preset),
        .pedal(pedal),.sostenuto(sost),.reference_release(release_step),.glide_index(glide),
        .lead_attack_index(2'd2),.bend_factor(bend),.lead_bend_factor(lead_bend),
        .envelope_override(override_env),.custom_hold(1'b0),.adsr_attack(attack),.adsr_decay(decay),
        .adsr_sustain(sustain_level),.adsr_release(release_step),.coeff0(c0),.coeff1(c1),.coeff2(c2),.coeff3(c3),
        .out_valid(old_valid),.out_sample(old_sample));
    integer ticks=0,frames=0,comparisons=0,outputs=0,latency=0,worst_latency=0,i,k;
    reg compare=0,require_old=1;
    reg signed [31:0] total,rounded;
    reg signed [19:0] old_term,new_term;
    always @(negedge clk) begin
        if(rst) begin ticks=0;ce=0;end
        else begin ce=ticks==1039;ticks=(ticks+1)%1040;end
    end
    always @(posedge clk) begin
        #1;
        if(!rst) begin
            if(ce) begin
                if(frames!=0 && outputs!=1) $fatal(1,"not one output per 1040-clock frame");
                outputs=0;latency=0;
            end else latency=latency+1;
            if(deadline || clip || (^sample)===1'bx) $fatal(1,"deadline/clip/unknown in bank");
            if(valid) begin
                outputs=outputs+1;frames=frames+1;
                if(latency>worst_latency) worst_latency=latency;
                if(compare) begin
                    total=0;
                    for(k=0;k<8;k=k+1) begin
                        old_term=reference.samples[k*20+:20];
                        new_term=dut.pmapped[k] ? dut.psamples[k*20+:20] : dut.hsamples[k*20+:20];
                        if(old_term!==new_term) begin
                            $display("tone mismatch frame=%0d preset=%0d slot=%0d old=%0d new=%0d env=%0d/%0d phase=%h/%h",
                                frames,preset,k,old_term,new_term,reference.envelopes[k*16+:16],dut.envs[k*16+:16],
                                reference.phases[k*32+:32],dut.phases[k*32+:32]);$fatal;
                        end
                        total=total+(reference.presets_snapshot[k*3+:3]==2 ? (old_term*4) : old_term);
                    end
                    rounded=total<0 ? -(((-total)+32)>>>6) : (total+32)>>>6;
                    if(sample!==rounded[15:0]) $fatal(1,"independent weighted mixing mismatch");
                    comparisons=comparisons+1;
                end
            end
        end
    end
    task wait_frames;input integer count;integer end_frame;
        begin end_frame=frames+count;while(frames<end_frame) @(negedge clk);end
    endtask
    task reset;
        begin compare=0;rst=1;ev=0;repeat(10) @(negedge clk);rst=0;wait_frames(2);end
    endtask
    task command;
        input is_off;input [31:0] id;input [6:0] midi;input [2:0] timbre;input expect_on;
        begin
            @(negedge clk);#1;
            // Compare identical audio-frame onset, independently of scan latency.
            // Arbitrary-phase onset latency is covered by v2_extended_tb.
            if(require_old)
                while(ticks!=800) begin @(negedge clk);#1;end
            while(!(ready && (!require_old || old_ready))) begin @(negedge clk);#1;end
            token=id;note=midi;preset=timbre;off=is_off;ev=1;
            @(negedge clk);ev=0;
            while(!accepted && !rejected) @(negedge clk);
            if(!is_off && (accepted!==expect_on || rejected===expect_on))
                $fatal(1,"wrong acceptance id=%0d timbre=%0d accepted=%b rejected=%b",id,timbre,accepted,rejected);
            repeat(20) @(negedge clk);
        end
    endtask
    integer timbre;
    initial begin
        for(i=0;i<(MODE==2 ? 0 : 5);i=i+1) begin
            timbre=i==0 ? 0 : i+1;override_env=0;release_step=3;
            bend=65536;lead_bend=65536;pedal=0;sost=0;glide=0;require_old=1;
            reset();command(0,1,48,timbre,1);command(0,2,60,timbre,1);command(0,3,72,timbre,1);
            wait_frames(10);compare=1;wait_frames(1200);
            command(1,1,48,timbre,0);command(1,2,60,timbre,0);command(1,3,72,timbre,0);
            wait_frames(100);compare=0;
            $display("V2_TONE_EQUIVALENCE preset=%0d cumulative_frames=%0d",timbre,comparisons);
        end
        if(MODE==1) begin $display("V2_BANK_TB_PASS equivalence_only=%0d",comparisons);$finish;end
        require_old=0;override_env=1;attack=65535;decay=1;sustain_level=65535;release_step=65535;
        c0=92;c1=92;c2=92;c3=92;
        for(i=0;i<4;i=i+1) begin
            timbre=i==0 ? 0 : i==1 ? 3 : i==2 ? 4 : 5;
            $display("V2_CAPACITY_START preset=%0d",timbre);
            reset();
            for(k=0;k<32;k=k+1) command(0,100+k,48,timbre,1);
            if(occupied!==32'hffffffff || held!==32'hffffffff) $fatal(1,"full32 not occupied");
            command(0,999,60,timbre,0);if(rejects!=1) $fatal(1,"full capacity rejection");
            wait_frames(150);
            for(k=0;k<32;k=k+1) command(1,100+k,48,timbre,0);
            wait_frames(20);if(held!=0 || occupied!=0) $fatal(1,"32 note-offs failed");
            $display("V2_CAPACITY_PASS preset=%0d",timbre);
        end
        reset();
        for(k=0;k<P;k=k+1) command(0,200+k,48,2,1);
        command(0,777,60,2,0);if(rejects!=1) $fatal(1,"pluck pool limit ignored");
        for(k=P;k<32;k=k+1) command(0,200+k,48,0,1);
        if(occupied!==32'hffffffff) $fatal(1,"mixed32 not full");
        command(0,888,60,0,0);wait_frames(150);
        for(k=0;k<32;k=k+1) command(1,200+k,48,0,0);
        wait_frames(20);if(held!=0) $fatal(1,"mixed note-offs failed");
        $display("V2_BANK_TB_PASS comparison_frames=%0d total_frames=%0d warm_capacity=%0d worst_render_clocks=%0d",comparisons,frames,P,worst_latency);
        $finish;
    end
    initial begin #1000000000;$fatal(1,"bank test timed out");end
endmodule

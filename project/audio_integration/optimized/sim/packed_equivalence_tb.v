`timescale 1ns/1ps
module packed_equivalence_tb;
    reg clk=0;always #10 clk=~clk;
    reg rst=1,ce=0,ev=0,off=0,pedal=0,sost=0,override_env=0;
    reg [31:0] token=0;
    reg [6:0] note=60;
    reg [2:0] preset=0,glide=0;
    reg [16:0] bend=65536,lead_bend=65536;
    reg [15:0] release_step=3,attack=68,decay=6,sustain_level=32768;
    reg [8:0] c0=256,c1=64,c2=32,c3=16;
    wire ready,reference_ready,accepted,rejected,valid,reference_valid,clip,deadline;
    wire [31:0] occupied,held,gated;
    wire signed [15:0] sample,reference_sample;
    wire reference_clip,reference_deadline;
    audio_v2_bank #(.PLUCK_N(12)) dut(.clk(clk),.rst(rst),.sample_ce(ce),.event_valid(ev),
        .event_ready(ready),.event_off(off),.event_token(token),.event_note(note),.event_timbre(preset),
        .pedal(pedal),.sostenuto(sost),.reference_release(release_step),.glide_index(glide),
        .lead_attack_index(2'd2),.bend_factor(bend),.lead_bend_factor(lead_bend),
        .envelope_override(override_env),.custom_hold(1'b1),.adsr_attack(attack),.adsr_decay(decay),
        .adsr_sustain(sustain_level),.adsr_release(release_step),.coeff0(c0),.coeff1(c1),.coeff2(c2),.coeff3(c3),
        .accepted(accepted),.rejected(rejected),.occupied(occupied),.held(held),.gated(gated),
        .out_valid(valid),.out_sample(sample),.clipped(clip),.deadline_missed(deadline));
    audio_v2_bank_reference #(.PLUCK_N(12)) reference(.clk(clk),.rst(rst),.sample_ce(ce),.event_valid(ev),
        .event_ready(reference_ready),.event_off(off),.event_token(token),.event_note(note),.event_timbre(preset),
        .pedal(pedal),.sostenuto(sost),.reference_release(release_step),.glide_index(glide),
        .lead_attack_index(2'd2),.bend_factor(bend),.lead_bend_factor(lead_bend),
        .envelope_override(override_env),.custom_hold(1'b1),.adsr_attack(attack),.adsr_decay(decay),
        .adsr_sustain(sustain_level),.adsr_release(release_step),.coeff0(c0),.coeff1(c1),.coeff2(c2),.coeff3(c3),
        .out_valid(reference_valid),.out_sample(reference_sample),
        .clipped(reference_clip),.deadline_missed(reference_deadline));
    integer ticks=0,frames=0,comparisons=0,outputs=0,reference_outputs=0,
            latency=0,worst_latency=0,i,k,timbre;
    reg signed [15:0] reference_pcm;
    reg [1023:0] reference_phases;
    reg [511:0] reference_envs;
    reg [31:0] reference_busy,reference_held,reference_gated;
    reg frame_seen=0;
    always @(negedge clk) begin
        if(rst) begin ticks=0;ce=0;end
        else begin ce=ticks==1039;ticks=(ticks+1)%1040;end
    end
    always @(posedge clk) begin
        #1;
        if(rst) frame_seen=0;
        else begin
            if(ce) begin
                if(frame_seen && (outputs!=1 || reference_outputs!=1))
                    $fatal(1,"not one output per 1040-clock frame");
                outputs=0;reference_outputs=0;latency=0;
            end else latency=latency+1;
            if(deadline || reference_deadline || clip || reference_clip)
                $fatal(1,"deadline/clip in equivalence run");
            if(reference_valid) begin
                reference_outputs=reference_outputs+1;
                reference_pcm=reference_sample;reference_phases=reference.phases;
                reference_envs=reference.envs;reference_busy=reference.occupied;
                reference_held=reference.held;reference_gated=reference.gated;
            end
            if(valid) begin
                frame_seen=1;
                outputs=outputs+1;frames=frames+1;
                if(latency>worst_latency) worst_latency=latency;
                if(sample!==reference_pcm || dut.phases!==reference_phases || dut.envs!==reference_envs ||
                   occupied!==reference_busy || held!==reference_held || gated!==reference_gated) begin
                    $display("packed mismatch frame=%0d timbre=%0d PCM=%0d/%0d phase=%h/%h env=%h/%h",
                        frames,preset,sample,reference_pcm,dut.phases,reference_phases,dut.envs,reference_envs);
                    $fatal;
                end
                comparisons=comparisons+1;
            end
        end
    end
    task wait_frames;input integer count;integer end_frame;
        begin end_frame=frames+count;while(frames<end_frame) @(negedge clk);end
    endtask
    task reset;
        begin rst=1;ev=0;outputs=0;reference_outputs=0;
            repeat(10) @(negedge clk);rst=0;wait_frames(2);end
    endtask
    task command;
        input is_off;input [31:0] id;input [6:0] midi;input [2:0] timbre;
        begin
            @(negedge clk);#1;
            while(ticks!=800 || !ready || !reference_ready) begin @(negedge clk);#1;end
            token=id;note=midi;preset=timbre;off=is_off;ev=1;
            @(negedge clk);ev=0;
            while(!accepted && !rejected) @(negedge clk);
            if(rejected) $fatal(1,"unexpected reject");
            repeat(20) @(negedge clk);
        end
    endtask
    initial begin
        for(i=0;i<5;i=i+1) begin
            timbre=i==0 ? 0 : i+1;
            override_env=0;release_step=3;bend=65536;lead_bend=65536;glide=0;pedal=0;sost=0;
            reset();
            for(k=0;k<(timbre==2 ? 12 : 32);k=k+1)
                command(0,100+k,36+(k%32),timbre);
            wait_frames(1000);
            for(k=0;k<(timbre==2 ? 12 : 32);k=k+1)
                command(1,100+k,36+(k%32),timbre);
            wait_frames(200);
        end
        override_env=1;attack=1024;decay=6;sustain_level=50000;release_step=96;
        reset();
        for(k=0;k<32;k=k+1) command(0,300+k,36+k,k<12 ? 2 : k%4==0 ? 0 : k%4==1 ? 3 : k%4==2 ? 4 : 5);
        wait_frames(200);
        // Parameter commits occur at sample boundaries in the public API.
        @(negedge clk);while(ticks!=1039) @(negedge clk);
        bend=67456;lead_bend=66489;c0=92;c1=92;c2=92;c3=92;
        wait_frames(400);
        for(k=0;k<32;k=k+1) command(1,300+k,36+k,0);
        wait_frames(800);
        $display("PACKED_EQUIVALENCE_TB_PASS frames=%0d PCM_state_equivalent_frames=%0d worst_render_clocks=%0d",
            frames,comparisons,worst_latency);
        $finish;
    end
    initial begin #1500000000;$fatal(1,"packed equivalence timed out");end
endmodule

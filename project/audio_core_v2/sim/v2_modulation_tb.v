`timescale 1ns/1ps
module v2_modulation_tb #(parameter P=12);
    reg clk=0;always #10 clk=~clk;
    reg rst=1,ce=0,ev=0,off=0,pedal=0,sost=0;
    reg [31:0] token=0;
    reg [6:0] note=60;
    reg [2:0] preset=4,glide=0;
    reg [16:0] bend=65536,lead_bend=65536;
    reg [15:0] release_step=3;
    wire ready,old_ready,accepted,rejected,valid,deadline,clip;
    wire [31:0] occupied,held,gated;
    wire signed [15:0] sample;
    audio_v2_bank #(.PLUCK_N(P)) dut(
        .clk(clk),.rst(rst),.sample_ce(ce),.event_valid(ev),.event_ready(ready),
        .event_off(off),.event_token(token),.event_note(note),.event_timbre(preset),
        .pedal(pedal),.sostenuto(sost),.reference_release(release_step),.glide_index(glide),
        .lead_attack_index(2'd2),.bend_factor(bend),.lead_bend_factor(lead_bend),
        .envelope_override(1'b0),.custom_hold(1'b1),.adsr_attack(16'd68),.adsr_decay(16'd6),
        .adsr_sustain(16'd32768),.adsr_release(16'd3),
        .coeff0(9'd256),.coeff1(9'd64),.coeff2(9'd32),.coeff3(9'd16),
        .accepted(accepted),.rejected(rejected),.occupied(occupied),.held(held),.gated(gated),
        .out_valid(valid),.out_sample(sample),.deadline_missed(deadline),.clipped(clip));
    audio_voice_bank #(.PROFILE(6),.N(8)) reference(
        .clk(clk),.rst(rst),.sample_ce(ce),.event_valid(ev),.event_ready(old_ready),
        .event_off(off),.event_token(token),.event_note(note),.event_timbre(preset),
        .pedal(pedal),.sostenuto(sost),.reference_release(release_step),.glide_index(glide),
        .lead_attack_index(2'd2),.bend_factor(bend),.lead_bend_factor(lead_bend),
        .envelope_override(1'b0),.custom_hold(1'b1),.adsr_attack(16'd68),.adsr_decay(16'd6),
        .adsr_sustain(16'd32768),.adsr_release(16'd3),
        .coeff0(9'd256),.coeff1(9'd64),.coeff2(9'd32),.coeff3(9'd16));
    integer tick=0,frames=0,compared=0,k;
    reg compare=0;
    reg signed [31:0] expected,rounded;
    reg signed [19:0] old_term;
    always @(negedge clk) begin
        if(rst) begin tick=0;ce=0;end
        else begin ce=tick==1039;tick=(tick+1)%1040;end
    end
    always @(posedge clk) begin
        #1;
        if(!rst && (deadline||clip||(^sample)===1'bx)) $fatal(1,"modulation fault");
        if(!rst && valid) begin
            frames=frames+1;
            if(compare) begin
                expected=0;
                for(k=0;k<8;k=k+1) begin
                    old_term=reference.samples[k*20+:20];
                    if(dut.hsamples[k*20+:20]!==old_term) begin
                        $display("modulation mismatch frame=%0d slot=%0d preset=%0d old/new=%0d/%0d phase=%h/%h env=%0d/%0d",
                            frames,k,preset,old_term,$signed(dut.hsamples[k*20+:20]),
                            reference.phases[k*32+:32],dut.phases[k*32+:32],
                            reference.envelopes[k*16+:16],dut.envs[k*16+:16]);
                        $fatal;
                    end
                    expected=expected+old_term;
                end
                rounded=expected<0 ? -(((-expected)+32)>>>6) : (expected+32)>>>6;
                if(sample!==rounded[15:0]) $fatal(1,"modulated mix mismatch");
                compared=compared+1;
            end
        end
    end
    task wait_frames;input integer count;integer limit;
        begin limit=frames+count;while(frames<limit) @(negedge clk);end
    endtask
    task command;input is_off;input [31:0] id;input [6:0] midi;
        begin
            // Place both schedulers' commits before the same audio boundary.
            @(negedge clk);#1;
            while(tick!=800 || !ready || !old_ready) begin @(negedge clk);#1;end
            token=id;note=midi;off=is_off;ev=1;
            @(negedge clk);ev=0;
            while(!accepted&&!rejected) @(negedge clk);
            if(rejected) $fatal(1,"modulation strike rejected");
            repeat(20) @(negedge clk);
        end
    endtask
    task reset;
        begin compare=0;rst=1;ev=0;repeat(10) @(negedge clk);rst=0;wait_frames(2);end
    endtask
    initial begin
        reset();command(0,1,60);wait_frames(5);compare=1;wait_frames(100);
        glide=1;command(0,2,72);wait_frames(1100);
        command(0,3,48);wait_frames(1100);
        lead_bend=73562;wait_frames(220);lead_bend=58386;wait_frames(260);
        lead_bend=65536;wait_frames(180);
        pedal=1;command(1,1,60);command(1,2,72);wait_frames(50);
        sost=1;wait_frames(3);command(1,3,48);release_step=255;pedal=0;wait_frames(50);
        sost=0;release_step=255;wait_frames(400);
        if(held!=0||occupied!=0) $fatal(1,"modulated voices not freed");
        preset=5;glide=0;release_step=3;reset();command(0,10,48);
        wait_frames(5);compare=1;wait_frames(300);bend=73562;wait_frames(250);
        bend=58386;wait_frames(300);bend=65536;wait_frames(180);
        command(1,10,48);release_step=255;wait_frames(400);
        $display("V2_MODULATION_TB_PASS %0d bit-exact frames: ascending/descending glide, two bend directions, held custom, ordinary/selective sustain and releases",compared);
        $finish;
    end
    initial begin #300000000;$fatal(1,"modulation timeout");end
endmodule

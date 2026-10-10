`timescale 1ns/1ps
// Offline audition: accelerated CE=64, one melodic slot, dry pre-master PCM.
// Logical sample rate/pitch/envelopes remain Fs=50MHz/1040. Not a deadline test.
module looper_preview_tb;
    reg clk=0;always #10 clk=~clk;
    reg rst=1;integer divider=0,frames=0,file_id=0,kind=0;
    wire ce=divider==63;
    always @(negedge clk) if(rst) divider=0;else divider=(divider+1)%64;
    reg ev=0,off=0;reg [2:0] preset=0;wire ready,accepted,valid,deadline,clip;
    wire signed [15:0] pcm;
    audio_v2_bank #(.N(1),.PLUCK_N(1)) bank(
        .clk(clk),.rst(rst),.sample_ce(ce),.event_valid(ev),.event_ready(ready),
        .event_off(off),.event_token(32'd1),.event_note(7'd60),.event_timbre(preset),
        .event_is_loop(1'b0),.event_track(3'd4),.event_patch(136'd0),.track_gains({4{17'd65536}}),
        .pedal(1'b0),.sostenuto(1'b0),.reference_release(16'd3),.glide_index(3'd0),
        .lead_attack_index(2'd2),.bend_factor(17'd65536),.lead_bend_factor(17'd65536),
        .envelope_override(1'b0),.custom_hold(1'b1),.adsr_attack(16'd68),.adsr_decay(16'd6),
        .adsr_sustain(16'd32768),.adsr_release(16'd3),.coeff0(9'd256),.coeff1(9'd64),.coeff2(9'd32),.coeff3(9'd16),
        .accepted(accepted),.out_valid(valid),.out_sample(pcm),.deadline_missed(deadline),.clipped(clip));
    reg strike=0;reg [3:0] pad=0;wire drum_ready,drum_valid;wire signed [19:0] drum_pcm;
    looper_drum_engine drum(.clk(clk),.rst(rst),.sample_ce(ce),.strike_valid(strike),.strike_ready(drum_ready),
        .strike_pad(pad),.strike_velocity(8'd220),.strike_track(3'd4),.strike_layer(2'd0),
        .track_gains({4{17'd65536}}),.flush_all(1'b0),.flush_valid(1'b0),.flush_track(2'd0),.flush_layer(2'd0),.flush_whole_track(1'b0),
        .sample_valid(drum_valid),.sample(drum_pcm));
    reg met_run=0;wire beat;wire [2:0] beat_index;wire click_valid;wire signed [15:0] click_pcm;
    looper_clock clock_i(.clk(clk),.rst(rst),.sample_ce(ce),.run(met_run),.restart(1'b0),.bpm(8'd120),
        .beats_per_bar(3'd4),.beat_pulse(beat),.beat_in_bar(beat_index));
    metronome_click click_i(.clk(clk),.rst(rst),.sample_ce(ce),.trigger(beat),.accent(beat_index==0),
        .enable(met_run),.gain_q8(9'd96),.valid(click_valid),.sample(click_pcm));
    always @(posedge clk) begin
        if(!rst && ce) frames=frames+1;
        #1;
        if(!rst && file_id!=0) begin
            if(kind==0 && valid) $fdisplay(file_id,"%0d",pcm);
            if(kind==1 && drum_valid) $fdisplay(file_id,"%0d",drum_pcm>>>4);
            if(kind==2 && click_valid) $fdisplay(file_id,"%0d",click_pcm);
            if(deadline || clip) $fatal(1,"preview render fault");
        end
    end
    task reset_sources;
        begin @(negedge clk);rst=1;ev=0;strike=0;met_run=0;frames=0;
            repeat(4) @(negedge clk);rst=0;end
    endtask
    task command;
        input isoff;
        begin @(negedge clk);#2;while(!ready) begin @(negedge clk);#2;end
            off=isoff;ev=1;@(negedge clk);#2;ev=0;wait(accepted);@(negedge clk);end
    endtask
    task audition;
        input [2:0] p;input [511:0] filename;
        begin reset_sources();preset=p;kind=0;file_id=$fopen(filename,"w");command(0);
            wait(frames>=19231);command(1);wait(frames>=48077);$fclose(file_id);file_id=0;end
    endtask
    integer i,target;
    initial begin
        audition(0,"audio/piano.txt");audition(2,"audio/warm_pluck.txt");
        audition(3,"audio/bell.txt");audition(4,"audio/drive_lead.txt");audition(5,"audio/custom.txt");
        reset_sources();kind=1;file_id=$fopen("audio/drum_kit.txt","w");
        for(i=0;i<16;i=i+1) begin
            @(negedge clk);pad=i;strike=1;wait(drum_ready);@(posedge clk);#2;strike=0;
            target=frames+19231;wait(frames>=target);
        end
        $fclose(file_id);file_id=0;reset_sources();kind=2;file_id=$fopen("audio/metronome120.txt","w");
        met_run=1;wait(frames>=96154);$fclose(file_id);file_id=0;
        $display("LOOPER_PREVIEW_TB_PASS five_presets drum16 metronome120 dry_pre_master accelerated_CE64");$finish;
    end
    initial begin #3.0e9;$fatal(1,"preview watchdog");end
endmodule

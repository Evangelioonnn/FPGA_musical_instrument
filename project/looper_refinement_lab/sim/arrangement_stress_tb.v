`timescale 1ns/1ps
module arrangement_stress_tb;
    reg clk=0;always #10 clk=~clk;
    reg rst=1;integer divider=0,frames=0,cycle=0,max_render=0,pcm_count=0;
    wire sample_ce=divider==1039;
    always @(negedge clk) if(rst) divider=0;else divider=(divider+1)%1040;
    reg flush=0;reg [67:0] gains={4{17'd65536}};
    reg strike=0,click_trigger=0;reg [3:0] pad=0;
    wire drum_ready,drum_valid;wire signed [19:0] drum_sample;
    reg signed [15:0] drum_hold=0;wire [31:0] drum_late,drum_rejected;
    looper_drum_engine drum(.clk(clk),.rst(rst),.sample_ce(sample_ce),.strike_valid(strike),.strike_ready(drum_ready),
        .strike_pad(pad),.strike_velocity(8'd255),.strike_track(3'd4),.strike_layer(2'd0),.track_gains(gains),
        .flush_all(flush),.flush_valid(1'b0),.flush_track(2'd0),.flush_layer(2'd0),.flush_whole_track(1'b0),
        .sample_valid(drum_valid),.sample(drum_sample),.late_strikes(drum_late),.rejected_strikes(drum_rejected));
    always @(posedge clk) if(rst) drum_hold<=0;else if(drum_valid) drum_hold<=drum_sample>>>4;
    wire signed [15:0] click_sample;wire [31:0] clicks;
    metronome_click click_i(.clk(clk),.rst(rst),.sample_ce(sample_ce),.trigger(click_trigger),.accent(1'b1),
        .enable(1'b1),.gain_q8(9'd256),.sample(click_sample),.delivered(clicks));
    wire signed [15:0] aux=drum_hold+click_sample;
    reg loop_valid=0,loop_off=0;reg [6:0] pitch=60;reg [1:0] track=0,layer=0;wire loop_ready;reg [15:0] local_id=0;reg [135:0] patch=0;
    reg host_valid=0;wire host_ready;reg [4:0] addr=1;reg [31:0] value=65536;
    wire final_valid,deadline;wire signed [15:0] left,right;wire [31:0] occupied,route_faults;
    looper_audio_core #(.N(32),.PLUCK_N(12),.WITH_FX(1)) audio(
        .clk(clk),.rst(rst),.sample_ce(sample_ce),.keys(16'd0),.changed(1'b0),.ghost(1'b0),.all_released(1'b1),
        .button_n(3'b111),.step_valid(1'b0),.step(2'sd0),.recording(1'b0),.capture_recording(1'b0),
        .current_loop_tick(12'd0),.record_ready(1'b1),.drum_mode(1'b0),.auxiliary_sample(aux),
        .flush_all(flush),.flush_valid(1'b0),.flush_whole_track(1'b0),.flush_track(2'd0),.flush_layer(2'd0),
        .loop_event_valid(loop_valid),.loop_event_ready(loop_ready),.loop_event_off(loop_off),.loop_event_drum(1'b0),
        .loop_event_track(track),.loop_event_layer(layer),.loop_event_id(local_id),.loop_event_tick(12'd0),
        .loop_event_note(pitch),.loop_event_velocity(8'd255),.loop_event_preset(patch[2:0]),.loop_event_patch(patch),
        .track_gains(gains),.drum_event_ready(1'b1),.drum_event_accepted(1'b1),.loop_route_faults(route_faults),
        .host_valid(host_valid),.host_ready(host_ready),.host_addr(addr),.host_value(value),
        .adc_valid(1'b0),.adc_ch0(12'd0),.adc_ch1(12'd0),.adc_ch2(12'd0),.adc_ch3(12'd0),.adc_ch4(12'd0),
        .final_valid(final_valid),.final_left(left),.final_right(right),.deadline_missed(deadline),.occupied(occupied));
    integer i,magnitude,peak=0;
    always @(posedge clk) begin
        if(!rst) begin if(sample_ce) begin frames=frames+1;cycle=0;end else cycle=cycle+1;
            #1;
            if(final_valid) begin
                if((^left)===1'bx || (^right)===1'bx) $fatal(1,"full-load unknown PCM");
                pcm_count=pcm_count+1;if(cycle>max_render) max_render=cycle;
                magnitude=left<0 ? -left : left;if(magnitude>peak) peak=magnitude;
                if(magnitude>28416) $fatal(1,"final headroom bound");
            end
            if(deadline || drum_late!=0 || drum_rejected!=0 || route_faults!=0) $fatal(1,"full-load scheduling/rejection fault");
        end
    end
    task parameter_write;
        input [4:0] a;input [31:0] v;
        begin @(negedge clk);addr=a;value=v;host_valid=1;wait(host_ready);@(posedge clk);#2;host_valid=0;end
    endtask
    initial begin
        patch[2:0]=5;patch[11:3]=256;patch[23:15]=64;patch[35:27]=32;patch[47:39]=16;
        patch[66:51]=65535;patch[98:83]=65535;patch[114:99]=3;patch[117:115]=5;patch[119:118]=2;patch[123]=1;patch[124]=1;
        repeat(4) @(negedge clk);rst=0;parameter_write(1,65536);parameter_write(18,1);
        for(i=0;i<32;i=i+1) begin
            @(negedge clk);loop_valid=1;local_id=i+1;track=i%4;layer=(i/4)%4;pitch=36+i;
            patch[2:0]=i<4 ? 2 : i%4==0 ? 0 : i%4==1 ? 3 : i%4==2 ? 4 : 5;wait(loop_ready);@(posedge clk);#2;loop_valid=0;
            wait(audio.event_router.state==0);
        end
        if(occupied!=32'hffffffff) $fatal(1,"full-load missing 32 melodic slots");
        wait(frames>=700);
        for(i=0;i<8;i=i+1) begin
            @(negedge clk);pad=i;strike=1;wait(drum_ready);@(posedge clk);#2;strike=0;
        end
        @(negedge clk);click_trigger=1;@(negedge clk);click_trigger=0;
        wait(frames>=1000);
        // Monotonic track mute ramp; never scales voices by active count.
        for(i=0;i<512;i=i+1) begin wait(sample_ce);@(posedge clk);#2;gains[0+:17]=gains[0+:17]-17'd128;@(negedge clk);end
        if(gains[0+:17]!=0) $fatal(1,"mixer ramp endpoint");
        @(negedge clk);flush=1;@(negedge clk);flush=0;
        wait(!audio.event_router.flushing);wait(frames>=1800);
        if(audio.event_router.map_valid!=0 || audio.held!=0 || audio.bank_clip) $fatal(1,"arrangement stop left held instances/clip");
        if(clicks!=1 || audio.room.effect.wet_applied==0 || pcm_count<1100 || peak==0) $fatal(1,"full-load sources/effect not active");
        $display("ARRANGEMENT_STRESS_TB_PASS five_presets mixed32 pitches36_to67 tracks4_layers4 drum8 click FX smooth_mute stop_clean melody32 drum8 click FX master_unity final_peak=%0d max_render=%0d cadence=1040",peak,max_render);$finish;
    end
    initial begin #100000000;$fatal(1,"full-load watchdog");end
endmodule

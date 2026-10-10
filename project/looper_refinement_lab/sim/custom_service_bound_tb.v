`timescale 1ns/1ps
module custom_service_bound_tb;
    reg clk=0;always #10 clk=~clk;
    reg rst=1;integer divider=0,frames=0,cycle=0,max_render=0,pcm_count=0;
    wire sample_ce=divider==1039;
    always @(negedge clk) if(rst) divider=0;else divider=(divider+1)%1040;
    reg strike=0,click_trigger=0;reg [3:0] pad=0;
    wire drum_ready,drum_valid;wire signed [19:0] drum_sample;
    reg signed [15:0] drum_hold=0;wire [31:0] drum_late,drum_rejected;
    looper_drum_engine drum(.clk(clk),.rst(rst),.sample_ce(sample_ce),.strike_valid(strike),.strike_ready(drum_ready),
        .strike_pad(pad),.strike_velocity(8'd255),.strike_track(3'd4),.strike_layer(2'd0),.track_gains({4{17'd65536}}),
        .flush_all(1'b0),.flush_valid(1'b0),.flush_track(2'd0),.flush_layer(2'd0),.flush_whole_track(1'b0),
        .sample_valid(drum_valid),.sample(drum_sample),.late_strikes(drum_late),.rejected_strikes(drum_rejected));
    always @(posedge clk) if(rst) drum_hold<=0;else if(drum_valid) drum_hold<=drum_sample>>>4;
    wire signed [15:0] click_sample;wire [31:0] clicks;
    metronome_click click_i(.clk(clk),.rst(rst),.sample_ce(sample_ce),.trigger(click_trigger),.accent(1'b1),
        .enable(1'b1),.gain_q8(9'd256),.sample(click_sample),.delivered(clicks));
    wire signed [15:0] aux=drum_hold+click_sample;
    reg loop_valid=0;wire loop_ready;reg [15:0] local_id=0;reg [135:0] patch=0;
    reg host_valid=0;wire host_ready;reg [4:0] addr=1;reg [31:0] value=65536;
    wire final_valid,deadline;wire signed [15:0] left,right;wire [31:0] occupied,route_faults;
    reg sv=0;wire sr,av,ar;reg [59:0] sd=0;wire [59:0] ad;wire [47:0] targets;wire [135:0] current_patch;
    fader_mode_adapter faders(.clk(clk),.rst(rst),.mix_mode(1'b0),.scan_valid(sv),.scan_ready(sr),.scan_data(sd),
        .harmonic_targets(targets),.mixer_targets({4{17'd65536}}),.invalidate(4'd0),
        .adc_valid(av),.adc_ready(ar),.adc_data(ad),.mixer_ready(1'b1));
    looper_audio_core #(.N(32),.PLUCK_N(1),.WITH_FX(1)) audio(
        .clk(clk),.rst(rst),.sample_ce(sample_ce),.keys(16'd0),.changed(1'b0),.ghost(1'b0),.all_released(1'b1),
        .button_n(3'b111),.step_valid(1'b0),.step(2'sd0),.recording(1'b0),.capture_recording(1'b0),
        .current_loop_tick(12'd0),.record_ready(1'b1),.drum_mode(1'b0),.auxiliary_sample(aux),
        .flush_all(1'b0),.flush_valid(1'b0),.flush_whole_track(1'b0),.flush_track(2'd0),.flush_layer(2'd0),
        .loop_event_valid(loop_valid),.loop_event_ready(loop_ready),.loop_event_off(1'b0),.loop_event_drum(1'b0),
        .loop_event_track(2'd0),.loop_event_layer(2'd0),.loop_event_id(local_id),.loop_event_tick(12'd0),
        .loop_event_note(7'd60),.loop_event_velocity(8'd255),.loop_event_preset(3'd5),.loop_event_patch(current_patch),
        .track_gains({4{17'd65536}}),.drum_event_ready(1'b1),.drum_event_accepted(1'b1),.loop_route_faults(route_faults),
        .host_valid(host_valid),.host_ready(host_ready),.host_addr(addr),.host_value(value),
        .adc_valid(av),.adc_ready(ar),.adc_ch0(ad[11:0]),.adc_ch1(ad[23:12]),.adc_ch2(ad[35:24]),.adc_ch3(ad[47:36]),.adc_ch4(ad[59:48]),
        .harmonic_targets(targets),.record_patch_current(current_patch),
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
            if(audio.coeff0+audio.coeff1+audio.coeff2+audio.coeff3>368 || audio.bank_clip) $fatal(1,"protected coefficient sum/clip");
            if(deadline || drum_late!=0 || drum_rejected!=0 || route_faults!=0) $fatal(1,"full-load scheduling/rejection fault");
        end
    end
    task parameter_write;
        input [4:0] a;input [31:0] v;
        begin @(negedge clk);addr=a;value=v;host_valid=1;wait(host_ready);@(posedge clk);#2;host_valid=0;end
    endtask
    task scan;input [11:0] raw;begin @(negedge clk);sd={5{raw}};sv=1;#2;
        while(!sr) begin @(negedge clk);#2;end @(posedge clk);#2;sv=0;repeat(1040*4) @(negedge clk);end endtask
    initial begin
        patch[2:0]=5;patch[11:3]=256;patch[23:15]=64;patch[35:27]=32;patch[47:39]=16;
        patch[66:51]=65535;patch[98:83]=65535;patch[114:99]=3;patch[117:115]=5;patch[119:118]=2;patch[123]=1;patch[124]=1;
        repeat(4) @(negedge clk);rst=0;parameter_write(0,5);parameter_write(1,65536);parameter_write(18,1);
        parameter_write(11,65535);parameter_write(12,1);parameter_write(13,65535);parameter_write(15,1);
        scan(0);scan(4095);wait(frames>=600);
        if(audio.coeff0!=92 || audio.coeff1!=92 || audio.coeff2!=92 || audio.coeff3!=92 || audio.master_target!=65536)
            $fatal(1,"four actual faders normalization coeff %d/%d/%d/%d",audio.coeff0,audio.coeff1,audio.coeff2,audio.coeff3);
        for(i=0;i<32;i=i+1) begin
            @(negedge clk);loop_valid=1;local_id=i+1;wait(loop_ready);@(posedge clk);#2;loop_valid=0;
            wait(audio.event_router.state==0);
        end
        if(occupied!=32'hffffffff) $fatal(1,"full-load missing 32 melodic slots");
        wait(frames>=900);
        for(i=0;i<8;i=i+1) begin
            @(negedge clk);pad=i;strike=1;wait(drum_ready);@(posedge clk);#2;strike=0;
        end
        @(negedge clk);click_trigger=1;@(negedge clk);click_trigger=0;
        wait(frames>=1500);
        if(clicks!=1 || audio.room.effect.wet_applied==0 || pcm_count<1100 || peak==0) $fatal(1,"full-load sources/effect not active");
        $display("CUSTOM_SERVICE_BOUND_TB_PASS actual_faders4_normalized92 sum368 melody32 drum8 click FX master_unity final_peak=%0d max_render=%0d cadence=1040",peak,max_render);$finish;
    end
    initial begin #100000000;$fatal(1,"full-load watchdog");end
endmodule

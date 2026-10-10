`timescale 1ns/1ps
module arrangement_preview_tb;
    reg clk=0;always #10 clk=~clk;
    reg rst=1;integer divider=0,frames=0,cycle=0,max_render=0,pcm_count=0;
    // Offline acceleration only; pitch/envelope constants still use 50M/1040.
    wire sample_ce=divider==255;
    always @(negedge clk) if(rst) divider=0;else divider=(divider+1)%256;
    reg [67:0] gains={4{17'd65536}};reg [1:0] track=0,layer=0;
    reg strike=0,click_trigger=0;reg [3:0] pad=0;
    wire drum_ready,drum_valid;wire signed [19:0] drum_sample;
    reg signed [15:0] drum_hold=0;wire [31:0] drum_late,drum_rejected;
    looper_drum_engine drum(.clk(clk),.rst(rst),.sample_ce(sample_ce),.strike_valid(strike),.strike_ready(drum_ready),
        .strike_pad(pad),.strike_velocity(8'd255),.strike_track(3'd4),.strike_layer(2'd0),.track_gains(gains),
        .flush_all(1'b0),.flush_valid(1'b0),.flush_track(2'd0),.flush_layer(2'd0),.flush_whole_track(1'b0),
        .sample_valid(drum_valid),.sample(drum_sample),.late_strikes(drum_late),.rejected_strikes(drum_rejected));
    always @(posedge clk) if(rst) drum_hold<=0;else if(drum_valid) drum_hold<=drum_sample>>>4;
    wire signed [15:0] click_sample;wire [31:0] clicks;
    metronome_click click_i(.clk(clk),.rst(rst),.sample_ce(sample_ce),.trigger(click_trigger),.accent(1'b1),
        .enable(1'b1),.gain_q8(9'd256),.sample(click_sample),.delivered(clicks));
    wire signed [15:0] aux=drum_hold+click_sample;
    reg loop_valid=0,loop_off=0,control=0;reg [6:0] pitch=60;reg [7:0] velocity=220;wire loop_ready;reg [15:0] local_id=0;reg [135:0] patch=0;
    reg host_valid=0;wire host_ready;reg [4:0] addr=1;reg [31:0] value=65536;
    wire final_valid,deadline;wire signed [15:0] left,right;wire [31:0] occupied,route_faults;
    looper_audio_core #(.N(8),.PLUCK_N(4),.WITH_FX(1),.WITH_EXPRESSION(1)) audio(
        .clk(clk),.rst(rst),.sample_ce(sample_ce),.keys(16'd0),.changed(1'b0),.ghost(1'b0),.all_released(1'b1),
        .button_n(3'b111),.step_valid(1'b0),.step(2'sd0),.recording(1'b0),.capture_recording(1'b0),
        .current_loop_tick(12'd0),.record_ready(1'b1),.drum_mode(1'b0),.auxiliary_sample(aux),
        .flush_all(1'b0),.flush_valid(1'b0),.flush_whole_track(1'b0),.flush_track(2'd0),.flush_layer(2'd0),
        .loop_event_valid(loop_valid),.loop_event_ready(loop_ready),.loop_event_off(loop_off),.loop_event_drum(1'b0),
        .loop_event_track(track),.loop_event_layer(layer),.loop_event_id(local_id),.loop_event_tick(12'd0),
        .loop_event_note(pitch),.loop_event_velocity(velocity),.loop_event_control(control),.loop_event_preset(patch[2:0]),.loop_event_patch(patch),
        .track_gains(gains),.drum_event_ready(1'b1),.drum_event_accepted(1'b1),.loop_route_faults(route_faults),
        .host_valid(host_valid),.host_ready(host_ready),.host_addr(addr),.host_value(value),
        .adc_valid(1'b0),.adc_ch0(12'd0),.adc_ch1(12'd0),.adc_ch2(12'd0),.adc_ch3(12'd0),.adc_ch4(12'd0),
        .final_valid(final_valid),.final_left(left),.final_right(right),.deadline_missed(deadline),.occupied(occupied));
    integer fd=0;
    integer i,magnitude,peak=0;
    always @(posedge clk) begin
        if(!rst) begin if(sample_ce) begin frames=frames+1;cycle=0;
            if(frames%16000==0) $display("ARRANGEMENT_PROGRESS frames=%0d",frames);
        end else cycle=cycle+1;
            #1;
            if(final_valid) begin
                if((^left)===1'bx || (^right)===1'bx) $fatal(1,"full-load unknown PCM");
                pcm_count=pcm_count+1;if(fd) $fdisplay(fd,"%0d %0d",left,right);if(cycle>max_render) max_render=cycle;
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
    task event_note;input [15:0] id;input stop;input [6:0] n;input [2:0] pr;input [1:0] tr;
        begin @(negedge clk);local_id=id;loop_off=stop;pitch=n;patch[2:0]=pr;track=tr;control=0;velocity=220;loop_valid=1;#2;
        while(!loop_ready) begin @(negedge clk);#2;end @(posedge clk);#2;loop_valid=0;wait(audio.event_router.state==0);end endtask
    task expression;input [1:0] kind;input [16:0] v;
        begin @(negedge clk);local_id=v[15:0];velocity={7'd0,v[16]};pitch=kind;track=0;loop_off=0;control=1;loop_valid=1;#2;
        while(!loop_ready) begin @(negedge clk);#2;end @(posedge clk);#2;loop_valid=0;wait(audio.event_router.state==0);control=0;end endtask
    task hit;input [3:0] p;
        begin @(negedge clk);pad=p;strike=1;#2;while(!drum_ready) begin @(negedge clk);#2;end
            @(posedge clk);#2;strike=0;end endtask
    initial begin
        patch[2:0]=0;patch[11:3]=256;patch[23:15]=64;patch[35:27]=32;patch[47:39]=16;
        patch[66:51]=68;patch[82:67]=6;patch[98:83]=32768;patch[114:99]=3;patch[117:115]=5;patch[119:118]=2;patch[123]=0;patch[124]=1;
        repeat(4) @(negedge clk);rst=0;parameter_write(1,65536);wait(frames>=600);
        fd=$fopen("audio/arrangement.txt","w");if(!fd) $fatal(1,"audio path unavailable");
        event_note(1,0,60,0,0);event_note(2,0,64,0,0);hit(0);click_trigger=1;@(negedge clk);click_trigger=0;
        wait(frames>=9600);expression(0,1);event_note(1,1,60,0,0);event_note(2,1,64,0,0);
        event_note(1,0,48,2,1);hit(5);
        wait(frames>=19200);expression(2,67456);event_note(1,0,76,3,2);hit(1);
        wait(frames>=28800);expression(0,0);event_note(1,0,67,4,3);hit(6);
        wait(frames>=38400);event_note(1,1,76,3,2);hit(5);
        for(i=0;i<512;i=i+1) begin wait(sample_ce);@(posedge clk);#2;gains[0+:17]=gains[0+:17]-17'd128;@(negedge clk);end
        wait(frames>=48000);patch[122:120]=3;event_note(2,0,72,4,3);event_note(1,1,67,4,3);hit(0);
        wait(frames>=57600);event_note(2,1,72,4,3);event_note(3,0,55,5,3);hit(10);
        wait(frames>=72000);event_note(3,1,55,5,3);hit(7);wait(frames>=96000);
        $fclose(fd);fd=0;
        $display("ARRANGEMENT_PREVIEW_TB_PASS actual_core FX five_presets layers_drums pedal_bend track_ramp glide N8_P4 offline_CE256 peak=%0d max_render=%0d",peak,max_render);$finish;
    end
    initial begin #1200000000;$fatal(1,"full-load watchdog");end
endmodule

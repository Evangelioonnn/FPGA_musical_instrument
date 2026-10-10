`timescale 1ns/1ps
module record_merge_tb;
    reg clk=0;always #10 clk=~clk;
    reg rst=1;integer divider=0,frames=0,nonzero=0;
    wire sample_ce=divider==1039;
    always @(negedge clk) if(rst) divider=0;else divider=(divider+1)%1040;
    reg strike_valid=0,trigger=0;wire strike_ready;wire drum_valid;
    wire signed [19:0] drum_sample;reg signed [15:0] drum_hold=0;
    wire click_valid,onset;wire signed [15:0] click_sample;wire [31:0] delivered;
    looper_drum_engine drum(.clk(clk),.rst(rst),.sample_ce(sample_ce),.strike_valid(strike_valid),
        .strike_ready(strike_ready),.strike_pad(4'd0),.strike_velocity(8'd255),.strike_track(3'd4),.strike_layer(2'd0),
        .track_gains({4{17'd65536}}),.flush_all(1'b0),.flush_valid(1'b0),.flush_track(2'd0),.flush_layer(2'd0),.flush_whole_track(1'b0),
        .sample_valid(drum_valid),.sample(drum_sample));
    metronome_click click_i(.clk(clk),.rst(rst),.sample_ce(sample_ce),.trigger(trigger),.accent(1'b1),
        .enable(1'b1),.gain_q8(9'd256),.valid(click_valid),.sample(click_sample),.onset(onset),.delivered(delivered));
    always @(posedge clk) if(rst) drum_hold<=0;else if(drum_valid) drum_hold<=drum_sample>>>4;
    wire signed [15:0] aux=drum_hold+click_sample;
    reg record_ready=0;reg host_valid=0;wire host_ready,final_valid;wire signed [15:0] final_left,final_right;
    wire record_event_valid,deadline_missed;reg checking_mute=0;
    looper_audio_core #(.N(1),.PLUCK_N(1),.WITH_FX(0),.WITH_EXPRESSION(1)) audio(
        .clk(clk),.rst(rst),.sample_ce(sample_ce),.keys(16'd0),.changed(1'b0),.ghost(1'b0),.all_released(1'b1),
        .button_n(3'b111),.step_valid(1'b0),.step(2'sd0),.recording(1'b1),.capture_recording(1'b0),
        .current_loop_tick(12'd0),.record_ready(record_ready),.drum_mode(1'b0),.auxiliary_sample(aux),
        .flush_all(1'b0),.flush_valid(1'b0),.flush_whole_track(1'b0),.flush_track(2'd0),.flush_layer(2'd0),
        .loop_event_valid(1'b0),.loop_event_off(1'b0),.loop_event_drum(1'b0),.loop_event_track(2'd0),.loop_event_layer(2'd0),
        .loop_event_id(16'd0),.loop_event_tick(12'd0),.loop_event_note(7'd0),.loop_event_velocity(8'd0),.loop_event_preset(3'd0),.loop_event_patch(136'd0),
        .track_gains({4{17'd65536}}),.record_event_valid(record_event_valid),.drum_event_ready(1'b1),
        .host_valid(host_valid),.host_ready(host_ready),.host_addr(5'd1),.host_value(32'd0),
        .adc_valid(1'b0),.adc_ch0(12'd0),.adc_ch1(12'd0),.adc_ch2(12'd0),.adc_ch3(12'd0),.adc_ch4(12'd0),
        .final_valid(final_valid),.final_left(final_left),.final_right(final_right),.deadline_missed(deadline_missed));
    integer hits=0;
    always @(posedge clk) if(!rst) begin
        if(sample_ce) frames=frames+1;
        if(strike_valid && strike_ready) hits=hits+1;
        #1;
        if(deadline_missed) $fatal(1,"auxiliary was recorded or missed deadline");
        if(final_valid) begin
            if((^final_left)===1'bx) $fatal(1,"unknown final PCM");
            if(final_left!=0) nonzero=nonzero+1;
            if(checking_mute && (final_left!=0 || final_right!=0)) $fatal(1,"master mute does not cover drum/click");
        end
    end
    task collision;
        begin
            wait(sample_ce);@(posedge clk);#2;@(negedge clk);strike_valid=1;trigger=1;
            @(negedge clk);trigger=0;
            wait(strike_ready);@(posedge clk);#2;strike_valid=0;
        end
    endtask
    reg [44:0] held_event;integer merged=0;
    always @(posedge clk) if(!rst && record_event_valid && record_ready) begin
        if(merged==0 && (audio.record_event_tick!=10 || audio.record_event_kind!=0 || audio.record_event_id!=7)) $fatal(1,"earlier note was blocked/reordered");
        if(merged==1 && (audio.record_event_tick!=20 || audio.record_event_kind!=3 || audio.record_event_note!=2 || audio.record_event_id!=8026 || audio.record_event_velocity!=1)) $fatal(1,"later expression was lost/reordered");
        merged=merged+1;
    end
    initial begin
        repeat(4) @(negedge clk);rst=0;
        force audio.record_pending=1;force audio.pending_tick=10;force audio.pending_kind=0;
        force audio.pending_note=60;force audio.pending_id=7;force audio.pending_velocity=255;
        force audio.capture_expression_valid=1;force audio.capture_expression_busy=1;
        force audio.capture_expression_tick=20;force audio.capture_expression_kind=2;force audio.capture_expression_value=73562;
        wait(record_event_valid);@(negedge clk);release audio.record_pending;audio.record_pending=0;
        held_event=audio.merged_event;repeat(20) begin @(negedge clk);if(!record_event_valid || audio.merged_event!==held_event) $fatal(1,"merged event changed on backpressure");end
        record_ready=1;wait(merged==1);@(negedge clk);
        wait(audio.capture_expression_ready);@(posedge clk);#2;force audio.capture_expression_valid=0;force audio.capture_expression_busy=0;
        wait(merged==2);repeat(5) @(negedge clk);if(record_event_valid) $fatal(1,"duplicate merged record");
        $display("RECORD_MERGE_TB_PASS earlier_note_than_queued_expression timestamp_order stable_payload no_deadlock no_duplicate");$finish;
    end
    initial begin #100000000;$fatal(1,"mix watchdog");end
endmodule

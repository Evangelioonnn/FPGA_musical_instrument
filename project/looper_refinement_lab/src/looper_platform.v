module looper_platform #(
    parameter ROW_CYCLES = 2500,
    parameter DEBOUNCE_FRAMES = 8,
    parameter BUTTON_CYCLES = 150000,
    parameter AUDIO_N = 32,
    parameter PLUCK_N = 12,
    parameter LONG_CYCLES = 50000000,
    parameter ENCODER_CYCLES = 2500
)(
    input wire sys_clk,input wire reset_request,output wire reset_active,
    input wire enc_a,
    input wire enc_b,
    input wire [2:0] button_n,
    input wire [3:0] matrix_col_n,
    output wire [3:0] matrix_row_n,
    output wire hp_bck,
    output wire hp_ws,
    output wire hp_din,
    output wire pa_en,
    output wire status_led,
    input wire adc_valid,output wire adc_ready,input wire [59:0] adc_data,
    input wire mixer_valid,output wire mixer_ready,input wire [67:0] mixer_data,
    input wire remote_valid,output wire remote_ready,input wire [4:0] remote_addr,input wire [31:0] remote_value,
    output wire remote_ack_valid,remote_ack_accepted,remote_ack_applied,
    output wire [4:0] remote_ack_addr,output wire [31:0] remote_ack_value,
    output wire snapshot_valid,output wire [320+AUDIO_N*64+512-1:0] snapshot_data,
    output wire [255:0] snapshot_extension,output wire [15:0] snapshot_keys,
    output wire [127:0] capabilities,
    output wire pcm_valid,output wire signed [15:0] pcm_left,pcm_right,output wire [31:0] pcm_index,
    output wire mix_mode,output wire [47:0] harmonic_targets,output wire [67:0] mixer_targets,
    output wire [3:0] fader_invalidate
);
    wire [4:0] host_addr;wire [31:0] host_value;
    wire [3:0] mixer_local_invalidate;
    localparam AUDIO_W=320+AUDIO_N*64;
    wire audio_snapshot_valid;wire [AUDIO_W-1:0] audio_snapshot;
    wire [127:0] audio_capabilities;wire [AUDIO_N*5-1:0] voice_origins;
    wire fault;
    reg [5:0] startup = 0;
    wire rst = !startup[5] || reset_request;
    assign reset_active=rst;
    always @(posedge sys_clk) begin
        if(reset_request) startup<=0;
        else if(!startup[5]) startup<=startup+1'b1;
    end

    wire [3:0] row_low;
    genvar r;
    generate for (r = 0; r < 4; r = r + 1) begin: rows
        assign matrix_row_n[r] = row_low[r] ? 1'b0 : 1'bz;
    end endgenerate

    wire [15:0] keys;
    wire changed, frame_valid, ghost, all_released;
    matrix_scanner #(.ROW_CYCLES(ROW_CYCLES), .DEBOUNCE_FRAMES(DEBOUNCE_FRAMES)) scanner(
        .clk(sys_clk), .rst(rst), .col_n(matrix_col_n), .row_low(row_low),
        .keys(keys), .changed(changed), .frame_valid(frame_valid), .ghost(ghost),
        .all_released(all_released));

    wire enc_step_valid, enc_pressed, enc_changed, enc_invalid;
    wire signed [1:0] enc_step;
    ec11_input #(.SAMPLE_CYCLES(ENCODER_CYCLES), .AB_SAMPLES(2)) encoder(
        .clk(sys_clk), .rst(rst), .a(enc_a), .b(enc_b), .button_n(1'b1),
        .step_valid(enc_step_valid), .step(enc_step), .pressed(enc_pressed),
        .button_changed(enc_changed), .invalid_transition(enc_invalid));

    wire [2:0] btn_down, btn_press, btn_release;
    genvar b;
    generate for (b = 0; b < 3; b = b + 1) begin: buttons
        playable_button #(.DEBOUNCE_CYCLES(BUTTON_CYCLES)) button_filter(
            .clk(sys_clk), .rst(rst), .button_n(button_n[b]),
            .down(btn_down[b]), .pressed(btn_press[b]), .released(btn_release[b]));
    end endgenerate

    wire tx_sample_ce;
    wire signed [15:0] audio_left,audio_right;
    output_tx tx(.clk(sys_clk),.rst(rst),.sample_left(audio_left),.sample_right(audio_right),
        .sample_ce(tx_sample_ce),.hp_bck(hp_bck),.hp_ws(hp_ws),.hp_din(hp_din));
    wire transport_run,count_in,playing,transport_recording,record_armed;
    wire record_start_pulse,record_done_pulse,loop_wrap_pulse,stop_pulse;
    wire [11:0] loop_tick;
    wire [31:0] loop_number;
    wire tick_pulse,beat_pulse,bar_pulse;
    wire [6:0] tick_in_beat;wire [2:0] beat_in_bar;
    wire [31:0] frame_index;wire [7:0] applied_bpm;
    wire [2:0] selected_preset,page,mode;
    wire [1:0] selected_track,quantize;
    wire start_req,stop_req,record_req,undo_req,clear_req;
    wire met_enable;wire [7:0] bpm;wire [2:0] meter,bars;
    wire [8:0] click_gain;wire [3:0] muted;wire [67:0] track_gains;
    wire host_valid,host_ready,control_overflow;
    wire backend_valid,backend_ready,backend_ack_valid,backend_ack_source,backend_ack_accepted,backend_ack_applied;
    wire [4:0] backend_addr,backend_ack_addr;wire [31:0] backend_value,backend_ack_value;
    wire arbiter_fault;
    refinement_config_arbiter config_arbiter(.clk(sys_clk),.rst(rst),
        .local_valid(host_valid),.local_ready(host_ready),.local_addr(host_addr),.local_value(host_value),
        .remote_valid(remote_valid),.remote_ready(remote_ready),.remote_addr(remote_addr),.remote_value(remote_value),
        .backend_valid(backend_valid),.backend_ready(backend_ready),.backend_addr(backend_addr),.backend_value(backend_value),
        .ack_valid(backend_ack_valid && backend_ack_source),.ack_addr(backend_ack_addr),.ack_value(backend_ack_value),
        .ack_accepted(backend_ack_accepted),.ack_applied(backend_ack_applied),
        .remote_ack_valid(remote_ack_valid),.remote_ack_addr(remote_ack_addr),.remote_ack_value(remote_ack_value),
        .remote_ack_accepted(remote_ack_accepted),.remote_ack_applied(remote_ack_applied),.protocol_error(arbiter_fault));
    assign mix_mode=page==2;
    wire [15:0] layer_valid;
    looper_controls #(.LONG_CYCLES(LONG_CYCLES)) controls(
        .clk(sys_clk),.rst(rst),.sample_ce(tx_sample_ce),.down(btn_down),.released(btn_release),
        .step_valid(enc_step_valid),.step(enc_step),.transport_run(transport_run),
        .host_ready(host_ready),.has_layers(|layer_valid),.host_valid(host_valid),.host_addr(host_addr),.host_value(host_value),
        .preset(selected_preset),.page(page),.mode(mode),.track(selected_track),
        .start_req(start_req),.stop_req(stop_req),.record_req(record_req),.undo_req(undo_req),.clear_req(clear_req),
        .met_enable(met_enable),.bpm(bpm),.meter(meter),.bars(bars),.click_gain(click_gain),
        .quantize(quantize),.track_gains(track_gains),.muted(muted),.overflow(control_overflow),
        .sync_valid(backend_ack_valid&&backend_ack_source&&backend_ack_accepted&&backend_ack_applied),
        .sync_remote(remote_ack_valid),.sync_addr(backend_ack_addr),.sync_value(backend_ack_value),
        .mixer_valid(mixer_valid),.mixer_ready(mixer_ready),.mixer_data(mixer_data),
        .mixer_targets(mixer_targets),.mixer_invalidate(mixer_local_invalidate));
    assign fader_invalidate=mixer_local_invalidate |
        ((backend_ack_valid && backend_ack_source && backend_ack_accepted && backend_ack_applied) ?
            (backend_ack_addr>=20 && backend_ack_addr<=23 ? (4'b0001<<(backend_ack_addr-20)) :
             backend_ack_addr==31 ? 4'b1111 : 4'b0000) : 4'b0000);
    looper_clock looper_clock_i(
        .clk(sys_clk),.rst(rst),.sample_ce(tx_sample_ce),.run(transport_run||met_enable),.restart(start_req),
        .bpm(bpm),.beats_per_bar(meter),.tick_pulse(tick_pulse),.beat_pulse(beat_pulse),.bar_pulse(bar_pulse),
        .tick_in_beat(tick_in_beat),.beat_in_bar(beat_in_bar),.frame_index(frame_index),.applied_bpm(applied_bpm));
    looper_transport transport_i(
        .clk(sys_clk),.rst(rst),.tick_pulse(tick_pulse),.beat_pulse(beat_pulse),.bar_pulse(bar_pulse),
        .tick_in_beat(tick_in_beat),.beat_in_bar(beat_in_bar),.start_req(start_req),.stop_req(stop_req),
        .record_req(record_req),.beats_per_bar(meter),.loop_bars(bars),.metronome_enable(1'b0),
        .transport_run(transport_run),.count_in(count_in),.playing(playing),.recording(transport_recording),
        .record_armed(record_armed),.record_start_pulse(record_start_pulse),.record_done_pulse(record_done_pulse),
        .loop_wrap_pulse(loop_wrap_pulse),.stop_pulse(stop_pulse),.metronome_click(),.metronome_accent(),
        .loop_tick(loop_tick),.loop_number(loop_number));
    wire click_valid,click_onset;wire signed [15:0] click_sample;wire [31:0] clicks_delivered;
    metronome_click click_generator(.clk(sys_clk),.rst(rst),.sample_ce(tx_sample_ce),
        .trigger(beat_pulse),.accent(beat_in_bar==0),.enable(met_enable||count_in),.gain_q8(click_gain),
        .valid(click_valid),.sample(click_sample),.onset(click_onset),.delivered(clicks_delivered));

    reg [1:0] record_track;
    reg [1:0] free_layer;reg lane_available;
    integer li;
    always @* begin
        free_layer=0;lane_available=0;
        for(li=0;li<4;li=li+1) if(!layer_valid[record_track*4+li] && !lane_available) begin
            free_layer=li;lane_available=1;
        end
    end
    always @(posedge sys_clk) if(rst) record_track<=0;else if(record_req) record_track<=selected_track;
    wire [3:0] record_lane={record_track,free_layer};
    wire record_busy;wire [11:0] record_event_tick;
    wire recording,record_commit,record_overflow,record_error,record_event_ready;
    wire [7:0] recorded_events;reg [11:0] loop_length;
    always @(posedge sys_clk) if(rst) loop_length<=384;else case({meter,bars})
        6'd17:loop_length<=12'd192;
        6'd18:loop_length<=12'd384;
        6'd19:loop_length<=12'd576;
        6'd20:loop_length<=12'd768;
        6'd25:loop_length<=12'd288;
        6'd26:loop_length<=12'd576;
        6'd27:loop_length<=12'd864;
        6'd28:loop_length<=12'd1152;
        6'd33:loop_length<=12'd384;
        6'd34:loop_length<=12'd768;
        6'd35:loop_length<=12'd1152;
        6'd36:loop_length<=12'd1536;
        default:loop_length<=384;
    endcase
    wire loop_event_valid,loop_event_ready,loop_event_off,loop_event_drum;
    wire loop_event_control,expression_overflow;
    wire [1:0] loop_event_track,loop_event_layer;
    wire [11:0] loop_event_tick;wire [6:0] loop_event_note;
    wire [15:0] loop_event_id;wire [7:0] loop_event_velocity;
    wire [2:0] loop_event_preset;wire [135:0] loop_event_patch,core_patch;
    wire [31:0] event_late_count;
    wire record_event_valid;wire [1:0] record_event_kind;
    wire [6:0] record_event_note;wire [15:0] record_event_id;wire [7:0] record_event_velocity;
    wire removed_valid;wire [1:0] removed_track,removed_layer;
    wire flushing;
    looper_event_store #(.LANES(16),.LAYERS_PER_TRACK(4),.RECORD_TICK_INPUT(1),.SERIAL_NOTES(1),.ACTIVE_NOTES(32)) store(
        .clk(sys_clk),.rst(rst),.play_enable(playing),.playback_reset(stop_pulse),
        .loop_wrap(loop_wrap_pulse),.loop_tick(loop_tick),.loop_length(loop_length),.quantize_mode(quantize),
        .record_start(record_start_pulse),.record_lane(record_lane),.record_patch(selected_preset==6 ? {core_patch[135:3],3'd6} : core_patch),
        .record_tick(record_event_tick),.record_busy(record_busy),.record_cancel(stop_req||stop_pulse||expression_overflow),.record_event_valid(record_event_valid),.record_event_ready(record_event_ready),
        .record_event_kind(record_event_kind),.record_note(record_event_note),.record_note_id(record_event_id),
        .record_velocity(record_event_velocity),.recording(recording),.record_commit(record_commit),
        .record_overflow(record_overflow),.record_error(record_error),.recorded_events(recorded_events),
        .undo_valid(undo_req && !flushing),.undo_lane({2'd0,selected_track}),
        .clear_valid(clear_req && !flushing),.clear_track(selected_track),
        .removed_valid(removed_valid),.removed_track(removed_track),.removed_layer(removed_layer),
        .layer_valid(layer_valid),.event_valid(loop_event_valid),.event_ready(loop_event_ready),
        .event_off(loop_event_off),.event_drum(loop_event_drum),.event_track(loop_event_track),.event_layer(loop_event_layer),
        .event_control(loop_event_control),
        .event_tick(loop_event_tick),.event_note(loop_event_note),.event_note_id(loop_event_id),.event_velocity(loop_event_velocity),
        .event_preset(loop_event_preset),.event_patch(loop_event_patch),.event_late_count(event_late_count));
    wire drum_event_valid,drum_engine_ready,drum_engine_accepted;wire [3:0] drum_event_pad;
    wire [1:0] drum_event_layer;wire [2:0] drum_event_track;wire [7:0] drum_event_velocity;
    wire drum_sample_valid;wire signed [19:0] drum_sample;wire [7:0] drum_active;
    wire [31:0] drum_late,drum_rejected;
    looper_drum_engine #(.VOICES(8)) drum(.clk(sys_clk),.rst(rst),.sample_ce(tx_sample_ce),
        .strike_valid(drum_event_valid),.strike_ready(drum_engine_ready),.strike_accepted(drum_engine_accepted),.strike_pad(drum_event_pad),
        .strike_layer(drum_event_layer),.strike_track(drum_event_track),.track_gains(track_gains),.strike_velocity(drum_event_velocity),
        .flush_all(stop_pulse),.flush_valid(clear_req||removed_valid),
        .flush_track(removed_valid ? removed_track : selected_track),.flush_layer(removed_layer),.flush_whole_track(clear_req),
        .sample_valid(drum_sample_valid),.sample(drum_sample),.active(drum_active),.active_pads(),
        .late_strikes(drum_late),.rejected_strikes(drum_rejected));
    reg signed [15:0] drum_audio;
    always @(posedge sys_clk) if(rst) drum_audio<=0;else if(drum_sample_valid) drum_audio<=drum_sample>>>4;
    wire signed [16:0] auxiliary_wide=$signed(drum_audio)+$signed(click_sample);
    wire signed [15:0] auxiliary_sample=auxiliary_wide[15:0];
    wire [31:0] loop_route_faults,loop_unmatched_offs;
    wire audio_deadline,blocked,rejected,clip_seen,final_valid;
    wire [AUDIO_N-1:0] occupied,held,gated;
    looper_audio_core #(.KEYS(16),.SPLIT(8),.DIATONIC(1),.N(AUDIO_N),.PLUCK_N(PLUCK_N),.WITH_FX(1),.WITH_EXPRESSION(1)) audio(
        .clk(sys_clk),.rst(rst),.sample_ce(tx_sample_ce),.keys(keys),.changed(changed),.ghost(ghost),.all_released(all_released),
        .button_n(3'b111),.step_valid(1'b0),.step(2'sd0),.recording(recording),.capture_recording(recording && transport_recording),
        .current_loop_tick(loop_tick),.record_busy(record_busy),.record_event_tick(record_event_tick),.record_ready(record_event_ready),
        .drum_mode(selected_preset==6),.auxiliary_sample(auxiliary_sample),
        .flush_all(stop_pulse),.flush_valid(removed_valid||clear_req),
        .flush_track(removed_valid ? removed_track : selected_track),.flush_layer(removed_layer),
        .flush_whole_track(clear_req),.flushing(flushing),
        .loop_event_valid(loop_event_valid),.loop_event_ready(loop_event_ready),.loop_event_off(loop_event_off),
        .loop_event_drum(loop_event_drum),.loop_event_track(loop_event_track),.loop_event_layer(loop_event_layer),
        .loop_event_control(loop_event_control),.expression_overflow(expression_overflow),
        .loop_event_id(loop_event_id),.loop_event_tick(loop_event_tick),.loop_event_note(loop_event_note),
        .loop_event_velocity(loop_event_velocity),.loop_event_preset(loop_event_preset),.loop_event_patch(loop_event_patch),
        .loop_route_faults(loop_route_faults),.loop_unmatched_offs(loop_unmatched_offs),
        .track_gains(track_gains),.record_event_valid(record_event_valid),.record_event_kind(record_event_kind),
        .record_event_note(record_event_note),.record_event_id(record_event_id),.record_event_velocity(record_event_velocity),
        .record_patch_current(core_patch),.drum_event_valid(drum_event_valid),.drum_event_ready(drum_engine_ready),.drum_event_accepted(drum_engine_accepted),
        .drum_event_layer(drum_event_layer),.drum_event_track(drum_event_track),.drum_event_pad(drum_event_pad),.drum_event_velocity(drum_event_velocity),
        .host_valid(backend_valid),.host_ready(backend_ready),.host_addr(backend_addr),.host_value(backend_value),
        .adc_valid(adc_valid),.adc_ready(adc_ready),.adc_ch0(adc_data[11:0]),.adc_ch1(adc_data[23:12]),
        .adc_ch2(adc_data[35:24]),.adc_ch3(adc_data[47:36]),.adc_ch4(adc_data[59:48]),
        .final_valid(final_valid),.final_left(audio_left),.final_right(audio_right),.sample_index(pcm_index),
        .snapshot_valid(audio_snapshot_valid),.snapshot_data(audio_snapshot),.selected_preset(),.control_mode(),.sustain(),.sostenuto(),.blocked(blocked),
        .rejected(rejected),.deadline_missed(audio_deadline),.occupied(occupied),.held(held),.gated(gated),.muting(),
        .clip_seen(clip_seen),.capabilities(audio_capabilities),.snapshot_extension(snapshot_extension),.snapshot_keys(snapshot_keys),
        .harmonic_targets(harmonic_targets),.voice_origins(voice_origins),
        .ack_valid(backend_ack_valid),.ack_source(backend_ack_source),.ack_accepted(backend_ack_accepted),
        .ack_applied(backend_ack_applied),.ack_addr(backend_ack_addr),.ack_value(backend_ack_value));
    // Versioned appendix, latched on the SAME audio snapshot publication.
    // audio_snapshot stays stable until its next 1024-frame publication.
    reg [511:0] appendix;reg published;
    assign snapshot_data={appendix,audio_snapshot};assign snapshot_valid=published;
    localparam [15:0] OBSERVATION_W=320+512+AUDIO_N*64;
    assign capabilities={audio_capabilities[127:112],OBSERVATION_W,audio_capabilities[95:0]};
    assign pcm_valid=final_valid;assign pcm_left=audio_left;assign pcm_right=audio_right;
    always @(posedge sys_clk) begin
        if(rst) begin appendix<=0;published<=0;end
        else begin
            published<=audio_snapshot_valid;
            if(audio_snapshot_valid) begin
                appendix<=0;
                appendix[15:0]<=16'h4c52;appendix[23:16]<=1;appendix[31:24]<=AUDIO_N;
                appendix[34:32]<=page;appendix[37:35]<=mode;appendix[39:38]<=selected_track;
                appendix[42:40]<=selected_preset;
                appendix[43]<=transport_run;appendix[44]<=count_in;appendix[45]<=playing;
                appendix[46]<=recording;appendix[47]<=record_armed;appendix[48]<=met_enable;
                appendix[56:49]<=bpm;appendix[64:57]<=applied_bpm;
                appendix[67:65]<=meter;appendix[70:68]<=bars;appendix[72:71]<=quantize;
                appendix[84:73]<=loop_tick;appendix[116:85]<=loop_number;
                appendix[132:117]<=layer_valid;appendix[136:133]<=muted;
                appendix[204:137]<=track_gains;appendix[212:205]<=drum_active;
                appendix[221:213]<=click_gain;appendix[229:222]<=recorded_events;
                appendix[230]<=fault;appendix[231]<=clip_seen;
                appendix[263:232]<=loop_route_faults;appendix[295:264]<=event_late_count;
                appendix[296+:AUDIO_N*5]<=voice_origins;
            end
        end
    end
    // One LED encodes page by short flashes; faults use rapid blinking. Beat
    // flash is overlaid, recording/count-in produces an obvious steady light.
    reg [25:0] led_counter;
    always @(posedge sys_clk) if(rst) led_counter<=0;else led_counter<=led_counter+1'b1;
    reg operation_error;
    always @(posedge sys_clk) if(rst) operation_error<=0;
        else if(expression_overflow || record_error || rejected || loop_route_faults!=0 || drum_rejected!=0) operation_error<=1;
    assign fault=operation_error||arbiter_fault||control_overflow||record_overflow||expression_overflow||audio_deadline||drum_late!=0;
    assign status_led=fault ? led_counter[21] :
        (recording||count_in) ? 1'b1 :
        (led_counter[25:23]<=page && led_counter[22:19]==0) || (met_enable && tick_in_beat<5);
    assign pa_en=1'b0;
endmodule

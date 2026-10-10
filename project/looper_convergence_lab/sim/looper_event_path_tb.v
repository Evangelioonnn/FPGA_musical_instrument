`timescale 1ns/1ps
module looper_event_path_tb;
    reg clk = 0;
    always #10 clk = !clk;
    reg rst = 1;
    reg play_enable = 0;
    reg playback_reset = 0;
    reg loop_wrap = 0;
    reg [11:0] loop_tick = 0;
    reg [11:0] loop_length = 192;
    reg [1:0] quantize_mode = 1;
    reg record_start = 0;
    reg [3:0] record_lane = 0;
    reg [135:0] record_patch = 136'd5;
    reg live_valid = 0;
    wire live_ready;
    reg live_off = 0;
    reg [31:0] live_token = 32'h12345678;
    reg [6:0] live_note = 60;
    reg [2:0] live_preset = 5;
    wire router_record_valid;
    wire [1:0] router_record_kind;
    wire [6:0] router_record_note;
    wire [15:0] router_record_id;
    wire [7:0] router_record_velocity;
    wire recording, record_commit, record_overflow, record_error;
    wire [7:0] recorded_events;
    wire event_valid, event_off, event_drum;
    wire [1:0] event_track, event_layer;
    wire [11:0] event_tick;
    wire [6:0] event_note;
    wire [15:0] event_id;
    wire [7:0] event_velocity;
    wire [2:0] event_preset;
    wire [135:0] event_patch;
    wire [31:0] event_late_count;
    wire [15:0] layer_valid;
    wire [2175:0] layer_patches;
    reg undo_valid = 0;
    reg [3:0] undo_lane = 0;
    wire router_loop_ready;
    wire bank_valid, bank_off;
    wire [31:0] bank_token;
    wire [6:0] bank_note;
    wire [2:0] bank_preset;
    wire [2:0] bank_track;
    wire [135:0] bank_patch;
    wire bank_loop;
    wire drum_valid;
    wire [3:0] drum_pad;
    wire [7:0] drum_velocity;
    wire [31:0] route_faults, unmatched_offs;
    integer accepted = 0;
    integer consumed = 0;
    integer commits = 0;
    reg [31:0] replay_token;

    looper_event_store #(.LANES(16), .EVENTS_PER_LANE(128), .LANE_W(4),
        .EVENT_AW(7), .PATCH_W(136)) store(
        .clk(clk), .rst(rst), .play_enable(play_enable), .playback_reset(playback_reset),
        .loop_wrap(loop_wrap), .loop_tick(loop_tick), .loop_length(loop_length),
        .quantize_mode(quantize_mode), .record_start(record_start),
        .record_lane(record_lane), .record_patch(record_patch),
        .record_event_valid(router_record_valid), .record_event_ready(),
        .record_event_kind(router_record_kind), .record_note(router_record_note),
        .record_note_id(router_record_id), .record_velocity(router_record_velocity),
        .recording(recording), .record_commit(record_commit), .record_overflow(record_overflow),
        .record_error(record_error), .recorded_events(recorded_events),
        .undo_valid(undo_valid), .undo_lane(undo_lane), .layer_valid(layer_valid),
         .event_valid(event_valid), .event_ready(router_loop_ready),
        .event_off(event_off), .event_drum(event_drum), .event_track(event_track),
        .event_layer(event_layer), .event_tick(event_tick), .event_note(event_note),
        .event_note_id(event_id), .event_velocity(event_velocity), .event_preset(event_preset),
        .event_patch(event_patch), .event_late_count(event_late_count));

    looper_event_router #(.VOICES(32), .PATCH_W(136)) router(
        .clk(clk), .rst(rst), .live_valid(live_valid), .live_ready(live_ready),
        .live_off(live_off), .live_token(live_token), .live_note(live_note),
        .live_preset(live_preset), .recording(recording), .record_valid(router_record_valid),
        .record_kind(router_record_kind), .record_note(router_record_note),
        .record_local_id(router_record_id), .record_velocity(router_record_velocity),
        .loop_valid(event_valid), .loop_ready(router_loop_ready), .loop_off(event_off),
        .loop_drum(event_drum), .loop_track(event_track), .loop_layer(event_layer),
        .loop_local_id(event_id), .loop_note(event_note), .loop_velocity(event_velocity),
        .loop_preset(event_preset), .loop_patch(event_patch), .bank_valid(bank_valid),
        .bank_ready(1'b1), .bank_off(bank_off), .bank_token(bank_token), .bank_note(bank_note),
        .bank_preset(bank_preset), .bank_patch(bank_patch), .drum_valid(drum_valid),
        .bank_track(bank_track), .bank_loop(bank_loop),
        .drum_ready(1'b1), .drum_pad(drum_pad), .drum_velocity(drum_velocity),
        .route_faults(route_faults), .unmatched_offs(unmatched_offs));

    always @(posedge clk) begin
        if (!rst && record_commit) commits = commits + 1;
        // bank_ready is tied high; bank and store handshakes are independent.
        if (!rst && play_enable && event_valid && router_loop_ready) consumed = consumed + 1;
        if (!rst && play_enable && bank_valid) begin
            accepted = accepted + 1;
            if (accepted == 1) begin
                replay_token = bank_token;
                if (bank_off || bank_note != 60 || bank_preset != 5 ||
                    bank_patch[2:0] != 5 || event_tick != 48)
                    $fatal(1, "recorded note-on/preset/quantization mismatch");
            end else if (accepted == 2) begin
                if (!bank_off || bank_token != replay_token || bank_preset != 5 || event_tick != 96)
                    $fatal(1, "recorded note-off did not match runtime token");
            end
        end
    end

    task live_event;
        input off;
        input [11:0] at_tick;
        begin
            @(negedge clk);
            loop_tick = at_tick;
            live_off = off;
            live_valid = 1;
            while (!live_ready) @(negedge clk);
            @(negedge clk);
            live_valid = 0;
            live_off = 0;
        end
    endtask

    initial begin
        repeat (3) @(negedge clk);
        rst = 0;
        @(negedge clk);
        record_start = 1;
        @(negedge clk);
        record_start = 0;
        live_event(0, 49);
        live_event(1, 95);
        @(negedge clk);
        loop_wrap = 1;
        @(negedge clk);
        loop_wrap = 0;
        // Closing the held-note table is serialized across ACTIVE_NOTES
        // entries before the patch/layer commit becomes visible.
        repeat (40) @(negedge clk);
        if (!layer_valid[0] || commits != 1 || store.patch_mem[0][2:0] != 5)
            $fatal(1, "layer did not atomically capture its patch");

        play_enable = 1;
        loop_tick = 48;
        playback_reset = 1;
        @(negedge clk);
        playback_reset = 0;
        repeat (240) @(negedge clk);
        loop_tick = 96;
        repeat (240) @(negedge clk);
        if (accepted != 2 || consumed != 2)
            $fatal(1, "expected one loop note-on and note-off, accepted=%0d", accepted);
        $display("LOOPER_EVENT_PATH_TB_PASS recorded_note_pair=1 replay_token_match=1 quantized=48/96 patch=5");
        $finish;
    end
endmodule

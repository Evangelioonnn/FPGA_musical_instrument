`timescale 1ns/1ps
module looper_event_store_tb;
    reg record_busy=0;reg [11:0] record_tick=0;
    reg record_cancel=0,clear_valid=0;
    reg [1:0] clear_track=0;
    wire removed_valid;wire [1:0] removed_track,removed_layer;
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
    reg [135:0] record_patch = 0;
    reg record_event_valid = 0;
    wire record_event_ready;
    reg [1:0] record_event_kind = 0;
    reg [6:0] record_note = 60;
    reg [15:0] record_note_id = 1;
    reg [7:0] record_velocity = 100;
    wire recording, record_commit, record_overflow, record_error;
    wire [7:0] recorded_events;
    reg undo_valid = 0;
    reg [3:0] undo_lane = 0;
    wire [15:0] layer_valid;
    wire [2175:0] layer_patches;
    wire event_valid;
    reg event_ready = 0;
    wire event_off, event_drum;
    wire [1:0] event_track, event_layer;
    wire [11:0] event_tick;
    wire [6:0] event_note;
    wire [15:0] event_note_id;
    wire [7:0] event_velocity;
    wire [2:0] event_preset;
    wire [135:0] event_patch;
    wire [31:0] event_late_count;
    integer commits = 0;
    integer note_ons = 0;
    integer note_offs = 0;
    integer events_seen = 0;
    integer timeout;
    reg [11:0] saved_tick;
    reg [15:0] saved_note_id;

    looper_event_store #(.LANES(16), .EVENTS_PER_LANE(4), .LANE_W(4),
        .EVENT_AW(2), .PATCH_W(136)) dut(.*);

    always @(posedge clk) begin
        if (!rst) begin
            if (record_commit) commits = commits + 1;
            if (event_valid && event_ready) begin
                events_seen = events_seen + 1;
                $display("ACCEPT track=%0d layer=%0d tick=%0d off=%b id=%0d preset=%0d",
                    event_track, event_layer, event_tick, event_off, event_note_id, event_preset);
                if (event_off) note_offs = note_offs + 1;
                else note_ons = note_ons + 1;
                saved_tick = event_tick;
                saved_note_id = event_note_id;
            end
        end
    end

    task push_record_event;
        input [1:0] kind;
        input [11:0] tick;
        input [15:0] id;
        begin
            @(negedge clk);
            loop_tick = tick;
            record_event_kind = kind;
            record_note = 60;
            record_note_id = id;
            record_event_valid = 1;
            #1;
            while (!record_event_ready) @(negedge clk);
            @(negedge clk);
            record_event_valid = 0;
        end
    endtask

    task wait_for_commit;
        input integer count;
        integer timeout;
        begin
            timeout = 0;
            while (commits < count && timeout < 500) begin
                @(negedge clk);
                timeout = timeout + 1;
            end
            if (commits < count) $fatal(1, "record commit timeout");
        end
    endtask

    task consume_at_tick;
        input [11:0] tick;
        input [3:0] expected_lane;
        integer timeout;
        begin
            @(negedge clk);
            loop_tick = tick;
            event_ready = 0;
            timeout = 0;
            while (!event_valid && timeout < 500) begin
                @(negedge clk);
                timeout = timeout + 1;
            end
            if (!event_valid) $fatal(1, "playback event timeout at tick %0d", tick);
            $display("PRESENT target=%0d track=%0d layer=%0d tick=%0d off=%b id=%0d", tick,
                event_track,event_layer,event_tick,event_off,event_note_id);
            repeat (3) begin
                @(negedge clk);
                if (!event_valid || event_tick > tick || event_track != expected_lane / 4 ||
                    event_layer != expected_lane % 4) begin
                    $display("STALLED valid=%b event_tick=%0d target=%0d track=%0d layer=%0d expected=%0d",
                        event_valid, event_tick, tick, event_track, event_layer, expected_lane);
                    $fatal(1, "stalled playback payload changed");
                end
            end
            event_ready = 1;
            @(negedge clk);
            event_ready = 0;
        end
    endtask

    task push_overflow_event;
        begin
            @(negedge clk);
            loop_tick = 12'd0;
            record_event_kind = 0;
            record_note_id = 8'd99;
            record_event_valid = 1;
            @(negedge clk);
            if (record_event_ready) $fatal(1, "full event lane still accepted input");
            record_event_valid = 0;
        end
    endtask

    initial begin
        repeat (3) @(negedge clk);
        rst = 0;
        @(negedge clk);
        record_lane = 0;
        record_patch = 136'd5;
        record_start = 1;
        @(negedge clk);
        record_start = 0;
        push_record_event(0, 49, 16'd267);
        push_record_event(1, 95, 16'd267);
        @(negedge clk);
        loop_wrap = 1;
        @(negedge clk);
        loop_wrap = 0;
        wait_for_commit(1);
        if (!layer_valid[0] || dut.patch_mem[0] != 136'd5)
            $fatal(1, "first layer patch was not frozen");

        @(negedge clk);
        record_lane = 1;
        record_patch = 136'd2;
        record_start = 1;
        @(negedge clk);
        record_start = 0;
        push_record_event(0, 0, 16'd1);
        push_record_event(1, 48, 16'd1);
        @(negedge clk);
        loop_wrap = 1;
        @(negedge clk);
        loop_wrap = 0;
        wait_for_commit(2);
        if (!layer_valid[1] || dut.patch_mem[1] != 136'd2)
            $fatal(1, "overdub layer patch was not kept separate");

        loop_tick = 0;
        play_enable = 1;
        playback_reset = 1;
        @(negedge clk);
        playback_reset = 0;
        repeat (24) @(negedge clk);
        consume_at_tick(0, 1);
        if (event_off || event_note_id != 16'd1 || event_preset != 2)
            $fatal(1, "overdub note-on payload mismatch");
        repeat (24) @(negedge clk);
        consume_at_tick(48, 1);
        if (!event_off || event_note_id != 16'd1 || event_preset != 2)
            $fatal(1, "overdub note-off payload mismatch");
        consume_at_tick(48, 0);
        if (event_off || event_note_id != 16'd267 || event_preset != 5 || event_note != 60)
            $fatal(1, "first quantized note-on payload mismatch");
        consume_at_tick(96, 0);
        if (!event_off || event_note_id != 16'd267 || event_preset != 5)
            $fatal(1, "matching note-off/preset mismatch");
        if (events_seen != 4 || note_ons != 2 || note_offs != 2)
            $fatal(1, "layer event count mismatch");

        @(negedge clk);
        loop_wrap = 1;
        @(negedge clk);
        loop_wrap = 0;
        playback_reset = 1;
        @(negedge clk);
        playback_reset = 0;
        @(negedge clk);
        undo_valid = 1;
        undo_lane = 0;
        @(negedge clk);
        undo_valid = 0;
        repeat(80) @(negedge clk);
        if (!layer_valid[0] || layer_valid[1]) $fatal(1, "track undo removed wrong layer");
        @(negedge clk);
        undo_valid = 1;
        undo_lane = 0;
        @(negedge clk);
        undo_valid = 0;
        repeat(80) @(negedge clk);
        if (layer_valid[0]) $fatal(1, "second track undo did not remove remaining layer");

        @(negedge clk);
        record_lane = 4;
        record_patch = 136'd3;
        record_start = 1;
        @(negedge clk);
        record_start = 0;
        push_record_event(0, 12'd191, 16'd513);
        @(negedge clk);
        loop_wrap = 1;
        @(negedge clk);
        loop_wrap = 0;
        wait_for_commit(3);
        loop_tick = 12'd191;
        play_enable = 1;
        playback_reset = 1;
        @(negedge clk);
        playback_reset = 0;
        timeout = 0;
        while (!event_valid && timeout < 500) begin
            @(negedge clk);
            timeout = timeout + 1;
        end
        if (!event_valid || event_tick != 12'd191 || event_note_id != 16'd513)
            $fatal(1, "last-tick event did not become valid");
        repeat (2) @(negedge clk);
        loop_wrap = 1;
        @(negedge clk);
        loop_wrap = 0;
        repeat (3) begin
            if (!event_valid || event_note_id != 16'd513 || event_tick != 12'd191)
                $fatal(1, "loop wrap dropped or changed a stalled event");
            @(negedge clk);
        end
        event_ready = 1;
        @(negedge clk);
        event_ready = 0;

        @(negedge clk);
        play_enable = 0;
        record_lane = 8;
        record_patch = 136'd6;
        record_start = 1;
        @(negedge clk);
        record_start = 0;
        push_record_event(0, 0, 16'd1);
        push_record_event(0, 12, 16'd2);
        push_record_event(0, 24, 16'd3);
        push_record_event(0, 36, 16'd4);
        push_overflow_event();
        if (!record_overflow) $fatal(1, "full event lane did not raise overflow");
        @(negedge clk);
        loop_wrap = 1;
        @(negedge clk);
        loop_wrap = 0;
        repeat (2) @(negedge clk);
        if (layer_valid[8] || commits != 3)
            $fatal(1, "overflowed recording was not rejected atomically");

        $display("LOOPER_EVENT_STORE_TB_PASS quantize=48/96 patches=5/2 undo=track0 wrap_stall=preserved overflow=atomic");
        $finish;
    end
endmodule

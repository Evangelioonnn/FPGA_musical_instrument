`timescale 1ns/1ps
module looper_auto_close_tb;
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
    reg [1:0] quantize_mode = 0;
    reg record_start = 0;
    reg [3:0] record_lane = 8;
    reg [135:0] record_patch = 136'd4;
    reg record_event_valid = 0;
    wire record_event_ready;
    reg [1:0] record_event_kind = 0;
    reg [6:0] record_note = 48;
    reg [15:0] record_note_id = 16'd600;
    reg [7:0] record_velocity = 255;
    wire recording, record_commit, record_overflow, record_error;
    wire [7:0] recorded_events;
    reg undo_valid = 0;
    reg [3:0] undo_lane = 0;
    wire [15:0] layer_valid;
    wire [2175:0] layer_patches;
    wire event_valid;
    reg event_ready = 1;
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
    integer ons = 0;
    integer offs = 0;
    integer timeout;

    looper_event_store #(.LANES(16), .EVENTS_PER_LANE(128), .LANE_W(4),
        .EVENT_AW(7), .PATCH_W(136)) dut(.event_control(),.*);

    always @(posedge clk) begin
        if (record_commit) commits = commits + 1;
        if (event_valid && event_ready) begin
            if (event_off) begin
                offs = offs + 1;
                if (event_tick != 191 || event_note_id != 600 || event_preset != 4 || event_velocity != 0)
                    $fatal(1, "synthetic wrap note-off payload invalid");
            end else begin
                ons = ons + 1;
                if (event_tick != 24 || event_note_id != 600 || event_preset != 4)
                    $fatal(1, "recorded note-on payload invalid");
            end
        end
    end

    initial begin
        repeat (3) @(negedge clk);
        rst = 0;
        @(negedge clk);
        record_start = 1;
        @(negedge clk);
        record_start = 0;
        loop_tick = 24;
        record_event_valid = 1;
        #1;
        while (!record_event_ready) @(negedge clk);
        @(negedge clk);
        record_event_valid = 0;
        @(negedge clk);
        loop_wrap = 1;
        @(negedge clk);
        loop_wrap = 0;
        timeout = 0;
        while (commits == 0 && timeout < 80) begin
            @(negedge clk);
            timeout = timeout + 1;
        end
        if (commits != 1 || !layer_valid[8] || recorded_events != 0)
            $fatal(1, "wrap did not commit a fully closed layer");
        play_enable = 1;
        playback_reset = 1;
        @(negedge clk);
        playback_reset = 0;
        loop_tick = 24;
        timeout = 0;
        while (ons != 1 && timeout < 80) begin
            @(negedge clk);
            timeout = timeout + 1;
        end
        loop_tick = 191;
        timeout = 0;
        while (offs != 1 && timeout < 80) begin
            @(negedge clk);
            timeout = timeout + 1;
        end
        if (ons != 1 || offs != 1)
            $fatal(1, "held note was not paired by synthetic wrap note-off");
        $display("LOOPER_AUTO_CLOSE_TB_PASS held_note_closed_at=%0d", event_tick);
        $finish;
    end
endmodule

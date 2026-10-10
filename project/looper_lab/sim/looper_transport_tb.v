`timescale 1ns/1ps
module looper_transport_tb;
    reg clk = 0;
    always #10 clk = !clk;
    reg rst = 1;
    reg sample_ce = 1;
    reg start_req = 0;
    reg stop_req = 0;
    reg record_req = 0;
    reg [7:0] bpm = 240;
    reg [2:0] beats_per_bar = 4;
    reg [2:0] loop_bars = 1;
    reg metronome_enable = 1;
    wire tick_pulse, beat_pulse, bar_pulse;
    wire [6:0] tick_in_beat;
    wire [2:0] beat_in_bar;
    wire [31:0] frame_index;
    wire transport_run, count_in, playing, recording, record_armed;
    wire record_start_pulse, record_done_pulse, loop_wrap_pulse, stop_pulse;
    wire metronome_click, metronome_accent;
    wire [11:0] loop_tick;
    wire [31:0] loop_number;
    integer rec_starts = 0;
    integer rec_dones = 0;
    integer wraps = 0;
    integer countin_beats = 0;
    integer clicks = 0;
    integer accents = 0;
    integer ticks_after_rec_start = 0;
    integer ticks_after_overdub_start = 0;
    reg recording_previous = 0;
    reg countin_previous = 0;

    looper_clock #(.CLK_HZ(5000000), .FRAME_CLOCKS(1040), .PPQN(96)) clock_unit(
        .clk(clk), .rst(rst), .sample_ce(sample_ce), .run(transport_run),
        .bpm(bpm), .beats_per_bar(beats_per_bar), .tick_pulse(tick_pulse),
        .beat_pulse(beat_pulse), .bar_pulse(bar_pulse), .tick_in_beat(tick_in_beat),
        .beat_in_bar(beat_in_bar), .frame_index(frame_index));

    looper_transport transport_unit(
        .clk(clk), .rst(rst), .tick_pulse(tick_pulse), .beat_pulse(beat_pulse),
        .bar_pulse(bar_pulse), .tick_in_beat(tick_in_beat), .beat_in_bar(beat_in_bar),
        .start_req(start_req), .stop_req(stop_req), .record_req(record_req),
        .beats_per_bar(beats_per_bar), .loop_bars(loop_bars), .metronome_enable(metronome_enable),
        .transport_run(transport_run), .count_in(count_in), .playing(playing),
        .recording(recording), .record_armed(record_armed), .record_start_pulse(record_start_pulse),
        .record_done_pulse(record_done_pulse), .loop_wrap_pulse(loop_wrap_pulse), .stop_pulse(stop_pulse),
        .metronome_click(metronome_click), .metronome_accent(metronome_accent),
        .loop_tick(loop_tick), .loop_number(loop_number));

    always @(posedge clk) begin
        if (rst) begin
            recording_previous <= 0;
            countin_previous <= 0;
        end else begin
            if (record_start_pulse) rec_starts = rec_starts + 1;
            if (record_done_pulse) rec_dones = rec_dones + 1;
            if (loop_wrap_pulse) wraps = wraps + 1;
            if (metronome_click) clicks = clicks + 1;
            if (metronome_click && metronome_accent) accents = accents + 1;
            if (count_in && beat_pulse) countin_beats = countin_beats + 1;
            if (recording && !recording_previous && rec_starts == 1)
                ticks_after_rec_start = 0;
            else if (recording && tick_pulse && rec_starts == 1)
                ticks_after_rec_start = ticks_after_rec_start + 1;
            if (recording && !recording_previous && rec_starts == 2)
                ticks_after_overdub_start = 0;
            else if (recording && tick_pulse && rec_starts == 2)
                ticks_after_overdub_start = ticks_after_overdub_start + 1;
            recording_previous <= recording;
            countin_previous <= count_in;
        end
    end

    task wait_for_wraps;
        input integer target;
        integer timeout;
        begin
            timeout = 0;
            while (wraps < target && timeout < 100000) begin
                @(negedge clk);
                timeout = timeout + 1;
            end
            if (wraps < target) $fatal(1, "loop wrap timeout target=%0d", target);
        end
    endtask

    initial begin
        repeat (3) @(negedge clk);
        rst = 0;
        @(negedge clk);
        start_req = 1;
        record_req = 1;
        @(negedge clk);
        start_req = 0;
        record_req = 0;
        wait_for_wraps(1);
        if (countin_beats != 5) $fatal(1, "count-in beat count=%0d", countin_beats);
        if (rec_starts != 1 || rec_dones != 1) $fatal(1, "first pass record state mismatch");
        if (ticks_after_rec_start != 384) $fatal(1, "first pass tick count=%0d", ticks_after_rec_start);

        @(negedge clk);
        record_req = 1;
        @(negedge clk);
        record_req = 0;
        wait_for_wraps(2);
        if (record_armed) $fatal(1, "second pass did not arm at wrap");
        wait_for_wraps(3);
        if (rec_starts != 2 || rec_dones != 2) $fatal(1, "overdub pass state mismatch");
        if (ticks_after_overdub_start != 384) $fatal(1, "overdub tick count=%0d", ticks_after_overdub_start);
        if (!playing || !transport_run) $fatal(1, "transport stopped during playback");
        if (clicks < 12 || accents < 3) $fatal(1, "metronome click/accent count=%0d/%0d", clicks, accents);

        @(negedge clk);
        stop_req = 1;
        @(negedge clk);
        stop_req = 0;
        if (transport_run || playing || recording || !stop_pulse)
            $fatal(1, "stop did not close transport");
        $display("LOOPER_TRANSPORT_TB_PASS countin=one_bar_plus_record_downbeat ticks_per_pass=384 loops=3");
        $finish;
    end
endmodule

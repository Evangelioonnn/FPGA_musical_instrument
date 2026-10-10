`timescale 1ns/1ps
module looper_clock_tb;
    localparam integer TEST_FRAMES = 2884615;
    reg restart=0;
    reg clk = 0;
    always #10 clk = !clk;
    reg rst = 1;
    reg sample_ce = 1;
    reg run = 0;
    reg [7:0] bpm = 120;
    reg [2:0] beats_per_bar = 4;
    wire tick_pulse, beat_pulse, bar_pulse;
    wire [6:0] tick_in_beat;
    wire [2:0] beat_in_bar;
    wire [31:0] frame_index;
    looper_clock dut(.*);

    task check_tempo;
        input integer tempo;
        integer i;
        reg [63:0] ticks_seen;
        reg [63:0] beats_seen;
        reg [63:0] bars_seen;
        reg [63:0] expected_ticks;
        reg [63:0] expected_beats;
        begin
            rst = 1;
            run = 0;
            bpm = tempo;
            repeat (3) @(negedge clk);
            rst = 0;
            run = 1;
            ticks_seen = 0;
            beats_seen = 0;
            bars_seen = 0;
            for (i = 0; i < TEST_FRAMES; i = i + 1) begin
                @(posedge clk);
                #1;
                if (tick_pulse) ticks_seen = ticks_seen + 1;
                if (beat_pulse) beats_seen = beats_seen + 1;
                if (bar_pulse) bars_seen = bars_seen + 1;
            end
            expected_ticks = (64'd2884614 * tempo * 64'd96 * 64'd1040) / 64'd3000000000;
            expected_beats = expected_ticks / 96 + 1;
            if (ticks_seen != expected_ticks || beats_seen != expected_beats ||
                bars_seen != (expected_beats-1) / 4) begin
                $display("CLOCK_COUNTS bpm=%0d ticks=%0d/%0d beats=%0d/%0d bars=%0d/%0d",
                    tempo, ticks_seen, expected_ticks, beats_seen, expected_beats,
                    bars_seen, (expected_beats-1) / 4);
                $fatal(1, "clock count mismatch");
            end
            $display("CLOCK_TEMPO_PASS bpm=%0d ticks=%0d beats=%0d bars=%0d",
                tempo, ticks_seen, beats_seen, bars_seen);
        end
    endtask

    initial begin
        check_tempo(40);
        check_tempo(120);
        check_tempo(240);
        $display("LOOPER_CLOCK_TB_PASS");
        $finish;
    end
endmodule

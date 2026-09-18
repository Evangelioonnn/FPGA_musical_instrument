`timescale 1ns/1ps

// Receiver models the datasheet: latch the last 16 rising-edge bits when
// WS changes. It neither reads DUT counters nor duplicates its bit indexing.
module pt8211_checker #(
    parameter PATTERN_TEST = 0
)(input wire bck, ws, din, pa_en);
    reg [15:0] shift = 0;
    reg [15:0] expected;
    integer word_clocks = 0;
    integer frames = 0;
    integer half_cycles;
    integer last_positive_frame = -1;
    integer first_positive_frame = -1;
    integer positive_edges = 0;
    reg [15:0] previous_right = 0;
    time last_bck_edge = 0;
    time last_change = 0;
    real measured_hz;

    function [15:0] pattern;
        input integer frame_no;
        input integer left_channel;
        begin
            if (left_channel) pattern = 16'hA53D ^ (frame_no * 17);
            else pattern = 16'h36C7 ^ (frame_no * 31);
        end
    endfunction

    always @(bck) begin
        if ($time > 0) begin
            if (last_bck_edge != 0 && $time-last_bck_edge != 260)
                $fatal(1, "BCK half period wrong at %0t", $time);
            last_bck_edge = $time;
        end
    end
    always @(din or ws) begin
        if ($time > 0 && bck !== 1'b0)
            $fatal(1, "DIN/WS changed while BCK high");
        last_change = $time;
    end
    always @(posedge bck) begin
        if (pa_en !== 1'b0 || ^{bck,ws,din} === 1'bx)
            $fatal(1, "Unknown serial output or PA disabled");
        if ($time > 260 && $time-last_change < 260)
            $fatal(1, "Insufficient serial setup time");
        // Selected implementation sends zero in the four leading slots.
        if (word_clocks < 4 && din !== 1'b0)
            $fatal(1, "Nonzero padding");
        shift = {shift[14:0], din};
        word_clocks = word_clocks + 1;
    end
    always @(ws) begin
        if ($time > 0) begin
            #1;
            if (word_clocks != 20)
                $fatal(1, "Expected 20 clocks/word, got %0d", word_clocks);
            // New WS=1 closes a RIGHT word; new WS=0 closes a LEFT word.
            if (PATTERN_TEST) expected = pattern(frames, ws == 0);
            else begin
                // Independent physical-frequency reference (no DUT phase).
                half_cycles = $rtoi(frames * 2.0 * 440.0 * 1040.0 / 50000000.0);
                expected = (half_cycles % 2) ? 16'hFE00 : 16'h0200;
            end
            if (shift !== expected)
                $fatal(1, "mode=%0d frame=%0d completed_left=%0d got=%h expected=%h",
                    PATTERN_TEST, frames, ws == 0, shift, expected);
            if (ws && !PATTERN_TEST) begin
                if (shift == 16'h0200 && previous_right == 16'hFE00) begin
                    if (last_positive_frame >= 0 &&
                        (frames-last_positive_frame < 109 || frames-last_positive_frame > 110))
                        $fatal(1, "Tone period out of range");
                    if (first_positive_frame < 0) first_positive_frame = frames;
                    last_positive_frame = frames;
                    positive_edges = positive_edges + 1;
                end
                previous_right = shift;
            end
            if (!ws) frames = frames + 1;
            word_clocks = 0;
            shift = 0;
        end
    end
    initial begin
        #25000000;
        if (frames != 1201) $fatal(1, "Frame count wrong: %0d", frames);
        if (!PATTERN_TEST) begin
            if (positive_edges < 9) $fatal(1, "Too few tone cycles");
            measured_hz = (positive_edges-1) * (50000000.0/1040.0) /
                (last_positive_frame-first_positive_frame);
            if (measured_hz < 439.0 || measured_hz > 441.0)
                $fatal(1, "Wrong frequency %f", measured_hz);
            $display("TONE_CHECK_PASS frames=%0d measured_hz=%f", frames, measured_hz);
        end else $display("PATTERN_CHECK_PASS frames=%0d", frames);
    end
endmodule

module audio_probe_tb;
    reg sys_clk = 0;
    wire bck, ws, din, pa_en;
    wire test_bck, test_ws, test_din, test_pa_en;
    integer stimulus_frame = 0;
    reg [15:0] test_left = 16'hA53D;
    reg [15:0] test_right = 16'h36C7;
    always #10 sys_clk = ~sys_clk;
    audio_probe_top dut(sys_clk, bck, ws, din, pa_en);
    audio_probe_top serializer_test(sys_clk, test_bck, test_ws, test_din, test_pa_en);
    pt8211_checker normal_checker(bck, ws, din, pa_en);
    pt8211_checker #(.PATTERN_TEST(1)) pattern_checker(test_bck, test_ws, test_din, test_pa_en);

    // Test-only sample injection distinguishes channels and exercises sign,
    // LSB, MSB and intermediate bits; production DUT above runs unmodified.
    initial begin
        force serializer_test.left_sample = test_left;
        force serializer_test.right_sample = test_right;
    end
    always @(negedge test_ws) begin
        if ($time > 0) begin
            #2;
            stimulus_frame = stimulus_frame + 1;
            test_left = 16'hA53D ^ (stimulus_frame * 17);
            test_right = 16'h36C7 ^ (stimulus_frame * 31);
        end
    end
    initial begin
        #25000010;
        $display("AUDIO_PROBE_TB_PASS");
        $finish;
    end
endmodule

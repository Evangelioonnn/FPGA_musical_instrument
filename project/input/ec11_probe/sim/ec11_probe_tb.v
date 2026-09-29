`timescale 1ns/1ps
module ec11_probe_tb;
    reg sys_clk = 0;
    reg enc_a = 1, enc_b = 1;
    wire hp_bck, hp_ws, hp_din, pa_en;
    integer events = 0, ups = 0, downs = 0;
    integer expected_note = 69;
    reg previous_valid = 0;
    reg [31:0] expected_phase_step;
    integer frames = 0, word_clocks = 0;
    reg [15:0] serial_shift = 0;
    reg signed [15:0] right_word = 0, left_word = 0;
    reg signed [15:0] previous_word = 0;
    integer measure_enable = 0, crossings = 0;
    integer first_cross = 0, last_cross = 0;
    integer saved_events, k;
    real frequency;
    time last_bck_edge = 0;
    always #10 sys_clk = ~sys_clk;

    // Real 50 MHz, 50 us sample interval and 100 us A/B stability window.
    ec11_audio_probe_top dut(sys_clk, enc_a, enc_b, hp_bck, hp_ws, hp_din, pa_en);

    // Independent musical pitch reference, not copied from note_table.
    function [31:0] musical_step;
        input integer midi;
        real increment;
        begin
            increment = 440.0 * (2.0 ** ((midi-69)/12.0)) *
                1040.0 / 50000000.0 * 4294967296.0;
            musical_step = $rtoi(increment + 0.5);
        end
    endfunction

    always @(posedge sys_clk) begin
        if (!dut.rst) begin
            if (dut.step_valid) begin
                if (previous_valid) $fatal(1, "step pulse lasted multiple clocks");
                events = events + 1;
                if (dut.step == 1) begin
                    ups = ups + 1;
                    if (expected_note < 84) expected_note = expected_note + 1;
                end else if (dut.step == -1) begin
                    downs = downs + 1;
                    if (expected_note > 48) expected_note = expected_note - 1;
                end else $fatal(1, "invalid step value");
            end
            previous_valid = dut.step_valid;
            expected_phase_step = musical_step(expected_note);
            #1;
            if (dut.note !== expected_note || dut.voice.step_hold !== expected_phase_step)
                $fatal(1, "actual DDS retune mismatch note=%0d expected=%0d step=%h expected=%h",
                    dut.note, expected_note, dut.voice.step_hold, expected_phase_step);
            if (pa_en !== 0 || ^{hp_bck,hp_ws,hp_din} === 1'bx)
                $fatal(1, "unknown output or disabled amplifier");
        end
    end

    // PT8211 reference receiver: retain last 16 bits at a WS transition.
    // Observe actual top-level pins, independent of transmitter bit indices.
    always @(hp_bck) if ($time > 1000) begin
        if (last_bck_edge != 0 && $time-last_bck_edge != 260)
            $fatal(1, "BCK half-period changed");
        last_bck_edge = $time;
    end
    always @(hp_din or hp_ws) if ($time > 1000 && hp_bck !== 0)
        $fatal(1, "data/WS changed while BCK high");
    always @(posedge hp_bck) begin
        serial_shift = {serial_shift[14:0], hp_din};
        word_clocks = word_clocks + 1;
    end
    always @(hp_ws) if ($time > 1000) begin
        if (word_clocks != 20) $fatal(1, "not 20 BCK per channel");
        if (hp_ws) right_word = serial_shift;
        else begin
            left_word = serial_shift;
            if (left_word !== right_word) $fatal(1, "left/right sample mismatch");
            if (left_word < -512 || left_word > 511) $fatal(1, "monitor gain changed");
            if (measure_enable && previous_word < 0 && left_word >= 0) begin
                if (crossings == 0) first_cross = frames;
                last_cross = frames;
                crossings = crossings + 1;
            end
            previous_word = left_word;
            frames = frames + 1;
        end
        word_clocks = 0;
    end

    task hold_ab;
        input [1:0] ab;
        begin
            @(negedge sys_clk);
            {enc_a,enc_b} = ab;
            #300000;
        end
    endtask
    task forward_cycle;
        begin hold_ab(2'b10); hold_ab(2'b00); hold_ab(2'b01); hold_ab(2'b11); end
    endtask
    task backward_cycle;
        begin hold_ab(2'b01); hold_ab(2'b00); hold_ab(2'b10); hold_ab(2'b11); end
    endtask
    task measure_pitch;
        input real expected_hz;
        begin
            #3000000;
            @(negedge sys_clk);
            crossings = 0;
            measure_enable = 1;
            #30000000;
            measure_enable = 0;
            if (crossings < 8) $fatal(1, "too few audio cycles");
            frequency = (crossings-1) * (50000000.0/1040.0) / (last_cross-first_cross);
            if (frequency < expected_hz*0.995 || frequency > expected_hz*1.005)
                $fatal(1, "serial PCM pitch mismatch: %f vs %f", frequency, expected_hz);
            $display("PITCH_PASS expected=%f measured=%f frames=%0d", expected_hz, frequency, frames);
        end
    endtask

    initial begin
        #1000000;
        if (events != 0) $fatal(1, "startup generated a rotation event");
        measure_pitch(440.0);
        forward_cycle;
        if (events != 1 || dut.note != 70) $fatal(1, "forward cycle failed");
        measure_pitch(466.1637615);
        backward_cycle;
        if (events != 2 || dut.note != 69) $fatal(1, "backward cycle failed");
        measure_pitch(440.0);

        // A 20 us glitch is shorter than the input stability window.
        @(negedge sys_clk); enc_b = 0; #20000;
        @(negedge sys_clk); enc_b = 1; #300000;
        if (events != 2) $fatal(1, "short glitch generated step");
        // Stable contact bounce reverses before completing a quadrature cycle.
        hold_ab(2'b10); hold_ab(2'b11); hold_ab(2'b10);
        hold_ab(2'b00); hold_ab(2'b01); hold_ab(2'b11);
        if (events != 3 || dut.note != 70) $fatal(1, "contact bounce double counted");
        // Simultaneous two-bit change is rejected; following legal cycle works.
        hold_ab(2'b00); hold_ab(2'b11);
        if (events != 3) $fatal(1, "illegal jump counted");
        backward_cycle;
        if (events != 4 || dut.note != 69) $fatal(1, "decoder failed to recover");

        for (k=0;k<18;k=k+1) forward_cycle;
        if (dut.note != 84) $fatal(1, "upper clamp failed");
        for (k=0;k<40;k=k+1) backward_cycle;
        if (dut.note != 48) $fatal(1, "lower clamp failed");
        for (k=0;k<21;k=k+1) forward_cycle;
        if (dut.note != 69 || events != 83 || ups != 41 || downs != 42)
            $fatal(1, "cycle count/final note mismatch");
        saved_events = events;
        #1000000;
        if (events != saved_events) $fatal(1, "stationary input generated step");
        $display("EC11_PROBE_TB_PASS events=%0d up=%0d down=%0d note=%0d frames=%0d",
            events, ups, downs, dut.note, frames);
        $finish;
    end
    initial begin #500000000; $fatal(1, "test timed out"); end
endmodule

`timescale 1ns/1ps
module looper_drum_engine_tb;
    localparam VOICES = 8;
    reg [1:0] strike_layer=0,flush_layer=0;reg flush_whole_track=1;
    reg [2:0] strike_track=4;
    reg [67:0] track_gains={4{17'd65536}};
    reg flush_all=0,flush_valid=0;reg [1:0] flush_track=0;
    reg clk = 0;
    always #10 clk = !clk;
    reg rst = 1;
    reg sample_ce = 0;
    reg strike_valid = 0;
    wire strike_ready,strike_accepted;
    reg [3:0] strike_pad = 0;
    reg [7:0] strike_velocity = 8'd127;
    wire sample_valid;
    wire signed [19:0] sample;
    wire [VOICES-1:0] active;
    wire [VOICES*4-1:0] active_pads;
    wire [31:0] late_strikes, rejected_strikes;
    integer sample_count = 0;
    integer nonzero_samples = 0;
    integer peak = 0;
    integer current_abs;
    integer i;
    integer reject_before;
    integer open_index;

    looper_drum_engine #(.VOICES(VOICES)) dut(.*);

    always @(posedge clk) begin
        if (sample_valid) begin
            sample_count = sample_count + 1;
            current_abs = sample < 0 ? -sample : sample;
            if (current_abs != 0) nonzero_samples = nonzero_samples + 1;
            if (current_abs > peak) peak = current_abs;
        end
    end

    task hit;
        input [3:0] drum_pad;
        input [7:0] velocity;
        integer timeout;
        begin
            @(negedge clk);
            strike_pad = drum_pad;
            strike_velocity = velocity;
            strike_valid = 1;
            timeout = 0;
            while (!strike_ready && timeout < 30) begin
                @(negedge clk);
                timeout = timeout + 1;
            end
            if (!strike_ready) $fatal(1, "strike-ready timeout pad=%0d", drum_pad);
            @(negedge clk);
            strike_valid = 0;
        end
    endtask

    task render_samples;
        input integer count;
        integer n;
        begin
            for (n = 0; n < count; n = n + 1) begin
                @(negedge clk);
                sample_ce = 1;
                @(negedge clk);
                sample_ce = 0;
                repeat (62) @(negedge clk);
            end
        end
    endtask

    initial begin
        repeat (3) @(negedge clk);
        rst = 0;
        hit(4'd0, 8'd127);
        render_samples(128);
        if (sample_count < 128 || peak == 0 || late_strikes != 0)
            $fatal(1, "kick rendering invalid count=%0d peak=%0d late=%0d",
                sample_count, peak, late_strikes);

        hit(4'd1, 8'd100);
        hit(4'd2, 8'd96);
        hit(4'd3, 8'd96);
        hit(4'd6, 8'd110);
        open_index = -1;
        for (i = 0; i < VOICES; i = i + 1)
            if (active[i] && active_pads[i*4 +: 4] == 4'd6) open_index = i;
        if (open_index < 0)
            $fatal(1, "open hat was not allocated to the available slot");
        hit(4'd5, 8'd110);
        if (!dut.forced_release[open_index] || active_pads[open_index*4 +: 4] != 4'd6)
            $fatal(1, "closed hat must preserve a fading open-hat tail when a spare slot exists");

        hit(4'd7, 8'd96);
        hit(4'd8, 8'd96);
        hit(4'd9, 8'd96);
        reject_before = rejected_strikes;
        @(negedge clk);
        strike_pad = 4'd15;
        strike_valid = 1;
        if (!strike_ready) $fatal(1, "full drum pool must consume and reject without deadlock");
        @(negedge clk);
        strike_valid = 0;
        if (rejected_strikes != reject_before + 1)
            $fatal(1, "full drum pool rejection counter mismatch");

        render_samples(512);
        if (nonzero_samples < 16 || peak < 100 || late_strikes != 0)
            $fatal(1, "drum mix failed nonzero=%0d peak=%0d late=%0d",
                nonzero_samples, peak, late_strikes);
        render_samples(100000);
        for (i = 0; i < VOICES; i = i + 1)
            if (active[i]) $fatal(1, "drum voice %0d did not decay pad=%0d level=%0d decay_shift=%0d",
                i, active_pads[i*4 +: 4], dut.level[i], dut.decay_shift[i]);
        hit(4'd4, 8'd96);
        hit(4'd9, 8'd96);
        render_samples(128);
        if (peak == 0 || late_strikes != 0)
            $fatal(1, "higher tom render failed");
        render_samples(100000);
        for (i = 0; i < VOICES; i = i + 1)
            if (active[i]) $fatal(1, "second drum group voice %0d did not decay", i);
        if (sample_count != 200768)
            $fatal(1, "sample frame count mismatch %0d", sample_count);
        $display("LOOPER_DRUM_ENGINE_TB_PASS voices=8 shared_sine=1 offline_CE64 choke=closed_hat overflow=1 tail=cleared");
        $finish;
    end
endmodule

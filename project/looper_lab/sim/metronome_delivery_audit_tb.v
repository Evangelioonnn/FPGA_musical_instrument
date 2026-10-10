`timescale 1ns/1ps
// Reproduce the existing top's sample -> registered beat -> registered click
// timing. This audit succeeds only when it exposes the current delivery bug.
module metronome_delivery_audit_tb;
    reg clk=0;
    always #10 clk=~clk;
    reg rst=1, sample_ce=0, beat_pulse=0, start_req=0;
    wire click, accent, ready;
    wire [7:0] active;
    integer clicks=0, accepted=0;
    looper_transport transport(
        .clk(clk),.rst(rst),.tick_pulse(1'b0),.beat_pulse(beat_pulse),
        .bar_pulse(1'b0),.tick_in_beat(7'd0),.beat_in_bar(3'd0),
        .start_req(start_req),.stop_req(1'b0),.record_req(1'b0),
        .beats_per_bar(3'd4),.loop_bars(3'd1),.metronome_enable(1'b1),
        .metronome_click(click),.metronome_accent(accent),
        .transport_run(),.count_in(),.playing(),.recording(),.record_armed(),
        .record_start_pulse(),.record_done_pulse(),.loop_wrap_pulse(),
        .stop_pulse(),.loop_tick(),.loop_number());
    looper_drum_engine #(.VOICES(8)) drum(
        .clk(clk),.rst(rst),.sample_ce(sample_ce),.strike_valid(click),
        .strike_ready(ready),.strike_pad(4'd5),.strike_velocity(8'd120),
        .active(active),.sample_valid(),.sample(),.active_pads(),
        .late_strikes(),.rejected_strikes());
    always @(posedge clk) if(!rst) begin
        if(click) clicks=clicks+1;
        if(click && ready) accepted=accepted+1;
    end
    initial begin
        repeat(3) @(negedge clk);
        rst=0; start_req=1;
        @(negedge clk); start_req=0;
        repeat(4) @(negedge clk);
        // looper_clock registers beat_pulse on the sample_ce edge.
        sample_ce=1;
        @(negedge clk); sample_ce=0; beat_pulse=1;
        @(negedge clk); beat_pulse=0;
        repeat(25) @(negedge clk);
        if(clicks!=1 || accepted!=0 || active!=0)
            $fatal(1,"Unexpected audit result clicks=%0d accepted=%0d active=%h",clicks,accepted,active);
        $display("KNOWN_DEFECT_REPRODUCED metronome_clicks=1 accepted_drum_hits=0");
        $finish;
    end
endmodule

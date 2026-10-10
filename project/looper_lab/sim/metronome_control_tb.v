`timescale 1ns/1ps
module metronome_control_tb;
    reg clk=0;always #10 clk=~clk;
    reg rst=1,run=0,restart=0,enable=1;reg [7:0] bpm=120;reg [2:0] beats_per_bar=3;
    reg [1:0] divider=0;wire sample_ce=divider==3;
    wire tick_pulse,beat_pulse,bar_pulse;wire [6:0] tick_in_beat;
    wire [2:0] beat_in_bar;wire [31:0] frame_index;
    wire valid,onset;wire signed [15:0] sample;wire [31:0] delivered;
    looper_clock clock_i(.*);
    metronome_click click_i(.clk(clk),.rst(rst),.sample_ce(sample_ce),.trigger(beat_pulse),
        .accent(beat_in_bar==0),.enable(enable),.gain_q8(9'd256),.valid(valid),.sample(sample),.onset(onset),.delivered(delivered));
    always @(negedge clk) if(rst) divider=0;else divider=divider+1'b1;
    integer frames=0,beats=0,last_frame=0,interval=0;reg [31:0] saved_delivered;
    always @(posedge clk) begin
        if(!rst && sample_ce) frames=frames+1;
        #1;if(!rst && beat_pulse) begin beats=beats+1;interval=frames-last_frame;last_frame=frames;end
    end
    initial begin
        repeat(3) @(negedge clk);rst=0;repeat(4) @(negedge clk);run=1;
        wait(beats==2);repeat(16) @(negedge clk);saved_delivered=delivered;
        enable=0;bpm=240;
        // The active tempo changes at the next beat, not at the request edge.
        wait(beats==3);if(interval<24038 || interval>24039) $fatal(1,"tempo applied inside beat");
        wait(beats==4);if(interval<12019 || interval>12020) $fatal(1,"240 BPM boundary interval");
        if(delivered!=saved_delivered) $fatal(1,"muted click produced onset");
        repeat(16) @(negedge clk);enable=1;wait(beats==5);repeat(16) @(negedge clk);
        if(delivered!=saved_delivered+1 || beat_in_bar!=1) $fatal(1,"audible toggle reset phase or lost click");
        @(negedge clk);run=0;repeat(16) @(negedge clk);
        if(sample!==0) $display("NOTE click tail preserved when only timebase stops");
        run=1;wait(beats==6);
        if(beat_in_bar!=0 || tick_in_beat!=0) $fatal(1,"restart not aligned");
        repeat(16) @(negedge clk);enable=0;repeat(16) @(negedge clk);
        if(sample!==0) $fatal(1,"audible disable not zero");
        $display("METRONOME_CONTROL_TB_PASS enable=phase_continuous tempo=next_beat restart=accented_zero mute=PCM_zero");$finish;
    end
    initial begin #10000000;$fatal(1,"metronome control watchdog");end
endmodule

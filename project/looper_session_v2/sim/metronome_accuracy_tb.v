`timescale 1ns/1ps
module metronome_accuracy_tb #(parameter CADENCE=4,SWEEP=1);
    reg clk=0;always #10 clk=~clk;
    reg rst=1,run=0,restart=0,enable=1;
    reg [7:0] bpm=120;reg [2:0] beats_per_bar=4;
    integer cadence_count=0,frames=0,beats=0,onsets=0,last_beat_frame=0;
    wire sample_ce=cadence_count==CADENCE-1;
    wire tick_pulse,beat_pulse,bar_pulse;
    wire [6:0] tick_in_beat;wire [2:0] beat_in_bar;wire [31:0] frame_index;
    wire valid,onset;wire signed [15:0] sample;wire [31:0] delivered;
    looper_clock clock_i(.applied_bpm(),.*);
    metronome_click click_i(.clk(clk),.rst(rst),.sample_ce(sample_ce),.trigger(beat_pulse),
        .accent(beat_in_bar==0),.enable(enable),.gain_q8(9'd96),
        .valid(valid),.sample(sample),.onset(onset),.delivered(delivered));
    integer origin,expected,seen_nonzero=0,click_due=0;
    real ideal;
    always @(negedge clk) begin
        if(rst) cadence_count=0;else cadence_count=(cadence_count+1)%CADENCE;
    end
    always @(posedge clk) begin
        if(rst) begin frames=0;beats=0;onsets=0;origin=0;seen_nonzero=0;click_due=0;end
        else begin
            if(sample_ce) frames=frames+1;
            #1;
            if(beat_pulse) begin
                if(beats==0) origin=frames;
                else begin
                    ideal=beats*3000000000.0/(bpm*1040.0);
                    expected=$rtoi($ceil(ideal));
                    if(frames-origin!=expected) $fatal(1,"tempo=%0d beat=%0d frame=%0d expected=%0d",bpm,beats,frames-origin,expected);
                end
                if(beat_in_bar!=beats%beats_per_bar) $fatal(1,"accent/bar position mismatch");
                beats=beats+1;last_beat_frame=frames;
            end
            if(onset) begin onsets=onsets+1;click_due=frames;end
            if(valid && sample!=0 && click_due!=0) begin seen_nonzero=seen_nonzero+1;click_due=0;end
            if(click_due!=0 && frames-click_due>2) $fatal(1,"beat click absent from PCM");
            if(sample>7680 || sample< -7680) $fatal(1,"click bound");
        end
    end
    task check;
        input integer tempo,meter;
        begin
            @(negedge clk);rst=1;run=0;bpm=tempo;beats_per_bar=meter;
            repeat(4) @(negedge clk);rst=0;
            repeat(4) @(negedge clk);run=1;
            wait(beats>=3);repeat(CADENCE*5) @(negedge clk);
            if(onsets!=beats || seen_nonzero!=beats) $fatal(1,"delivery count beat=%0d onset=%0d pcm=%0d",beats,onsets,seen_nonzero);
            run=0;
        end
    endtask
    integer t;
    initial begin
        if(SWEEP) begin for(t=40;t<=240;t=t+1) check(t,4);end
        else begin check(40,2);check(120,3);check(240,4);end
        $display("METRONOME_ACCURACY_TB_PASS cadence=%0d sweep=%0d each_beat_error<=1_sample PCM_clicks=complete",CADENCE,SWEEP);
        $finish;
    end
    initial begin #1.0e13;$fatal(1,"metronome watchdog");end
endmodule

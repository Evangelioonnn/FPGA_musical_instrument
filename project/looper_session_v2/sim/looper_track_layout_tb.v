`timescale 1ns/1ps
module looper_track_layout_tb;
    reg clk=0;always #10 clk=~clk;
    reg rst=1,play_enable=0,playback_reset=0,loop_wrap=0;
    reg [11:0] loop_tick=0,loop_length=384,record_tick=0;
    reg [1:0] quantize_mode=0,record_lane=0,undo_lane=0;
    reg record_start=0,record_event_valid=0,record_busy=0,record_cancel=0,clear_valid=0,undo_valid=0;
    reg [1:0] clear_track=0,record_event_kind=2;
    reg [135:0] record_patch=6;reg [6:0] record_note=0;reg [15:0] record_note_id=1;reg [7:0] record_velocity=255;
    wire record_event_ready,recording,record_commit,record_overflow,record_error,removed_valid;
    wire [1:0] removed_track,removed_layer;wire [7:0] recorded_events;
    wire [3:0] layer_valid;wire [543:0] layer_patches;
    wire event_valid;reg event_ready=1;wire event_off,event_drum;
    wire [1:0] event_track,event_layer;wire [11:0] event_tick;wire [6:0] event_note;
    wire [15:0] event_note_id;wire [7:0] event_velocity;wire [2:0] event_preset;
    wire [135:0] event_patch;wire [31:0] event_late_count;
    looper_event_store #(.LANES(4),.LAYERS_PER_TRACK(1),.LANE_W(2)) dut(.edit_busy(),.event_control(),.*);
    reg [3:0] seen=0;integer i;
    always @(posedge clk) if(event_valid && event_ready) begin
        if(!event_drum || event_layer!=0 || event_note!=event_track || event_preset!=6 || seen[event_track]) $fatal(1,"four-track mapping incorrect");
        seen[event_track]=1;
    end
    initial begin
        repeat(3) @(negedge clk);rst=0;
        for(i=0;i<4;i=i+1) begin
            @(negedge clk);record_lane=i;record_note=i;record_start=1;
            @(negedge clk);record_start=0;record_event_valid=1;#1;
            while(!record_event_ready) @(negedge clk);
            @(negedge clk);record_event_valid=0;loop_wrap=1;
            @(negedge clk);loop_wrap=0;wait(record_commit);@(negedge clk);
        end
        play_enable=1;wait(seen==15);
        @(negedge clk);clear_valid=1;clear_track=2;@(negedge clk);clear_valid=0;repeat(4) @(negedge clk);
        if(layer_valid!=4'b1011) $fatal(1,"track clear crossed track boundary");
        @(negedge clk);record_lane=2;record_start=1;@(negedge clk);record_start=0;
        record_cancel=1;@(negedge clk);record_cancel=0;
        if(recording || layer_valid[2]) $fatal(1,"cancel committed a partial take");
        $display("LOOPER_TRACK_LAYOUT_TB_PASS four_lanes=four_tracks clear=selected cancel=atomic");$finish;
    end
    initial begin #200000;$fatal(1,"layout watchdog");end
endmodule

`timescale 1ns/1ps
module looper_boundary_tb;
    reg clk=0;always #10 clk=~clk;
    reg rst=1,play_enable=0,playback_reset=0,loop_wrap=0;
    reg [11:0] loop_tick=383,loop_length=384,record_tick=383;
    reg [1:0] quantize_mode=2,record_event_kind=0,clear_track=0;
    reg record_start=0,record_event_valid=0,record_busy=0,record_cancel=0,clear_valid=0,undo_valid=0;
    reg [3:0] record_lane=15,undo_lane=0;
    reg [135:0] record_patch=5;reg [6:0] record_note=60;reg [15:0] record_note_id=23;reg [7:0] record_velocity=255;
    wire record_event_ready,recording,record_commit,record_overflow,record_error,removed_valid;
    wire [1:0] removed_track,removed_layer;wire [7:0] recorded_events;wire [15:0] layer_valid;
    wire event_valid;reg event_ready=1;wire event_off,event_drum;
    wire [1:0] event_track,event_layer;wire [11:0] event_tick;wire [6:0] event_note;
    wire [15:0] event_note_id;wire [7:0] event_velocity;wire [2:0] event_preset;
    wire [135:0] event_patch;wire [31:0] event_late_count;integer seen=0;
    looper_event_store #(.RECORD_TICK_INPUT(1)) dut(.edit_busy(),.event_control(),.*);
    always @(posedge clk) if(event_valid && event_ready) begin
        if(event_track!=3 || event_layer!=3 || event_tick!=383 || event_note_id!=23 || event_off!=(seen==1)) $fatal(1,"last-tick identity/order mismatch");
        seen=seen+1;
    end
    initial begin
        repeat(3) @(negedge clk);rst=0;
        record_start=1;@(negedge clk);record_start=0;
        record_event_valid=1;record_busy=1;
        // Deliberately wrap while the recorder's quantizer is busy. Raw event
        // timestamp remains 383 while the playback position becomes zero.
        @(negedge clk);loop_wrap=1;loop_tick=0;
        @(negedge clk);loop_wrap=0;
        #1;while(!record_event_ready) @(negedge clk);
        @(negedge clk);record_event_valid=0;record_busy=0;
        wait(record_commit);@(negedge clk);
        if(!layer_valid[15] || record_overflow || recording) $fatal(1,"boundary take did not commit");
        loop_tick=383;play_enable=1;wait(seen==2);
        if(record_error) $fatal(1,"boundary error");
        $display("LOOPER_BOUNDARY_TB_PASS raw_stamp=383 pending_drained_before_close on_off_order=preserved track3_layer3=correct");$finish;
    end
    initial begin #200000;$fatal(1,"boundary watchdog");end
endmodule

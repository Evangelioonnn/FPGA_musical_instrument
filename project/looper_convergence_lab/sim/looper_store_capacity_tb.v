`timescale 1ns/1ps
module looper_store_capacity_tb #(parameter SERIAL=0);
    reg clk=0;always #10 clk=~clk;
    reg rst=1,play_enable=0,playback_reset=0,loop_wrap=0;
    reg [11:0] loop_tick=0,loop_length=384,record_tick=0;
    reg [1:0] quantize_mode=0,record_event_kind=0,clear_track=0;
    reg record_start=0,record_event_valid=0,record_busy=0,record_cancel=0,clear_valid=0,undo_valid=0;
    reg [3:0] record_lane=0,undo_lane=0;
    reg [135:0] record_patch=0;reg [6:0] record_note=60;reg [15:0] record_note_id=1;reg [7:0] record_velocity=255;
    wire record_event_ready,recording,record_commit,record_overflow,record_error,removed_valid;
    wire [1:0] removed_track,removed_layer;wire [7:0] recorded_events;wire [15:0] layer_valid;
    wire event_valid;reg event_ready=1;wire event_off,event_drum;
    wire [1:0] event_track,event_layer;wire [11:0] event_tick;wire [6:0] event_note;
    wire [15:0] event_note_id;wire [7:0] event_velocity;wire [2:0] event_preset;
    wire [135:0] event_patch;wire [31:0] event_late_count;
    looper_event_store #(.SERIAL_NOTES(SERIAL)) dut(.event_control(),.*);
    integer i,j,k,accepted=0,per_lane[0:15];reg [31:0] rng=32'h57ab019d;
    always @(negedge clk) if(play_enable) begin
        rng={rng[30:0],rng[31]^rng[21]^rng[1]^rng[0]};event_ready=rng[0] || rng[1];
    end
    always @(posedge clk) if(event_valid && event_ready) begin
        k=event_track*4+event_layer;
        if(event_tick!=per_lane[k] || event_note_id!=1+per_lane[k]/2 || event_off!=per_lane[k]%2 ||
            event_note!=36+k || event_patch[14:3]!=k || event_preset!=0) $fatal(1,"full store replay mismatch lane=%0d ordinal=%0d tick=%0d",k,per_lane[k],event_tick);
        per_lane[k]=per_lane[k]+1;accepted=accepted+1;
    end
    initial begin
        for(i=0;i<16;i=i+1) per_lane[i]=0;
        repeat(3) @(negedge clk);rst=0;
        for(i=0;i<16;i=i+1) begin
            @(negedge clk);record_lane=i;record_patch=0;record_patch[14:3]=i;record_start=1;
            @(negedge clk);record_start=0;
            for(j=0;j<128;j=j+1) begin
                @(negedge clk);loop_tick=j;record_note=36+i;record_note_id=1+j/2;record_event_kind=j%2;record_event_valid=1;#1;
                while(!record_event_ready) @(negedge clk);
                @(negedge clk);record_event_valid=0;
            end
            loop_wrap=1;@(negedge clk);loop_wrap=0;wait(record_commit);@(negedge clk);
            if(record_overflow || recording) $fatal(1,"full layer commit failed");
        end
        if(layer_valid!=16'hffff) $fatal(1,"missing layer");
        loop_tick=383;play_enable=1;wait(accepted==2048);repeat(100) @(negedge clk);
        for(i=0;i<16;i=i+1) if(per_lane[i]!=128) $fatal(1,"lane total %0d",i);
        if(event_valid) $fatal(1,"duplicate events beyond lane end");
        $display("LOOPER_STORE_CAPACITY_TB_PASS serial=%0d tracks=4 layers=4 events_per_layer=128 replayed=2048 random_backpressure=stable",SERIAL);$finish;
    end
    initial begin #10000000;$fatal(1,"capacity watchdog accepted=%0d",accepted);end
endmodule

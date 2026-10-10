`timescale 1ns/1ps
module looper_controls_tb;
    reg clk=0;always #10 clk=~clk;
    reg rst=1,sample_ce=1,transport_run=0,host_ready=1,has_layers=0;
    reg [2:0] down=0,released=0;reg step_valid=0;reg signed [1:0] step=1;
    wire host_valid;wire [4:0] host_addr;wire [31:0] host_value;
    wire [2:0] preset,page,mode,meter,bars;wire [1:0] track,quantize;
    wire start_req,stop_req,record_req,undo_req,clear_req,met_enable,overflow;
    wire [7:0] bpm;wire [8:0] click_gain;wire [67:0] track_gains;wire [3:0] muted;
    looper_controls #(.LONG_CYCLES(20)) dut(.ui_valid(1'b0),.ui_ready(),.ui_addr(8'd0),.ui_value(32'd0),.ui_recording(1'b0),.ui_armed(1'b0),.ui_count_in(1'b0),.ui_busy(1'b0),.ui_flushing(1'b0),.ui_layers(16'd0),.menu_drums_commit(1'b0),.ui_ack(),.ui_accepted(),.ui_applied(),.ui_reason(),.ui_result(),.sync_valid(1'b0),.sync_remote(1'b0),.sync_addr(5'd0),.sync_value(32'd0),.mixer_valid(1'b0),.mixer_data(68'd0),.mixer_ready(),.mixer_targets(),.mixer_invalidate(),.*);
    task key;
        input integer k;
        begin @(negedge clk);released=1<<k;@(negedge clk);released=0;repeat(3) @(negedge clk);end
    endtask
    task turn;
        input integer n;input positive;integer i;
        begin for(i=0;i<n;i=i+1) begin @(negedge clk);step=positive ? 1 : -1;step_valid=1;
            @(negedge clk);step_valid=0;repeat(3) @(negedge clk);end end
    endtask
    integer i;
    initial begin
        repeat(3) @(negedge clk);rst=0;
        for(i=0;i<6;i=i+1) key(0);
        if(preset!=0) $fatal(1,"six-entry menu cycle");
        turn(40,0);if(dut.master!=0) $fatal(1,"master lower clamp");
        turn(40,1);if(dut.master!=65536) $fatal(1,"master upper clamp");
        key(2);down[1]=1;turn(10,1);down[1]=0;released[1]=1;@(negedge clk);released=0;
        if(bars!=4 || record_req) $fatal(1,"bars chord accidentally recorded");
        has_layers=1;down[1]=1;turn(1,0);down[1]=0;
        if(bars!=4) $fatal(1,"stored loop length changed");has_layers=0;
        key(2);key(1);key(1);key(0);repeat(520) @(negedge clk);
        if(track!=2 || track_gains[34+:17]!=0 || track_gains[0+:17]!=65536 || dut.master!=65536) $fatal(1,"relative mixer changed master or other track");
        key(2);turn(200,0);if(bpm!=40) $fatal(1,"BPM min");
        turn(220,1);if(bpm!=240) $fatal(1,"BPM max");
        key(1);turn(1,0);if(meter!=3) $fatal(1,"meter option");
        transport_run=1;turn(1,0);if(meter!=3) $fatal(1,"meter changed within loop");
        transport_run=0;has_layers=1;turn(1,0);if(meter!=3) $fatal(1,"stored loop meter changed");has_layers=0;
        key(0);if(!met_enable) $fatal(1,"metronome independent enable");
        key(2);key(0);if(preset!=5) $fatal(1,"custom page timbre");
        key(1);turn(1,1);if(dut.raw[1]!=1088 || dut.raw[0]!=4095) $fatal(1,"harmonic editing channel");
        if(overflow) $fatal(1,"human control rate overflow");
        $display("LOOPER_CONTROLS_TB_PASS menu=0_2_3_4_5_6 master=0..65536 mixer=independent bpm=40..240 bars=1..4 custom=editable");$finish;
    end
endmodule

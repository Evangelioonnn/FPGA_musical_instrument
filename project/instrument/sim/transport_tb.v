`timescale 1ns/1ps
// Datasheet receiver: latch the LAST 16 rising-edge bits at the WS boundary.
module serial_checker(
    input wire clk,rst,ce,bck,ws,din,
    input wire signed [15:0] source_left,source_right
);
    reg [15:0] left_queue[0:4095],right_queue[0:4095];
    reg [15:0] shift=0,expected;
    integer loaded=0,frames=0,bits=0;
    time edge_time=0,change_time=0,last_ce=0;
    always @(posedge clk) if(!rst && ce) begin
        if(last_ce!=0 && $time-last_ce!=20800) $fatal(1,"Wrong frame cadence");
        last_ce=$time;
        left_queue[loaded]=source_left;
        right_queue[loaded]=source_right;
        loaded=loaded+1;
    end
    always @(bck) if(!rst && $time>0) begin
        if(edge_time!=0 && $time-edge_time!=260) $fatal(1,"BCK half period");
        edge_time=$time;
    end
    always @(ws or din) if(!rst && $time>0) begin
        if(bck!==0) $fatal(1,"Data/WS changed at unsafe edge");
        change_time=$time;
    end
    always @(posedge bck) if(!rst) begin
        if(^{bck,ws,din}===1'bx) $fatal(1,"Unknown serial pins");
        if(change_time!=0 && $time-change_time<260) $fatal(1,"Serial setup");
        if(bits<4 && din!==0) $fatal(1,"Padding not zero");
        bits=bits+1;
        shift={shift[14:0],din};
    end
    always @(ws) if(!rst && $time>0) begin
        #1;
        if(bits!=20) $fatal(1,"Word length %0d",bits);
        if(frames==0) expected=0;
        else if(ws) expected=right_queue[frames-1];
        else expected=left_queue[frames-1];
        if(shift!==expected) $fatal(1,"Serial frame=%0d left=%0d got=%h expected=%h",frames,!ws,shift,expected);
        if(!ws) frames=frames+1;
        bits=0; shift=0;
    end
endmodule

module transport_tb;
    reg clk=0,rst=1;
    reg [15:0] left=16'hA53D,right=16'h36C7;
    wire ce,bck,ws,din;
    wire top_bck,top_ws,top_din,pa;
    always #10 clk=~clk;
    // Input changes within words AND at loading edges: no tearing is allowed.
    always @(posedge clk) begin left<=left+16'd17; right<=right-16'd31; end
    pt8211_tx tx(clk,rst,left,right,ce,bck,ws,din);
    serial_checker pattern_check(clk,rst,ce,bck,ws,din,left,right);
    instrument_top top(clk,top_bck,top_ws,top_din,pa);
    // Only the event loop and envelopes are shortened for transport integration.
    defparam top.demo.SLOT_SAMPLES=480;
    defparam top.demo.GATE_SAMPLES=240;
    defparam top.voice.ATTACK_STEP=1024;
    defparam top.voice.DECAY_STEP=256;
    defparam top.voice.RELEASE_STEP=256;
    serial_checker top_check(clk,top.rst,top.sample_ce,top_bck,top_ws,top_din,top.sample,top.sample);
    integer audible=0;
    always @(posedge clk) if(top.sample_valid && top.sample!=0) audible=audible+1;
    initial begin
        repeat(16) @(negedge clk); rst=0;
        #65000000;
        if(pattern_check.frames<3000 || top_check.frames<3000 || audible<800 || pa!==0)
            $fatal(1,"Insufficient integration coverage");
        $display("TRANSPORT_TB_PASS pattern_frames=%0d top_frames=%0d audible_samples=%0d",
            pattern_check.frames,top_check.frames,audible);
        $finish;
    end
endmodule

`timescale 1ns/1ps
// Independent pin receiver. No access to transmitter's counters/shift registers.
module format_checker (
    input wire clk,rst,ce,bck,ws,din,mode16,
    input wire signed [15:0] source_left,source_right
);
    reg [15:0] left_queue[0:4095],right_queue[0:4095];
    reg [15:0] shift=0,expected;
    integer loaded=0,frames=0,bits=0,expected_bits=20,words16=0,words20=0;
    time edge_time=0,change_time=0,last_ce=0,last_ws=0;
    always @(posedge rst) begin
        loaded=0; frames=0; bits=0; expected_bits=20;
        words16=0; words20=0; shift=0;
        edge_time=0; change_time=0; last_ce=0; last_ws=0;
    end
    always @(posedge clk) if(!rst && ce) begin
        if(last_ce!=0 && $time-last_ce!=20800) $fatal(1,"Wrong sample interval");
        last_ce=$time;
        if(loaded>=4096) $fatal(1,"Checker queue overflow");
        left_queue[loaded]=source_left; right_queue[loaded]=source_right;
        loaded=loaded+1;
    end
    always @(bck) if(!rst && $time>0) begin
        if(edge_time!=0) begin
            if(!bck && $time-edge_time!=260) $fatal(1,"Wrong BCK high width");
            if(bck) begin
                if(expected_bits==16 && bits==0) begin
                    if($time-edge_time!=2340) $fatal(1,"Wrong 16-bit word gap");
                end else if($time-edge_time!=260) $fatal(1,"Wrong BCK low width");
            end
        end
        edge_time=$time;
    end
    always @(ws or din) if(!rst && $time>0) begin
        if(bck!==0) $fatal(1,"Data/WS changed while BCK high");
        change_time=$time;
    end
    always @(posedge bck) if(!rst) begin
        if(^{bck,ws,din}===1'bx) $fatal(1,"Unknown serial pin");
        if(change_time!=0 && $time-change_time<260) $fatal(1,"Insufficient setup");
        if(expected_bits==20 && bits<4 && din!==0) $fatal(1,"Nonzero A padding");
        bits=bits+1;
        shift={shift[14:0],din};
    end
    always @(ws) if(!rst && $time>0) begin
        #1;
        if(last_ws!=0 && $time-last_ws!=10400) $fatal(1,"Wrong WS interval");
        last_ws=$time;
        if(bits!=expected_bits) $fatal(1,"Word length got=%0d expected=%0d",bits,expected_bits);
        if(frames==0) expected=0;
        else if(ws) expected=right_queue[frames-1];
        else expected=left_queue[frames-1];
        if(shift!==expected) $fatal(1,"Decoded mismatch frame=%0d left=%0d got=%h expected=%h",frames,!ws,shift,expected);
        if(expected_bits==16) words16=words16+1;
        else words20=words20+1;
        if(!ws) frames=frames+1;
        expected_bits=mode16 ? 16 : 20;
        bits=0; shift=0;
    end
endmodule

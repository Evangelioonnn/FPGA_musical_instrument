`timescale 1ns/1ps
module keys_tb;
    reg clk=0,rst=1,panic=0,changed=0,ghost=0,all_up=1,ready=1;
    reg [15:0] keys=0;reg [1:0] tone=0;
    wire valid,off,fault,blocked,overflow,exhausted;wire [31:0] token,faults;wire [6:0] note;wire [1:0] out_tone;
    integer count=0,i;reg seen_off[0:63];reg [31:0] seen_token[0:63];reg [6:0] seen_note[0:63];reg [1:0] seen_tone[0:63];
    reg [41:0] stalled;reg was_stalled=0;
    always #10 clk=~clk;
    playable_keys #(.DEPTH(4)) dut(clk,rst,panic,changed,ghost,all_up,keys,tone,
        valid,ready,off,token,note,out_tone,fault,blocked,overflow,exhausted,faults);
    always @(posedge clk)if(!rst)begin
        if(was_stalled && !fault && !panic && !blocked && {off,token,note,out_tone}!==stalled)$fatal(1,"Payload moved under backpressure");
        was_stalled=valid && !ready;stalled={off,token,note,out_tone};
        if(valid && ready)begin
            seen_off[count]=off;seen_token[count]=token;seen_note[count]=note;seen_tone[count]=out_tone;count=count+1;
        end
    end
    task tick;input integer n;begin repeat(n)@(negedge clk);end endtask
    task snapshot;input [15:0] value;begin keys=value;all_up=value==0;changed=1;tick(1);changed=0;end endtask
    initial begin
        tick(4);rst=0;tick(5);if(blocked)$fatal(1,"Initial all-up did not arm");
        snapshot(1);tick(12);
        tone=2;snapshot(0);snapshot(1);tick(30);
        if(count!=3 || seen_off[0] || !seen_off[1] || seen_off[2] || seen_token[0]!=seen_token[1] || seen_token[2]==seen_token[0] || seen_note[2]!=60 || seen_tone[2]!=2)$fatal(1,"Retrigger identity");
        ready=0;snapshot(0);tick(8);snapshot(16'h8001);tick(5);tone=1;tick(5);
        ready=1;tick(40);
        if(count!=6 || !seen_off[3] || seen_token[3]!=seen_token[2] || seen_tone[4]!=2 || seen_note[5]!=75)$fatal(1,"Ordered snapshots and captured tone");
        ghost=1;tick(3);ghost=0;tick(3);
        if(!blocked || faults!=1 || valid)$fatal(1,"Ghost not protected");
        snapshot(1);tick(15);if(!blocked || count!=6)$fatal(1,"Ghost rearmed while held");
        snapshot(0);tick(10);snapshot(2);tick(20);if(count!=7 || seen_note[6]!=61)$fatal(1,"Recovery failed");
        ready=0;snapshot(0);tick(8);
        for(i=0;i<8;i=i+1)begin snapshot(i[0]?0:4);tick(2);end
        tick(5);if(!overflow || faults<2)$fatal(1,"Overflow silently lost events overflow=%b faults=%0d",overflow,faults);
        ready=1;snapshot(0);tick(20);snapshot(8);tick(20);
        panic=1;tick(3);panic=0;tick(10);if(!blocked || valid)$fatal(1,"Panic retained held key");
        snapshot(0);tick(10);
        // Explicit exhaustion, no token wrap/reuse even after panic.
        dut.next_token=32'hffffffff;snapshot(1);tick(15);snapshot(0);tick(15);snapshot(2);tick(15);
        if(!exhausted || !blocked || valid)$fatal(1,"Token exhaustion failed closed");
        $display("KEYS_TB_PASS events=%0d repeat_identity=1 stable_backpressure=1 ghost_overflow_panic=1 token_wrap_blocked=1",count);$finish;
    end
    initial begin #1000000;$fatal(1,"keys timeout");end
endmodule

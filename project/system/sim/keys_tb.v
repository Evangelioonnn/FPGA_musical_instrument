`timescale 1ns/1ps
module keys_tb;
    reg clk=0,rst=1,sv=0,ready=0;
    reg [3:0] state;reg [27:0] mapping;reg [8:0] velocity;
    wire sr,ev;wire [1:0] kind;wire [6:0] note;wire [8:0] vel;wire [3:0] owned;
    integer fs,fe,rv,rv2,requested,total=0,received=0,count=0,seed=71,timeout=0;
    reg [17:0] expected,held_packet;reg stalled=0;
    always #10 clk=~clk;
    key_router #(.KEYS(4)) dut(clk,rst,1'b0,sv,state,mapping,velocity,sr,ev,kind,note,vel,ready,owned);
    always @(negedge clk) if(!rst) ready=($random(seed)&7)<3;
    always @(posedge clk) if(!rst) begin
        if(stalled && (!ev || {kind,note,vel}!==held_packet)) $fatal(1,"Key event changed while stalled");
        if(ev && ready) begin
            rv2=$fscanf(fe,"%h\n",expected);
            if(rv2!=1 || {kind,note,vel}!==expected) $fatal(1,"Key oracle event=%0d got=%h expected=%h",received,{kind,note,vel},expected);
            received=received+1;
        end
        stalled=ev && !ready;held_packet={kind,note,vel};
    end
    initial begin
        fs=$fopen("key_states.txt","r");fe=$fopen("key_events.txt","r");if(!fs || !fe) $fatal(1,"Input vectors missing");
        repeat(4) @(negedge clk);rst=0;
        while(!$feof(fs)) begin
            rv=$fscanf(fs,"%h %h %d %d\n",state,mapping,velocity,requested);
            if(rv==4) begin
                wait(sr);@(negedge clk);sv=1;@(negedge clk);sv=0;
                wait(sr);@(negedge clk);
                total=total+requested;count=count+1;
                if(received!=total || owned!==state) $fatal(1,"Key snapshot reconciliation");
            end
        end
        if(count!=2006 || received<2000) $fatal(1,"Key coverage");
        $display("KEYS_TB_PASS snapshots=%0d events=%0d",count,received);$finish;
    end
    initial begin #10000000;$fatal(1,"Key timeout");end
endmodule

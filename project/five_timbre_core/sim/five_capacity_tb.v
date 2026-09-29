`timescale 1ns/1ps
module five_capacity_tb;
    reg clk=0;always #10 clk=~clk;
    reg rst=1,ce=0,ev=0,off=0;
    reg [31:0] token=0;reg [6:0] note=60;reg [2:0] timbre=0;
    wire ready,rejected,valid,clip,deadline;
    wire [15:0] occupied;wire signed [15:0] pcm;
    wire [31:0] rejected_count;
    gallery_bank #(.N(16),.BALANCE_MODE(1)) dut(
        .clk(clk),.rst(rst),.sample_ce(ce),.event_valid(ev),.event_ready(ready),
        .event_off(off),.event_token(token),.event_note(note),.event_timbre(timbre),
        .pedal(1'b0),.sostenuto(1'b0),.reference_release(16'd24),
        .glide_index(3'd0),.lead_attack_index(2'd2),.bend_factor(17'd65536),
        .accepted(),.unmatched_off_count(),.held(),
        .rejected(rejected),.rejected_count(rejected_count),
        .occupied(occupied),.out_valid(valid),.out_sample(pcm),
        .clipped(clip),.deadline_missed(deadline));
    integer frames_seen=0,nonzero=0,i;
    always @(posedge clk) if(!rst) begin
        #1;
        if(valid) begin
            frames_seen=frames_seen+1;
            if(pcm!=0) nonzero=nonzero+1;
            if(clip || deadline || (^pcm)===1'bx) $fatal(1,"bad 16-voice PCM");
        end
    end
    task frames;input integer count;integer j,prior;begin
        for(j=0;j<count;j=j+1) begin
            prior=frames_seen;ce=1;@(negedge clk);ce=0;
            repeat(1040) @(negedge clk);
            if(frames_seen!=prior+1) $fatal(1,"16-voice deadline");
        end
    end endtask
    task command;input kind;input integer id,pitch,preset;begin
        while(!ready) @(negedge clk);
        ev=1;off=kind;token=id;note=pitch;timbre=preset;
        @(negedge clk);ev=0;
    end endtask
    initial begin
        repeat(8) @(negedge clk);rst=0;frames(4);
        for(i=0;i<16;i=i+1) command(0,100+i,48+i*2,i%5);
        frames(400);
        if(occupied!=16'hffff || nonzero<100 || rejected_count!=0)
            $fatal(1,"16 voices not held");
        command(0,500,60,0);frames(2);
        if(rejected_count!=1 || occupied!=16'hffff) $fatal(1,"full policy");
        $display("FIVE_CAPACITY_TB_PASS 16 mixed voices, %0d frames",frames_seen);
        $finish;
    end
endmodule

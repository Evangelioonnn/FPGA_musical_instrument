`timescale 1ns/1ps
module bank_tb;
    reg clk=0,rst=1;reg [6:0] tick=0;wire ce=!rst && tick==0;
    reg valid=0,off=0,pedal=0;reg [31:0] token=1;reg [6:0] note=60;reg [1:0] tone=0;
    reg [15:0] release_step=3;reg [2:0] fm_r=3;
    wire ready,accepted,rejected,ov,clip,deadline;wire [31:0] rejects,unmatched;
    wire [7:0] occupied,held;wire signed [15:0] sample;
    integer frames=0,accepts=0,reject_pulses=0,i,sum,nonzero=0;
    always #10 clk=~clk;
    always @(posedge clk)if(rst)tick<=0;else tick<=tick+1'b1;
    playable_bank dut(clk,rst,ce,valid,ready,off,token,note,tone,pedal,release_step,fm_r,
        accepted,rejected,rejects,unmatched,occupied,held,ov,sample,clip,deadline);
    always @(posedge clk)if(!rst)begin
        if(accepted)accepts=accepts+1;
        if(rejected)reject_pulses=reject_pulses+1;
        if(deadline || clip)$fatal(1,"Bank deadline/clip");
        if(ov)begin
            sum=0;for(i=0;i<8;i=i+1)sum=sum+$signed(dut.frame[i*16+:16]);
            if(sample!==sum)$fatal(1,"Fixed-gain signed mixer differs got=%0d expected=%0d",sample,sum);
            if(sample!=0)nonzero=nonzero+1;
            frames=frames+1;
        end
    end
    task send;input integer is_off,id,key,timbre;begin
        @(negedge clk);while(!ready)@(negedge clk);
        off=is_off;token=id;note=key;tone=timbre;valid=1;
        @(negedge clk);valid=0;repeat(8)@(negedge clk);
    end endtask
    task wait_frames;input integer n;integer end_at;begin end_at=frames+n;wait(frames>=end_at);@(negedge clk);end endtask
    initial begin
        repeat(5)@(negedge clk);rst=0;send(0,1,60,0);wait_frames(2000);
        send(1,1,60,2);send(0,2,60,0);wait_frames(50);
        if(occupied[1:0]!=3 || held[1:0]!=2)$fatal(1,"Same-note tail overwritten or wrong off");
        pedal=1;send(1,2,60,1);send(0,3,64,2);send(1,3,64,0);
        send(0,4,67,1);send(1,4,67,2);wait_frames(2000);
        if(dut.slots[1].slot.state!=3 || dut.slots[2].slot.state!=3 || dut.slots[3].slot.state!=3)$fatal(1,"Sustain or pluck one-shot");
        if(dut.slots[2].slot.held_timbre!=2 || dut.slots[3].slot.held_timbre!=1)$fatal(1,"Tone changed under old voices");
        send(0,5,69,0);send(0,6,72,2);send(0,7,74,1);send(0,8,75,0);
        if(occupied!=255)$fatal(1,"Eight voices not occupied");
        send(0,9,62,0);send(0,2,65,1);
        if(rejects!=2 || accepts!=8)$fatal(1,"Capacity/duplicate rejection");
        release_step=96;fm_r=0;pedal=0;wait_frames(1600);
        if(occupied[2:1]!=0 || !occupied[3])$fatal(1,"Release semantics differ between algorithms");
        if(dut.slots[3].slot.pluck.releasing)$fatal(1,"Pluck reacted to key/pedal release");
        send(0,10,62,0);send(1,2,60,0);wait_frames(20);
        if(!held[1] || dut.tokens[1]!=10 || unmatched!=1)$fatal(1,"Late old off killed recycled slot");
        if(nonzero<4000)$fatal(1,"No meaningful audio");
        $display("BANK_TB_PASS frames=%0d accepted=%0d rejected=%0d identity=1 fixed_gain_mix=1 pluck_ignores_off=1",frames,accepts,rejects);$finish;
    end
    initial begin #100000000;$fatal(1,"bank timeout");end
endmodule

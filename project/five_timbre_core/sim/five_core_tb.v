`timescale 1ns/1ps
module five_core_tb;
    reg clk=0;always #10 clk=~clk;
    reg rst=1,ce=0,ev=0,off=0,pedal=0,sostenuto=0;
    reg [31:0] token=0;reg [6:0] note=60;reg [2:0] timbre=0,glide=0;
    reg [16:0] bend_factor=65536;
    wire ready,accepted,rejected,valid,clip,deadline;
    wire [7:0] occupied,held;wire [31:0] rejected_count,unmatched;
    wire signed [15:0] sample;
    gallery_bank #(.N(8)) dut(clk,rst,ce,ev,ready,off,token,note,timbre,
        pedal,sostenuto,16'd24,glide,2'd2,bend_factor,accepted,rejected,rejected_count,
        unmatched,occupied,held,valid,sample,clip,deadline);
    integer frames_seen=0,nonzero=0,i;
    reg [63:0] expected_step;
    reg [31:0] lead_step;
    always @(posedge clk) if(!rst) begin
        #1;
        if(valid) begin
            frames_seen=frames_seen+1;
            if(sample!=0) nonzero=nonzero+1;
            if(clip || deadline || (^sample)===1'bx) $fatal(1,"bad audio frame");
        end
    end
    task frames;input integer count;integer j,last;begin
        for(j=0;j<count;j=j+1) begin
            last=frames_seen;ce=1;@(negedge clk);ce=0;
            repeat(1040) @(negedge clk);
            if(frames_seen!=last+1) $fatal(1,"missing frame");
        end
    end endtask
    task command;input kind;input integer id,pitch,preset;begin
        while(!ready) @(negedge clk);
        ev=1;off=kind;token=id;note=pitch;timbre=preset;
        @(negedge clk);ev=0;repeat(8) @(negedge clk);
    end endtask
    task reset_bank;begin rst=1;repeat(8) @(negedge clk);rst=0;end endtask
    initial begin
        repeat(8) @(negedge clk);rst=0;frames(4);
        for(i=0;i<5;i=i+1) begin
            command(0,100+i,60,i);frames(300);
            if(!occupied[0] || dut.slots[0].slot.held_timbre!=i)
                $fatal(1,"wrong preset %0d",i);
            command(1,100+i,0,0);frames(40);
            reset_bank;frames(4);
        end
        if(nonzero<100) $fatal(1,"silent bank");
        command(0,200,60,0);frames(20);
        sostenuto=1;frames(2);command(1,200,0,0);frames(20);
        if(!occupied[0] || held[0]) $fatal(1,"sostenuto lost captured piano");
        command(0,201,64,0);frames(20);command(1,201,0,0);frames(20);
        if(dut.slots[1].slot.state==3) $fatal(1,"new piano incorrectly captured");
        sostenuto=0;frames(20);
        if(dut.slots[0].slot.state==3) $fatal(1,"sostenuto release failed");
        reset_bank;frames(4);
        pedal=1;command(0,210,60,0);frames(20);
        sostenuto=1;frames(2);command(1,210,0,0);frames(20);
        pedal=0;frames(20);
        if(dut.slots[0].slot.state!=3) $fatal(1,"pedal overlap released captured note");
        sostenuto=0;frames(20);
        if(dut.slots[0].slot.state==3) $fatal(1,"overlap release failed");
        reset_bank;frames(4);
        command(0,300,60,4);frames(10);
        bend_factor=73562;frames(140);
        expected_step=({32'd0,dut.slots[0].slot.harmonic.current_step}*64'd73562)>>16;
        if(dut.slots[0].slot.harmonic.bend_slewed!=73562 ||
           dut.slots[0].slot.harmonic.bent_step!==expected_step[31:0])
            $fatal(1,"positive bend failed");
        bend_factor=58386;frames(250);
        expected_step=({32'd0,dut.slots[0].slot.harmonic.current_step}*64'd58386)>>16;
        if(dut.slots[0].slot.harmonic.bend_slewed!=58386 ||
           dut.slots[0].slot.harmonic.bent_step!==expected_step[31:0])
            $fatal(1,"negative bend failed");
        bend_factor=65536;frames(1);
        if(dut.slots[0].slot.harmonic.bend_slewed==65536)
            $fatal(1,"abrupt bend return");
        frames(129);
        if(dut.slots[0].slot.harmonic.bent_step!=dut.slots[0].slot.harmonic.current_step)
            $fatal(1,"bend return failed");
        lead_step=dut.slots[0].slot.harmonic.current_step;
        glide=1;command(0,301,64,4);frames(5);
        if(dut.slots[1].slot.glide_source_step!=lead_step ||
           dut.slots[1].slot.harmonic.current_step<=lead_step ||
           dut.slots[0].slot.harmonic.current_step!=lead_step)
            $fatal(1,"new-note glide selection failed");
        frames(1100);
        if(dut.slots[1].slot.harmonic.current_step!=dut.slots[1].slot.harmonic.target_step)
            $fatal(1,"glide did not reach target");
        glide=0;
        reset_bank;frames(4);
        for(i=0;i<8;i=i+1) command(0,400+i,48+i*2,i%5);
        frames(250);
        if(occupied!=8'hff || rejected_count!=0) $fatal(1,"eight voice failure");
        command(0,500,60,0);
        if(rejected_count!=1 || occupied!=8'hff) $fatal(1,"full bank failure");
        reset_bank;frames(4);
        command(0,501,60,7);
        if(rejected_count!=1 || occupied!=0) $fatal(1,"invalid preset accepted");
        $display("FIVE_CORE_TB_PASS five presets, selective hold, bend, eight voices, %0d frames",frames_seen);
        $finish;
    end
endmodule

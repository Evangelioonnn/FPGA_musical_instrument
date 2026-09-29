`timescale 1ns/1ps
module gallery_events_tb;
    reg clk=0;always #10 clk=~clk;
    reg rst=1,ce=0,ev=0,off=0,pedal=0;
    reg [31:0] token=0;reg [6:0] note=60;reg [2:0] timbre=0,glide=0;
    wire ready,accepted,rejected,valid,clip,deadline;
    wire [7:0] occupied,held;wire [31:0] rejected_count,unmatched;
    wire signed [15:0] sample;
    gallery_bank dut(clk,rst,ce,ev,ready,off,token,note,timbre,pedal,16'd24,glide,
        accepted,rejected,rejected_count,unmatched,occupied,held,valid,sample,clip,deadline);
    integer samples=0,nonzero=0,i;reg signed [31:0] prior_step,target;
    always @(posedge clk) if(!rst) begin
        #1;
        if(valid) begin
            samples=samples+1;
            if(sample!=0) nonzero=nonzero+1;
            if(clip || deadline || (^sample)===1'bx) $fatal;
        end
    end
    task frames;input integer count;integer j,v;begin
        for(j=0;j<count;j=j+1) begin
            v=samples;ce=1;@(negedge clk);ce=0;repeat(127) @(negedge clk);
            if(samples!=v+1) $fatal;
        end
    end endtask
    task command;input kind;input integer id,pitch,preset;
        begin while(!ready) @(negedge clk);
            ev=1;off=kind;token=id;note=pitch;timbre=preset;
            @(negedge clk);ev=0;repeat(8) @(negedge clk);
        end
    endtask
    task command_fast;input integer id,pitch,preset;
        begin while(!ready) @(negedge clk);
            ev=1;off=0;token=id;note=pitch;timbre=preset;
            @(negedge clk);ev=0;
        end
    endtask
    initial begin
        repeat(6) @(negedge clk);rst=0;frames(100);
        command(0,1,60,4);frames(20);
        target=dut.slots[0].slot.harmonic.current_step;
        if(target==0 || dut.slots[0].slot.held_timbre!=4) $fatal;
        glide=3;command(0,2,64,5);frames(4);
        if(dut.slots[1].slot.harmonic.current_step<=0 || dut.slots[1].slot.harmonic.current_step<=target) begin
            $display("glide start %0d target-first %0d",dut.slots[1].slot.harmonic.current_step,target);$fatal;
        end
        prior_step=dut.slots[1].slot.harmonic.current_step;
        for(i=0;i<4096;i=i+1) begin
            frames(1);
            if($signed(dut.slots[1].slot.harmonic.current_step)<prior_step) $fatal;
            prior_step=dut.slots[1].slot.harmonic.current_step;
        end
        if(dut.slots[1].slot.harmonic.current_step!=dut.new_step ||
           dut.slots[0].slot.harmonic.current_step!=target) $fatal;
        command(1,1,0,0);command(1,2,0,0);frames(700);
        rst=1;repeat(8) @(negedge clk);rst=0;frames(10);
        command(0,100,60,4);frames(20);
        prior_step=dut.slots[0].slot.harmonic.current_step;
        glide=3;command_fast(101,64,5);command_fast(102,67,4);frames(8);
        if(dut.slots[1].slot.glide_source_step!=prior_step ||
           dut.slots[2].slot.glide_source_step!=prior_step ||
           dut.slots[1].slot.held_glide_index!=3 ||
           dut.slots[2].slot.held_glide_index!=3 ||
           dut.slots[0].slot.harmonic.current_step!=prior_step) $fatal;
        rst=1;repeat(8) @(negedge clk);rst=0;frames(10);
        pedal=1;command(0,10,60,2);frames(280);
        if(dut.slots[0].slot.tone_envelope<65000) $fatal;
        command(1,10,0,0);frames(120);
        if(!occupied[0]) $fatal;pedal=0;frames(150);
        rst=1;repeat(8) @(negedge clk);rst=0;frames(10);
        for(i=0;i<8;i=i+1) command(0,20+i,48+i*2,i);
        frames(1500);
        if(occupied!=8'hff || nonzero<100 || rejected_count!=0) $fatal;
        command(0,99,60,0);
        if(rejected_count!=1 || occupied!=8'hff) $fatal;
        for(i=0;i<8;i=i+1) command(1,20+i,0,0);
        frames(200);
        rst=1;repeat(8) @(negedge clk);rst=0;pedal=1;frames(10);
        command(0,110,60,1);frames(30);command(1,110,0,0);frames(20);
        if(dut.slots[0].slot.state!=3 || dut.slots[0].slot.key_down) $fatal;
        rst=1;repeat(8) @(negedge clk);rst=0;frames(10);
        command(0,111,60,6);frames(30);command(1,111,0,0);frames(20);
        if(dut.slots[0].slot.state==3 || dut.slots[0].slot.key_down) $fatal;
        rst=1;repeat(8) @(negedge clk);rst=0;pedal=0;frames(10);
        command(0,112,60,3);frames(100);
        if(dut.slots[0].slot.tone_envelope<1000 ||
           dut.slots[0].slot.tone_envelope>3000) $fatal;
        frames(5000);
        if(dut.slots[0].slot.tone_envelope<60000) $fatal;
        $display("GALLERY_EVENTS_TB_PASS pitch-continuous glide, held organ, all 8 presets, full refusal, %0d nonzero frames",nonzero);$finish;
    end
endmodule

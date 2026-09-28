`timescale 1ns/1ps
module poly_preview_tb #(parameter N=16,parameter SHIFT=1,parameter FAST=1,parameter SHORT=0);
    reg clk=0;always #10 clk=~clk;
    reg rst=1,ce=0,ev=0,off=0,pedal=0;
    reg [31:0] token=0;reg [6:0] note=60;
    wire ready,valid,clip,deadline;
    wire signed [15:0] sample;
    wire [N-1:0] occupied;
    piano_poly_core #(.N(N),.OUTPUT_SHIFT(SHIFT)) dut(
        .clk(clk),.rst(rst),.sample_ce(ce),.event_valid(ev),.event_ready(ready),
        .event_off(off),.event_token(token),.event_note(note),.attack_step(16'd68),
        .decay_step(16'd6),.sustain_level(16'd32768),.release_step(16'd48),
        .sustain(pedal),.sostenuto(1'b0),.occupied(occupied),
        .out_valid(valid),.out_sample(sample),.clipped(clip),.deadline_missed(deadline));
    integer i,j,v,fd,frames_written=0,max_occupied=0,current_count,ticks;
    reg [1023:0] filename;
    task frames;
        input integer count;
        begin for(j=0;j<count;j=j+1) begin
            ticks=FAST ? 16*N+8 : 1040;
            ce=1;@(negedge clk);ce=0;
            while(!valid) @(negedge clk);
            if(clip||deadline||(^sample)===1'bx)$fatal;
            $fwrite(fd,"%0d\n",sample);frames_written=frames_written+1;
            current_count=0;
            for(v=0;v<N;v=v+1) if(occupied[v]) current_count=current_count+1;
            if(current_count>max_occupied)max_occupied=current_count;
            repeat(ticks-(16*N+2)) @(negedge clk);
        end end
    endtask
    task command;
        input kind;input [31:0] id;input [6:0] pitch;
        begin
            while(!ready) @(negedge clk);
            ev=1;off=kind;token=id;note=pitch;@(negedge clk);ev=0;
            repeat(N+3) @(negedge clk);
            if(dut.rejected_count!=0 || dut.unmatched_off_count!=0)$fatal;
        end
    endtask
    initial begin
        $sformat(filename,"poly_preview_%0d_%0d_%0d_%0d.txt",N,SHIFT,FAST,SHORT);
        fd=$fopen(filename,"w");repeat(5) @(negedge clk);rst=0;
        if(SHORT) begin
            frames(3);command(0,1,60);frames(300);command(1,1,0);frames(100);
        end else begin
            frames(100);command(0,1,48);frames(10000);command(1,1,0);frames(8000);
            command(0,2,60);frames(10000);command(1,2,0);frames(8000);
            command(0,3,72);frames(10000);command(1,3,0);frames(8000);
            pedal=1;
            for(i=0;i<N;i=i+1) begin
                command(0,100+i,48+(i%25));frames(700);command(1,100+i,0);
            end
            frames(10000);if(occupied!={N{1'b1}})$fatal;
            pedal=0;frames(6000);if(occupied!=0)$fatal;
        end
        $fclose(fd);
        $display("POLY_PREVIEW_TB_PASS N=%0d shift=%0d FAST=%0d SHORT=%0d samples=%0d max-occupied=%0d",N,SHIFT,FAST,SHORT,frames_written,max_occupied);$finish;
    end
endmodule

`timescale 1ns/1ps
module output_render_tb #(parameter FAST=1,parameter SHORT=0);
    reg clk=0;always #10 clk=~clk;
    reg rst=1,ce=0,ev=0,off=0;
    reg [31:0] token=0;reg [6:0] note=48;reg [1:0] tone=0;
    wire [1:0] ready,valid,clip,deadline;
    wire signed [15:0] pcm[0:1];wire [7:0] occupied[0:1];
    wire [13:0] gain_valid;wire [223:0] gain_pcm;
    genvar v,k;
    generate for(v=0;v<2;v=v+1) begin: banks
        output_bank #(.TONE_SHIFT(v*3)) dut(clk,rst,ce,ev,ready[v],off,token,note,tone,
            1'b0,16'd96,,,,,occupied[v],,valid[v],pcm[v],clip[v],deadline[v]);
        for(k=0;k<7;k=k+1) begin: levels
            wire [16:0] target;
            knob_volume_table table_gain(5'd18+k,target);
            knob_gain vol(clk,rst,valid[v],pcm[v],target,gain_valid[v*7+k],gain_pcm[(v*7+k)*16+:16],);
        end
    end endgenerate
    wire [7:0] initializing;
    generate for(k=0;k<8;k=k+1) begin: init_mon
        assign initializing[k]=banks[0].dut.slots[k].slot.pluck.initializing;
        always @(posedge clk) if(!rst && valid[0]) begin
            if(banks[0].dut.slots[k].slot.held_timbre==1) begin
                if(banks[0].dut.samples[k*20+:20] !== banks[1].dut.samples[k*20+:20]) $fatal;
            end else if($signed(banks[0].dut.samples[k*20+:20])-8*$signed(banks[1].dut.samples[k*20+:20])>4 ||
                        $signed(banks[0].dut.samples[k*20+:20])-8*$signed(banks[1].dut.samples[k*20+:20])< -4) $fatal;
        end
    end endgenerate
    integer fd,count=0,valids=0,i,section=0;reg [1023:0] filename;
    always @(posedge clk) if(!rst) begin
        #1;
        if(valid[0]) begin
            if(valid!==3 || clip || deadline || occupied[0]!==occupied[1] || banks[0].dut.rejected_count || banks[1].dut.rejected_count) $fatal;
        end
        if(gain_valid[0]) begin
            if(gain_valid!==14'h3fff || (^gain_pcm)===1'bx) $fatal;
            $fwrite(fd,"%0d %0d %0d",section,pcm[0],pcm[1]);
            for(i=0;i<14;i=i+1) $fwrite(fd," %0d",$signed(gain_pcm[i*16+:16]));
            $fwrite(fd,"\n");count=count+1;valids=valids+1;
        end
    end
    task frames;
        input integer n;integer j,ticks;
        begin for(j=0;j<n;j=j+1) begin
            ticks=(!FAST || initializing!=0) ? 1040:128;
            valids=0;ce=1;@(negedge clk);ce=0;repeat(ticks-1) @(negedge clk);
            if(valids!=1) $fatal;
        end end
    endtask
    task command;
        input kind;input integer id,pitch,timbre;
        begin while(ready!==3) @(negedge clk);
            ev=1;off=kind;token=id;note=pitch;tone=timbre;@(negedge clk);ev=0;repeat(8) @(negedge clk);
        end
    endtask
    integer j;
    initial begin
        $sformat(filename,"render_%0d_%0d.txt",FAST,SHORT);fd=$fopen(filename,"w");
        repeat(8) @(negedge clk);rst=0;frames(600);
        if(SHORT) begin
            command(0,1,48,0);command(0,2,50,1);frames(1200);
        end else begin
            section=1;command(0,1,48,0);frames(4000);
            section=2;command(0,2,50,0);frames(16000);
            section=3;command(0,3,52,0);frames(16000);
            section=4;for(j=1;j<=3;j=j+1) command(1,j,0,0);frames(8000);
            section=5;command(0,4,60,0);frames(4000);
            section=6;command(0,5,62,0);frames(16000);
            section=7;command(0,6,64,0);frames(16000);
            section=8;for(j=4;j<=6;j=j+1) command(1,j,0,0);frames(8000);
            section=9;for(j=0;j<8;j=j+1) command(0,10+j,48,0);frames(5000);
            section=10;for(j=0;j<8;j=j+1) command(1,10+j,0,0);frames(2000);
            section=11;for(j=0;j<8;j=j+1) command(0,20+j,48+j*2,0);frames(5000);
            section=12;for(j=0;j<8;j=j+1) command(1,20+j,0,0);frames(2000);
            section=13;for(j=0;j<8;j=j+1) command(0,30+j,48+j*2,j%2);frames(24000);
            section=14;for(j=0;j<8;j=j+1) command(1,30+j,0,0);frames(24000);
        end
        $fclose(fd);$display("OUTPUT_RENDER_TB_PASS %0d samples; gain18..24; pluck exact; fixed per-voice piano gain; no clip/deadline",count);$finish;
    end
endmodule

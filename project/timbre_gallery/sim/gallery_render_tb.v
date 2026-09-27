`timescale 1ns/1ps
module gallery_render_tb #(parameter PRESET=0,parameter FAST=1,parameter SHORT=0);
    reg clk=0;always #10 clk=~clk;
    reg rst=1,ce=0,ev=0,off=0;
    reg [31:0] token=0;reg [6:0] note=60;
    wire ready,valid,clip,deadline,rejected;
    wire signed [15:0] sample;
    wire [7:0] occupied,initializing;
    gallery_bank dut(clk,rst,ce,ev,ready,off,token,note,PRESET[2:0],
        1'b0,16'd24,3'd0,,, , ,occupied,,valid,sample,clip,deadline);
    genvar g;generate for(g=0;g<8;g=g+1) begin: init_monitor
        assign initializing[g]=dut.slots[g].slot.pluck.initializing;
    end endgenerate
    integer fd,frames_written=0,valids=0,clocks_skipped=0;
    reg [1023:0] filename;
    always @(posedge clk) if(!rst) begin
        #1;
        if(valid) begin
            if((^sample)===1'bx || clip || deadline || dut.rejected_count!=0) $fatal;
            $fwrite(fd,"%0d\n",sample);frames_written=frames_written+1;valids=valids+1;
        end
    end
    task frames;
        input integer count;integer i,ticks;
        begin for(i=0;i<count;i=i+1) begin
            // Mutable delay-line initialization still gets the full clock cadence.
            ticks=(!FAST || initializing!=0) ? 1040 : 128;
            valids=0;ce=1;@(negedge clk);ce=0;repeat(ticks-1) @(negedge clk);
            if(valids!=1 || dut.mix_state!=0 || dut.tones.state!=0) $fatal;
            clocks_skipped=clocks_skipped+1040-ticks;
        end end
    endtask
    task command;
        input kind;input [31:0] id;input [6:0] pitch;
        begin
            while(!ready) @(negedge clk);
            ev=1;off=kind;token=id;note=pitch;@(negedge clk);ev=0;
            repeat(8) @(negedge clk);
        end
    endtask
    task reset_bank;
        begin rst=1;repeat(8) @(negedge clk);rst=0;end
    endtask
    initial begin
        if(SHORT) $sformat(filename,"gallery_cadence_%0d_%0d.txt",PRESET,FAST);
        else $sformat(filename,"gallery_%0d.txt",PRESET);
        fd=$fopen(filename,"w");repeat(8) @(negedge clk);rst=0;
        if(SHORT) begin
            frames(60);command(0,1,60);frames(500);command(1,1,0);frames(200);
        end else begin
            frames(100);command(0,1,48);frames(6000);command(1,1,0);frames(7000);
            reset_bank;command(0,2,60);frames(12000);command(1,2,0);frames(16000);
            reset_bank;command(0,3,72);frames(6000);command(1,3,0);frames(7000);
            reset_bank;command(0,4,60);command(0,5,64);command(0,6,67);
            frames(10000);command(1,4,0);command(1,5,0);command(1,6,0);frames(16000);
        end
        $fclose(fd);
        $display("GALLERY_RENDER_TB_PASS preset=%0d samples=%0d skipped-idle=%0d",
            PRESET,frames_written,clocks_skipped);$finish;
    end
endmodule

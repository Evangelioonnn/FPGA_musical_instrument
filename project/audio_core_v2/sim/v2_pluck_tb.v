`timescale 1ns/1ps
module v2_pluck_tb;
    reg clk=0;always #10 clk=~clk;
    reg rst=1,ce=0,cmd=0;reg [1:0] kind=0;reg [6:0] note=36;
    wire [9:0] length;wire [15:0] fraction;wire [24:0] reciprocal;
    pluck_note_table lookup(note,length,fraction,reciprocal);
    wire ready,old_ready,active,old_active,valid,old_valid,request;
    wire signed [15:0] sample,old_sample;
    wire signed [33:0] operand;wire signed [25:0] factor;
    reg grant=0;reg [2:0] state=0;
    reg signed [33:0] a;
    reg signed [25:0] b;
    reg signed [59:0] product;
    audio_v2_pluck #(.LOGIC_SCALE(1)) dut(clk,rst,ce,cmd,kind,note,9'd256,32'h12345678,
        length,fraction,reciprocal,ready,,active,sample,valid,request,operand,factor,grant,product);
    palette_pluck #(.LOGIC_SCALE(1)) reference(clk,rst,ce,cmd,kind,note,9'd256,32'h12345678,
        length,fraction,reciprocal,old_ready,,old_active,old_sample,old_valid);
    always @(posedge clk) begin
        grant<=0;
        if(rst) begin state<=0;a<=0;b<=0;product<=0;end
        else case(state)
            0:if(request) begin a<=operand;b<=factor;state<=1;end
            1:begin product<=a*b;state<=2;end
            2:begin grant<=1;state<=3;end
            3:state<=0;
        endcase
    end
    integer new_count=0,old_count=0,compared=0,i,j;
    always @(posedge clk) begin #1;if(valid) new_count=new_count+1;if(old_valid) old_count=old_count+1;end
    task command;input [1:0] value;
        begin
            @(negedge clk);#1;while(!ready || !old_ready) begin @(negedge clk);#1;end
            kind=value;cmd=1;@(negedge clk);cmd=0;
        end
    endtask
    task frames;input integer n,period;
        integer k;
        begin
            for(k=0;k<n;k=k+1) begin
                new_count=0;old_count=0;ce=1;@(negedge clk);ce=0;
                repeat(period-1) @(negedge clk);
                if(new_count!=1 || old_count!=1 || sample!==old_sample || active!==old_active)
                    $fatal(1,"pluck differs note=%0d frame=%0d new=%0d old=%0d counts=%0d/%0d",note,compared,sample,old_sample,new_count,old_count);
                compared=compared+1;
            end
        end
    endtask
    initial begin
        for(i=0;i<5;i=i+1) begin
            rst=1;ce=0;cmd=0;note=36+12*i;repeat(10) @(negedge clk);rst=0;
            command(0);repeat(6000) @(negedge clk);
            if(!ready || !old_ready) $fatal(1,"pluck initialization exceeded6000 clocks");
            frames(100,1040);frames(400,64);command(1);frames(7400,64);
            if(active || old_active || sample!=0) $fatal(1,"pluck release not complete");
        end
        $display("V2_PLUCK_TB_PASS %0d bit-exact frames; MIDI36/48/60/72/84, nominal and64-clock recurrence, full releases",compared);$finish;
    end
    initial begin #200000000;$fatal(1,"pluck equivalence timeout");end
endmodule

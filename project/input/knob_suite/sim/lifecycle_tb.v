`timescale 1ns/1ps
module lifecycle_tb;
    reg clk=0,rst=1;reg [6:0] tick=0;wire ce=!rst && tick==0;
    reg valid=0,all_release=0;reg [1:0] tone=0;reg [15:0] r=3;
    wire ready,accepted,rejected,ov,clip,deadline,slot;
    wire [31:0] rejects;wire [1:0] occupied,gated,captured;
    wire signed [15:0] sample;
    integer i,k,accepts=0,denials=0;
    always #10 clk=~clk;
    always @(posedge clk)if(rst)tick<=0;else tick<=tick+1'b1;
    knob_bank #(.N(2),.MULTI(1)) dut(clk,rst,ce,valid,ready,7'd48,tone,24'd31250,
        16'd68,16'd6,16'd32768,r,1'b0,1'b0,all_release,accepted,rejected,slot,rejects,
        occupied,gated,captured,ov,sample,clip,deadline);
    always @(posedge clk)if(!rst)begin
        if(accepted)accepts=accepts+1;
        if(rejected)denials=denials+1;
        if(clip || deadline)$fatal(1,"Lifecycle audio fault");
    end
    task reset;begin @(negedge clk);rst=1;repeat(5)@(negedge clk);rst=0;repeat(5)@(negedge clk);end endtask
    task send;begin @(negedge clk);valid=1;@(negedge clk);valid=0;end endtask
    initial begin
        reset;
        for(i=0;i<8;i=i+1)begin
            reset;tone=i<3?0:1;send;
            repeat(i<3?i:i+3)@(negedge clk);
            all_release=1;@(negedge clk);all_release=0;
            repeat(1400)@(negedge clk);
            if(occupied || sample)$fatal(1,"In-flight start survived all_release phase=%0d",i);
        end
        reset;tone=0;r=12;send;repeat(10)@(negedge clk);
        if(!rejects || occupied)$fatal(1,"Unsupported ADSR silently accepted");
        r=3;send;repeat(3000)@(negedge clk);
        if(occupied!=1 || dut.slots[0].slot.gate_left>=31250)$fatal(1,"New note after cancel failed");
        $display("LIFECYCLE_TB_PASS cancelled_start_phases=8 unsupported_adsr_rejected=1 restart=1");$finish;
    end
endmodule

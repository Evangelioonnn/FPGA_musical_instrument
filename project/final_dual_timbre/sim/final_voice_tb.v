`timescale 1ns/1ps
module final_voice_tb;
    reg clk=0,rst=1,sample_ce=0,note_on=0,note_off=0;
    reg [31:0] step=32'd39307541;
    wire signed [15:0] harmonic,pluck;
    wire hv,pv,ready,active;
    wire [2:0] hs;
    always #10 clk=~clk;
    clean_voice #(.MODE(1)) h(clk,rst,sample_ce,note_on,note_off,step,16'd3,harmonic,hv,hs);
    pluck_voice #(.LOGIC_SCALE(1)) p(clk,rst,sample_ce,
        note_on,2'd0,7'd60,9'd256,32'h12345678,ready,,active,pluck,pv);
    integer i,hits_h,hits_p;
    task frame;
        begin repeat(1039) @(posedge clk); sample_ce<=1; @(posedge clk); sample_ce<=0; end
    endtask
    always @(posedge clk) begin
        if(hv && harmonic!=0) hits_h=hits_h+1;
        if(pv && pluck!=0) hits_p=hits_p+1;
    end
    initial begin
        hits_h=0;hits_p=0;
        repeat(8) @(posedge clk); rst<=0;
        @(posedge clk); note_on<=1; @(posedge clk); note_on<=0;
        for(i=0;i<24;i=i+1) frame();
        note_off<=1; @(posedge clk); note_off<=0;
        repeat(5000) @(posedge clk);
        if(hits_h<8) $fatal(1,"harmonic candidate silent: %0d",hits_h);
        if(hits_p<1) $fatal(1,"pluck candidate silent: %0d",hits_p);
        $display("FINAL_VOICE_TB_PASS harmonic=%0d pluck=%0d",hits_h,hits_p);
        $finish;
    end
endmodule

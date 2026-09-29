`timescale 1ns/1ps
module clean_voice_tb;
    reg clk=0,rst=1,sample_ce=0,note_on=0,note_off=0;
    reg [31:0] step=32'd39307541;
    wire signed [15:0] s0,s1,s2,s3;
    wire v0,v1,v2,v3;
    wire [2:0] e0,e1,e2,e3;
    integer i,c0,c1,c2,c3,n0,n1,n2,n3;
    always #10 clk=~clk;
    clean_voice #(.MODE(0)) d0(clk,rst,sample_ce,note_on,note_off,step,s0,v0,e0);
    clean_voice #(.MODE(1)) d1(clk,rst,sample_ce,note_on,note_off,step,s1,v1,e1);
    clean_voice #(.MODE(2)) d2(clk,rst,sample_ce,note_on,note_off,step,s2,v2,e2);
    clean_voice #(.MODE(3)) d3(clk,rst,sample_ce,note_on,note_off,step,s3,v3,e3);
    task frame;
        begin
            repeat(1039) @(posedge clk);
            sample_ce<=1; @(posedge clk); sample_ce<=0;
        end
    endtask
    always @(posedge clk) begin
        if(v0) begin c0=c0+1; if(s0!=0)n0=n0+1; end
        if(v1) begin c1=c1+1; if(s1!=0)n1=n1+1; end
        if(v2) begin c2=c2+1; if(s2!=0)n2=n2+1; end
        if(v3) begin c3=c3+1; if(s3!=0)n3=n3+1; end
    end
    initial begin
        c0=0;c1=0;c2=0;c3=0;n0=0;n1=0;n2=0;n3=0;
        repeat(8) @(posedge clk); rst<=0;
        @(posedge clk); note_on<=1; @(posedge clk); note_on<=0;
        for(i=0;i<40;i=i+1) frame();
        note_off<=1; @(posedge clk); note_off<=0;
        repeat(5000) @(posedge clk);
        if(c0<30 || c1<30 || c2<30 || c3<30) $fatal(1,"too few valid samples %0d %0d %0d %0d",c0,c1,c2,c3);
        if(n0<10 || n1<10 || n2<10 || n3<10) $fatal(1,"candidate remained silent %0d %0d %0d %0d",n0,n1,n2,n3);
        $display("CLEAN_VOICE_TB_PASS valid=%0d,%0d,%0d,%0d nonzero=%0d,%0d,%0d,%0d",c0,c1,c2,c3,n0,n1,n2,n3);
        $finish;
    end
endmodule

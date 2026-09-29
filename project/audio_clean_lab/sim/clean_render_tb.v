`timescale 1ns/1ps
module clean_render_tb;
    reg clk=0,rst=1,sample_ce=0,note_on=0,note_off=0;
    reg [31:0] step=32'd39307541;
    wire signed [15:0] s0,s1,s2,s3;
    wire v0,v1,v2,v3;
    wire [2:0] e0,e1,e2,e3;
    integer i, f0,f1,f2,f3;
    always #10 clk=~clk;
    clean_voice #(.MODE(0)) d0(clk,rst,sample_ce,note_on,note_off,step,s0,v0,e0);
    clean_voice #(.MODE(1)) d1(clk,rst,sample_ce,note_on,note_off,step,s1,v1,e1);
    clean_voice #(.MODE(2)) d2(clk,rst,sample_ce,note_on,note_off,step,s2,v2,e2);
    clean_voice #(.MODE(3)) d3(clk,rst,sample_ce,note_on,note_off,step,s3,v3,e3);
    initial begin
        forever begin
            repeat(19) @(posedge clk);
            sample_ce<=1;
            @(posedge clk); sample_ce<=0;
        end
    end
    always @(posedge clk) begin
        if(v0) $fwrite(f0,"%0d\n",s0);
        if(v1) $fwrite(f1,"%0d\n",s1);
        if(v2) $fwrite(f2,"%0d\n",s2);
        if(v3) $fwrite(f3,"%0d\n",s3);
    end
    initial begin
        f0=$fopen("clean_mode_0.txt","w"); f1=$fopen("clean_mode_1.txt","w");
        f2=$fopen("clean_mode_2.txt","w"); f3=$fopen("clean_mode_3.txt","w");
        repeat(8) @(posedge clk); rst<=0;
        @(posedge clk); note_on<=1; @(posedge clk); note_on<=0;
        repeat(10000) @(posedge clk);
        note_off<=1; @(posedge clk); note_off<=0;
        repeat(10000) @(posedge clk);
        $fclose(f0);$fclose(f1);$fclose(f2);$fclose(f3);
        $display("CLEAN_RENDER_TB_PASS"); $finish;
    end
endmodule

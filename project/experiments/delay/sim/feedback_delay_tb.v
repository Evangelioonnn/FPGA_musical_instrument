`timescale 1ns/1ps
module feedback_delay_tb #(parameter D=8);
    reg clk=0,rst=1,valid=0,bypass=1;reg signed [15:0] sample=0;
    wire ready,out_valid;wire signed [15:0] out_sample;wire clipped;
    feedback_delay #(.DEPTH(D),.DELAY(D)) dut(clk,rst,valid,bypass,sample,ready,out_valid,out_sample,clipped);
    integer file1,rv,x,b,expected,clip_expected,pause,n=0,clips=0,was_reset=0;
    always #10 clk=~clk;
    initial begin
        if(D==8)file1=$fopen("delay8_vectors.txt","r");else file1=$fopen("delay4096_vectors.txt","r");
        if(file1==0)$fatal(1,"oracle missing");
        repeat(3)@(negedge clk);rst=0;
        while(!$feof(file1))begin
            rv=$fscanf(file1,"%d %d %d %d %d\n",x,b,expected,clip_expected,pause);
            if(rv!=5)$fatal(1,"bad oracle");
            if(pause<0)begin @(negedge clk);rst=1;repeat(3)@(negedge clk);rst=0;pause=0;was_reset=was_reset+1;end
            repeat(pause)@(negedge clk);
            @(negedge clk);sample=x;bypass=b;valid=1;
            if(!ready)$fatal(1,"ready unexpectedly low");
            @(posedge clk);#1;if(ready)$fatal(1,"busy handshake missing");
            @(negedge clk);valid=0;
            @(posedge clk);#1;
            if(!out_valid || out_sample!==expected[15:0] || clipped!==clip_expected[0])
                $fatal(1,"oracle mismatch D=%0d n=%0d got=%0d/%0d expected=%0d/%0d",D,n,out_sample,clipped,expected,clip_expected);
            n=n+1;clips=clips+clipped;
        end
        $fclose(file1);$display("FEEDBACK_DELAY_TB_PASS D=%0d samples=%0d clips=%0d resets=%0d oracle=python_history",D,n,clips,was_reset);$finish;
    end
    initial begin #30000000;$fatal(1,"delay timeout");end
endmodule

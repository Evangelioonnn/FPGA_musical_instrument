`timescale 1ns/1ps
module delay_render_tb;
    reg clk=0,rst=1,valid=0;reg signed [15:0] sample=0;
    wire ready,ov,clip;wire signed [15:0] out;
    integer fi,fo,rv,x,n=0;
    feedback_delay dut(clk,rst,valid,1'b0,sample,ready,ov,out,clip);
    always #10 clk=~clk;
    task send;input signed [15:0] x;begin
        @(negedge clk);valid=1;sample=x;@(negedge clk);valid=0;@(posedge clk);#1;
        if(!ov || clip)$fatal(1,"render invalid");$fwrite(fo,"%0d\n",out);n=n+1;
    end endtask
    initial begin
        fi=$fopen("../../../system/sim/system_samples.txt","r");fo=$fopen("delay_samples.txt","w");
        repeat(3)@(negedge clk);rst=0;
        while(!$feof(fi))begin rv=$fscanf(fi,"%d\n",x);if(rv==1)send(x);end
        repeat(96000)send(0);
        $fclose(fi);$fclose(fo);$display("DELAY_RENDER_TB_PASS samples=%0d",n);$finish;
    end
endmodule

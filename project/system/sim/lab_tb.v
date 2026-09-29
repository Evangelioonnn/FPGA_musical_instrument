`timescale 1ns/1ps
module lab_tb;
    reg clk=0,rst=1;reg [3:0] tick=0;wire ce=!rst && tick==0;
    wire signed [15:0] c4,a4,silent;wire vc,va,vs;
    integer fc,fa,n=0,audible=0;
    always #10 clk=~clk;
    always @(posedge clk)if(rst)tick<=0;else tick<=tick+1'b1;
    lab_source c(clk,rst,ce,c4,vc);
    lab_source #(.NOTE(69)) a(clk,rst,ce,a4,va);
    lab_source #(.SILENT(1)) s(clk,rst,ce,silent,vs);
    always @(posedge clk)if(!rst)begin #1;
        if(vc!==va || va!==vs || silent!=0)$fatal(1,"Lab cadence/silence");
        if(vc)begin
            if(c4>512 || c4 < -512 || a4>512 || a4 < -512)$fatal(1,"Lab amplitude changed");
            if(n<48077 || n>8*48077)if(c4!=0 || a4!=0)$fatal(1,"Lab silence interval");
            if(c4!=0)audible=audible+1;
            $fwrite(fc,"%0d\n",c4);$fwrite(fa,"%0d\n",a4);n=n+1;
            if(n==10*48077)begin
                if(audible<270000)$fatal(1,"Lab coverage");
                $fclose(fc);$fclose(fa);$display("LAB_TB_PASS samples=%0d audible=%0d conservative_level=1",n,audible);$finish;
            end
        end
    end
    initial begin fc=$fopen("lab_c4_samples.txt","w");fa=$fopen("lab_a4_samples.txt","w");repeat(5)@(negedge clk);rst=0;end
    initial begin #160000000;$fatal(1,"Lab timeout");end
endmodule

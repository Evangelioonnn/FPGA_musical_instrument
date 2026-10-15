`timescale 1ns/1ps
module tmds_pipeline_tb;
    reg clk=0,rstn=0,den=0;
    reg [7:0] data=0;
    reg [1:0] ctrl=0;
    wire [9:0] actual,reference;
    reg [9:0] history0=0,history1=0,history2=0;
    integer n=0,checked=0;
    always #3.333 clk=~clk;
    dvi_tx_tmds_enc dut(.clock(clk),.rstn(rstn),.data(data),.den(den),.ctrl(ctrl),.tmds(actual));
    reference_tmds_enc ref_enc(.clock(clk),.rstn(rstn),.data(data),.den(den),.ctrl(ctrl),.tmds(reference));
    always @(posedge clk) begin
        #0.1;
        history2=history1;history1=history0;history0=reference;
        if(rstn && n>8) begin
            if(actual!==history2) $fatal(1,"TMDS mismatch cycle=%d actual=%b expected=%b",n,actual,history2);
            checked=checked+1;
        end
    end
    initial begin
        repeat(4) @(negedge clk);rstn=1;
        for(n=0;n<4096;n=n+1) begin
            @(negedge clk);
            data=(n<256)?n:$random;
            den=(n%271)<256;
            ctrl=n%4;
        end
        @(negedge clk);
        $display("TMDS_PIPELINE_TB_PASS checked=%d",checked);
        $finish;
    end
endmodule

`timescale 1ns/1ps
module encoder_tb;
    reg clk=0,rst=1,a=0,b=0,button=1;
    wire valid,pressed,changed,error;wire signed [1:0] step;
    integer positive=0,negative=0,errors=0,buttons=0,n;
    always #10 clk=~clk;
    ec11_input #(.SAMPLE_CYCLES(3),.AB_SAMPLES(2),.BUTTON_SAMPLES(4)) dut(clk,rst,a,b,button,valid,step,pressed,changed,error);
    always @(posedge clk) if(!rst) begin
        if(valid) begin if(step==1)positive=positive+1;else if(step==-1)negative=negative+1;else $fatal(1,"Encoder zero step");end
        if(error) errors=errors+1;if(changed) buttons=buttons+1;
    end
    task pos;input [1:0] value;begin {a,b}=value;repeat(15) @(negedge clk);end endtask
    initial begin
        repeat(4) @(negedge clk);rst=0;pos(0);
        for(n=0;n<10;n=n+1) begin pos(1);pos(3);pos(2);pos(0);end
        for(n=0;n<7;n=n+1) begin pos(2);pos(3);pos(1);pos(0);end
        if(positive!=10 || negative!=7) $fatal(1,"Encoder direction/count");
        {a,b}=1;@(negedge clk);{a,b}=0;pos(0);
        if(positive!=10 || negative!=7) $fatal(1,"Encoder bounce");
        pos(3);pos(0);if(errors!=2) $fatal(1,"Encoder invalid jump");
        button=0;@(negedge clk);button=1;repeat(20) @(negedge clk);
        if(pressed || buttons) $fatal(1,"Button bounce");
        button=0;repeat(25) @(negedge clk);if(!pressed) $fatal(1,"Button press");
        button=1;repeat(25) @(negedge clk);if(pressed || buttons!=2) $fatal(1,"Button release");
        $display("ENCODER_TB_PASS positive=%0d negative=%0d invalid=%0d button_edges=%0d",positive,negative,errors,buttons);$finish;
    end
endmodule

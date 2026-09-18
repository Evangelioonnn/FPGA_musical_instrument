`timescale 1ns/1ps
module baseline_voice_tb;
    reg clk=0,rst=1,ce=0,on=0,off=0;
    reg [6:0] note=60;
    reg [8:0] velocity=256;
    wire [31:0] step;
    wire signed [15:0] original,actual;
    wire rv,av;
    wire [15:0] re,ae;
    wire [2:0] rs,as;
    reg expected_valid;
    integer i,j,p,expected,count=0,positive=0,negative=0;
    always #10 clk=~clk;
    note_table notes(note,step);
    synth_voice reference(clk,rst,ce,on,off,1'b0,step,original,rv,re,rs);
    baseline_voice dut(clk,rst,ce,on,off,step,velocity,actual,av,as,ae);
    always @(posedge clk) if(!rst) begin
        expected_valid=rv;
        p=$signed(original)*$signed({1'b0,velocity});
        expected=p>=0 ? p/256 : -((-p+255)/256);
        #1;
        if(av!==expected_valid || ae!==re || as!==rs) $fatal(1,"Voice control mismatch");
        if(av) begin
            if($signed(actual)!==expected) $fatal(1,"Reference mismatch velocity=%0d got=%0d expected=%0d",velocity,actual,expected);
            count=count+1;
            if(actual>0) positive=positive+1;
            if(actual<0) negative=negative+1;
        end
    end
    initial begin
        repeat(4) @(negedge clk);rst=0;
        for(j=0;j<4;j=j+1) begin
            velocity=j==0 ? 256 : j==1 ? 64 : j==2 ? 128 : 0;
            note=60+j*4;on=1;
            @(negedge clk);on=0;
            for(i=0;i<48077;i=i+1) begin
                ce=1;
                @(negedge clk);ce=0;
                if(i==31250) off=1;
                @(negedge clk);off=0;
                repeat(6) @(negedge clk);
            end
            if(actual!==0 || original!==0 || ae!==0 || as!==0) $fatal(1,"Voice tail not silent");
        end
        if(count!=4*48077 || positive<10000 || negative<10000) $fatal(1,"Voice coverage");
        $display("BASELINE_VOICE_TB_PASS samples=%0d positive=%0d negative=%0d",count,positive,negative);$finish;
    end
    initial begin #35000000; $fatal(1,"Voice timeout");end
endmodule

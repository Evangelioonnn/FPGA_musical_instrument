`timescale 1ns/1ps
module palette_scheduler_tb;
    reg clk=0;always #10 clk=~clk;
    reg rst=1,ce=0;wire [15:0] valid;wire [0:0] one_valid;wire deadline,one_deadline;
    wire signed [19:0] sample,one_sample;
    palette_shared_tone #(.PROFILE(1),.N(16)) dut(clk,rst,ce,{16{32'h12345678}},{16{16'd65535}},{16{16'd65535}},sample,valid,deadline);
    palette_shared_tone #(.PROFILE(0),.N(1)) single(clk,rst,ce,32'h12345678,16'd65535,16'd65535,one_sample,one_valid,one_deadline);
    reg [15:0] seen=0;integer cycles=0,last=0;
    always @(posedge clk) if(!rst) begin
        #1;
        if(valid) begin
            if((valid & (valid-1))!=0 || (seen & valid)!=0) $fatal;
            seen=seen|valid;last=cycles;
        end
        cycles=cycles+1;
    end
    task pulse;begin @(negedge clk);ce=1;@(negedge clk);ce=0;end endtask
    initial begin
        repeat(5) @(negedge clk);rst=0;pulse;
        repeat(170) @(negedge clk);
        if(seen!=16'hffff || deadline || one_deadline || last>120) $fatal;
        seen=0;pulse;repeat(3) @(negedge clk);pulse;
        repeat(3) @(negedge clk);
        if(!deadline || !one_deadline) $fatal;
        $display("PALETTE_SCHEDULER_TB_PASS N=1/16, unique outputs, last=%0d, forced deadline detected",last);$finish;
    end
endmodule

`timescale 1ns/1ps
module sine_compact_tb;
reg clk=0;always #10 clk=~clk;reg [11:0] addr=0;wire signed [15:0] a,b;
refinement_sine dut(clk,addr,a);palette_sine oracle(clk,addr,b);
integer i;reg [31:0] rng=32'h13579bdf;
task check;begin @(posedge clk);#1;if(a!==b) $fatal(1,"sine mismatch addr=%h %d %d",addr,a,b);@(negedge clk);end endtask
initial begin #1;if(a!==b) $fatal(1,"initial mismatch");@(negedge clk);
for(i=0;i<4096;i=i+1) begin addr=i;check;end
for(i=0;i<2000;i=i+1) begin rng={rng[30:0],rng[31]^rng[21]^rng[1]^rng[0]};addr=rng[11:0];check;end
addr=12'hxxx;check;addr=12'hzzz;check;addr=0;check;
$display("SINE_COMPACT_TB_PASS all4096 random2000 XZ_hold initial single_clock bit_exact");$finish;end
endmodule

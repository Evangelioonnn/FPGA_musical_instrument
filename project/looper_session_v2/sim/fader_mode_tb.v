`timescale 1ns/1ps
module fader_mode_tb;
reg clk=0;always #10 clk=~clk;reg rst=1,mix=0,sv=0,ar=1,mr=1;reg [59:0] raw=0;
reg [47:0] ht={12'd256,12'd512,12'd1024,12'd4095};reg [67:0] mt={4{17'd65536}};reg [3:0] invalidate=0;
wire sr,av,mv;wire [59:0] ad;wire [67:0] md;wire [3:0] acquired;
fader_mode_adapter dut(clk,rst,mix,sv,sr,raw,ht,mt,invalidate,av,ar,ad,mv,mr,md,acquired);
task scan;input [11:0] volume,a,b,c,d;begin
@(negedge clk);while(!sr) @(negedge clk);raw={d,c,b,a,volume};sv=1;
@(negedge clk);sv=0;
end endtask
initial begin repeat(4) @(negedge clk);rst=0;
scan(1234,0,0,0,0);
if(ad[11:0]!=1234 || ad[59:12]!==ht || acquired!=0 || mv) $fatal(1,"initial pickup/CH0");
scan(0,4095,1024,512,256);if(acquired!=15 || ad[59:12]!==ht) $fatal(1,"harmonic pickup");
scan(0,4093,1026,514,254);if(ad[59:12]!==ht) $fatal(1,"small jitter");
scan(4095,3500,800,400,200);if(ad[23:12]!=3500 || ad[11:0]!=4095) $fatal(1,"edit movement");
ht=ad[59:12];mix=1;repeat(3) @(negedge clk);
scan(3000,3500,800,400,200);if(md!==mt || acquired!=0 || ad[59:12]!==ht) $fatal(1,"mode jumped");
scan(3000,4095,4095,4095,4095);if(acquired!=15 || md!==mt) $fatal(1,"mixer pickup");
scan(0,2048,1024,0,4095);if(md[16:0]!=32768 || md[50:34]!=0 || ad[59:12]!==ht) $fatal(1,"relative gains/CH0 independent");
mt=md;mt[16:0]=50000;invalidate=1;repeat(2) @(negedge clk);invalidate=0;
scan(0,0,1024,0,4095);if(acquired[0] || md[16:0]!=50000) $fatal(1,"external owner reacquire");
scan(0,4095,1024,0,4095);if(!acquired[0] || md[16:0]!=65536) $fatal(1,"crossing pickup");
repeat(3) @(negedge clk);ar=0;mr=0;scan(500,4095,4095,4095,4095);
repeat(10) @(negedge clk);if(sr || !av || !mv) $fatal(1,"consumer backpressure");
ar=1;mr=1;repeat(4) @(negedge clk);if(!sr) $fatal(1,"bundle drain");
$display("FADER_MODE_TB_PASS master_independent edit_mix_pickup jitter crossing external_owner stable_bundle");$finish;end
initial begin #1000000;$fatal(1,"fader watchdog");end
endmodule

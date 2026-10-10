`timescale 1ns/1ps
// Serial device model, not a direct data injection into the reader.
module mcp3208_reader_tb #(parameter HALF=4,SCAN=2000);
reg clk=0;always #10 clk=~clk;reg rst=1,ready=1,miso=0;
wire sclk,mosi,cs,valid;wire [95:0] data;wire [31:0] seq,skipped;
mcp3208_reader #(.HALF_CYCLES(HALF),.SCAN_CYCLES(SCAN)) dut(clk,rst,miso,sclk,mosi,cs,valid,ready,data,seq,skipped);
integer sys_cycles=0,edge_cycle=0;always @(posedge clk) sys_cycles=sys_cycles+1;
always @(sclk) if(!cs && !rst) begin
 if(sclk && edge_cycle!=0 && sys_cycles-edge_cycle!=HALF) $fatal(1,"SPI half-period");
 edge_cycle=sys_cycles;
end
integer clocks=0,transfers=0,ch=0,i,scans=0;reg [23:0] command;reg [11:0] sample_value;
reg [95:0] held;
function [11:0] expected;input integer channel;begin expected=channel==0 ? 0 : channel==7 ? 4095 : 12'h123+channel*12'h111;end endfunction
always @(negedge cs) begin clocks=0;command=0;miso=0;edge_cycle=0;end
always @(posedge sclk) begin
    command={command[22:0],mosi};clocks=clocks+1;
    if(clocks==10) begin
        if(command[9:3]!==7'b0000011) $fatal(1,"MCP start/single-ended framing %h",command);
        ch=command[2:0];sample_value=expected(ch);
    end
end
always @(negedge sclk) if(!cs) begin
    if(clocks>=12 && clocks<=23) miso=sample_value[23-clocks];else miso=0;
end
always @(posedge cs) if(!rst && clocks!=0) begin
    if(clocks!=24 || ch!=(transfers%8)) $fatal(1,"channel/order/clock count");
    transfers=transfers+1;
end
always @(posedge clk) if(!rst && valid && ready) begin
    for(i=0;i<8;i=i+1) if(data[i*12+:12]!==expected(i)) $fatal(1,"ADC value channel%d %h",i,data[i*12+:12]);
    scans=scans+1;
end
initial begin repeat(4) @(negedge clk);rst=0;wait(scans==3);@(negedge clk);ready=0;
wait(valid);held=data;repeat(SCAN*3+SCAN/4) @(negedge clk);
if(data!==held || !valid || skipped<2) $fatal(1,"coherent scan backpressure overwrite");
ready=1;wait(scans>=5);
$display("MCP3208_READER_TB_PASS mode0 command24 channels8 endpoints coherent_scan backpressure skipped=%0d",skipped);$finish;end
initial begin #50000000;$fatal(1,"ADC watchdog");end
endmodule

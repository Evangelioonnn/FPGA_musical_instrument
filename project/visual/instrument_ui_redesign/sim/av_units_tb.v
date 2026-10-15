`timescale 1ns/1ps
module av_units_tb;
 reg clk=0,pclk=0,rst=1;always #10 clk=~clk;always #3.333 pclk=~pclk;
 reg valid=0;reg [2367:0] snapshot=0;reg [255:0] extension=0;reg [15:0] keys=0;
 wire we,publish;wire [10:0] addr;wire [11:0] data;
 av_page_writer writer(clk,rst,1'b1,valid,snapshot,extension,keys,we,addr,data,publish);
 reg [11:0] page[0:2047];integer written=0,completed=0;
 always @(posedge clk) if(we && !rst) begin
   if(addr!==written[10:0])$fatal(1,"page address expected %d got %d",written,addr);
   page[addr]=data;written=written+1;
   if(publish)begin if(written!=2048)$fatal(1,"short page");completed=completed+1;written=0;end
 end
 wire we25,pub25;wire [10:0] addr25;wire [11:0] data25;
 reg [2367:0] snapshot25=0;
 av_page_writer #(.KEYS(25),.SPLIT(12),.DIATONIC(0)) writer25(clk,rst,1'b1,valid,snapshot25,256'd0,25'h1FFFFFF,we25,addr25,data25,pub25);
 integer count25=0,done25=0;
 always @(posedge clk) if(we25 && !rst)begin
   if(addr25>=1920 && addr25<1945)begin
      if(data25[6:0]!==7'd48+(addr25-1920) || !data25[7] || !data25[11] || (|data25[10:8]))$fatal(1,"25 chromatic keys mismatch %d %h",addr25,data25);
      count25=count25+1;
   end
   if(pub25)begin if(count25!=25)$fatal(1,"25-key record count");done25=1;end
 end
 task check_char;input integer row,col;input [7:0] expected;
 begin if(page[row*64+col][7:0]!==expected)$fatal(1,"text r%0d c%0d got %0d expected %0d",row,col,page[row*64+col][7:0],expected);end endtask
 reg wr=0,pub=0,frame=0;reg [3:0] wa=0,ra=0;reg [15:0] wd=0;
 wire ready,have,changed;wire [15:0] rd;
 av_frame_ram #(.AW(4),.DW(16)) banks(clk,rst,pclk,rst,wr,wa,wd,pub,ready,frame,ra,rd,have,changed);
 task fill;input [15:0] tag;integer k;
 begin for(k=0;k<16;k=k+1)begin @(negedge clk);wr=1;wa=k;wd=tag+k;pub=k==15;end @(negedge clk);wr=0;pub=0;end endtask
 task swap;begin @(negedge pclk);frame=1;@(negedge pclk);frame=0;end endtask
 task read_bank;input [15:0] tag;integer k;
 begin for(k=0;k<16;k=k+1)begin @(negedge pclk);ra=k;@(posedge pclk);#1;if(rd!==tag+k)$fatal(1,"RAM coherency");end end endtask
 reg [10:0] px=0,py=0;wire [10:0] text_addr;reg [11:0] text_data=0;
 wire [8:0] unused_scope;wire [23:0] rgb;wire ode,ohs,ovs;
 always @(posedge pclk)text_data<=page[text_addr];
 av_renderer renderer(pclk,rst,px,py,1'b1,1'b0,1'b0,1'b1,1'b0,1'b0,1'b0,text_addr,text_data,unused_scope,18'd0,rgb,ode,ohs,ovs);
 task check_pixel;input [10:0] x,y;input [23:0] expected;
 begin @(negedge pclk);px=x;py=y;repeat(8)@(posedge pclk);#0.2;
   if(rgb!==expected)$fatal(1,"pixel (%d,%d): %h expected %h",x,y,rgb,expected);
 end endtask
 integer k;
 initial begin
  repeat(5)@(negedge clk);rst=0;
  snapshot[80:64]=17'h10000;snapshot[97:81]=17'h10000;snapshot[100:98]=2;
  snapshot[101]=1;snapshot[113:109]=3;snapshot[130:128]=5;
  snapshot[120:114]=48;snapshot[127:121]=60;snapshot[165:157]=128;
  snapshot[362]=1;snapshot[363]=1;snapshot[359+:3]=0;snapshot[352+:7]=52;
  snapshot[362+64]=1;snapshot[364+64]=1;snapshot[359+64+:3]=4;snapshot[352+64+:7]=61;
  snapshot[362+128]=1;snapshot[359+128+:3]=2;snapshot[352+128+:7]=72;
  snapshot25[120:114]=48;snapshot25[127:121]=60;keys=16'h0081;
  @(negedge clk);valid=1;@(negedge clk);valid=0;
  repeat(80)@(negedge clk);
  // A new publication during formatting must not change the captured frame.
  snapshot=0;keys=0;valid=1;@(negedge clk);valid=0;
  wait(completed==1 && done25);@(negedge clk);
  check_char(7,45,"1");check_char(7,46,"0");check_char(7,47,"0");
  check_char(11,45,"5");check_char(11,46,"0");
  check_char(14,48,"0");check_char(14,49,"3");check_char(14,54,"0");check_char(14,55,"1");
  check_char(19,41,"-");check_char(22,13,"4");check_char(22,14,"8");
  if(page[1920]!==12'h8B0 || page[1924]!==12'hC34 || page[1933]!==12'h13D || page[1944]!==12'hA48)$fatal(1,"physical / held / sustained / released key mapping");
  if(page[1945]!==112 || page[1946]!==56)$fatal(1,"gain / wet meter endpoints");
  for(k=0;k<25;k=k+1)if(page[1920+k][6:0]!==48+k)$fatal(1,"chromatic note record order");
  check_pixel(50,810,24'hD7BA7C); // C: pressed
  check_pixel(110,810,24'h202527); // C#: unconnected black key
  check_pixel(370,810,24'hD7BA7C); // E: held voice
  check_pixel(390,810,24'hE2E3DB); // no black key between E and F
  check_pixel(886,810,24'hE2E3DB); // no black key between B and C
  check_pixel(906,810,24'hD7BA7C); // next C: physical key 7
  check_pixel(1020,810,24'h67577F); // C#: sustained old voice
  check_pixel(1830,810,24'h98A5AC); // final C: released tail
  check_pixel(1400,260,24'hD7BA7C); // gain full-scale
  check_pixel(1750,390,24'h373B3D); // maximum 50% wet is half the full-scale track
  fill(16'h1000);repeat(6)@(negedge clk);
  if(ready || have)$fatal(1,"bank published before frame boundary");
  swap();read_bank(16'h1000);repeat(6)@(negedge clk);
  if(!ready || !have)$fatal(1,"bank ack missing");
  fill(16'h2000);read_bank(16'h1000);swap();read_bank(16'h2000);
  rst=1;repeat(4)@(negedge clk);rst=0;repeat(4)@(negedge clk);
  if(have || !ready)$fatal(1,"reset did not invalidate both banks");
  $display("AV_UNITS_TB_PASS atomic snapshot 16/25-key adapters H/S/R 25-key geometry endpoints colors frame-boundary ownership reset");$finish;
 end
 initial begin #1000000;$fatal(1,"timeout");end
endmodule


`timescale 1ns/1ps
module av_wave_auto_tb;
 reg clk=0,pclk=0,rst=1;always #10 clk=~clk;always #3.333 pclk=~pclk;
 reg sv=0;reg signed [15:0] l=0,r=0;
 wire ready,we,pub;wire [8:0] wa;wire [39:0] wd;
 av_wave_capture dut(clk,rst,ready,sv,l,r,we,wa,wd,pub);
 reg frame=0;reg [8:0] read_index=0;wire [39:0] rd;wire have,changed;
 reg render_mode=0;wire [8:0] plot_address;
 wire [8:0] ra=render_mode ? plot_address : read_index;
 reg [10:0] px=257,py=255;wire [23:0] rgb;wire de,hs,vs;
 av_wave_renderer renderer(pclk,rst,px,py,1'b1,1'b0,1'b0,have,changed,frame,plot_address,rd,rgb,de,hs,vs);
 task pixel;input integer x,y;input [23:0] expected_rgb;
 begin
   @(negedge pclk);px=x;py=y;repeat(8)@(negedge pclk);
   if(rgb!==expected_rgb)$fatal(1,"scaled actual-bank pixel got %h expected %h",rgb,expected_rgb);
 end endtask
 task character;input integer x,y;input [7:0] c;
 begin
   @(negedge pclk);px=x*32;py=y*32;repeat(8)@(negedge pclk);
   if(renderer.character2!==c)$fatal(1,"diagnostic text got %h expected %h",renderer.character2,c);
 end endtask
 av_frame_ram #(.AW(9),.DW(40)) bank(clk,rst,pclk,rst,we,wa,wd,pub,ready,frame,ra,rd,have,changed);
 reg [39:0] expected[0:511];integer writes=0,publications=0;
 integer i,j,peak,shift,lv,rv,scaled_l,scaled_r;reg [39:0] saved;
 always @(posedge clk)if(!rst && we)begin
   if(wa!==writes[8:0] || wd!==expected[writes])$fatal(1,"packet index=%d got=%h expected=%h",wa,wd,expected[writes]);
   if(pub !== (writes==511))$fatal(1,"publish position");
   writes=writes+1;if(pub)publications=publications+1;
 end
 task sample;input integer a,b;begin
   @(negedge clk);sv=1;l=a;r=b;@(negedge clk);sv=0;
   repeat(2)@(negedge clk);
 end endtask
 task run_case;input integer amplitude,expected_peak,expected_shift,last_extreme;
 begin
   wait(ready);writes=0;peak=expected_peak;shift=expected_shift;
   // Force a rising crossing, then exactly 512 consecutive pairs.
   sample(-1,-1);
   for(i=0;i<512;i=i+1)begin
     lv=(i%2==0)?amplitude:-amplitude;rv=(i%2==0)?amplitude/2:-amplitude/2;
     if(i==511 && last_extreme!=0)lv=last_extreme;
     scaled_l=(lv*(1<<shift))>>>8;scaled_r=(rv*(1<<shift))>>>8;
     expected[i]={4'hA,shift[3:0],scaled_r[7:0],peak[15:8],scaled_l[7:0],peak[7:0]};
     sample(lv,rv);
   end
   wait(writes==512);repeat(5)@(negedge clk);
   if(ready)$fatal(1,"bank ownership not waiting");
   saved=bank.memory[512];
   // Incoming audio continues while display is stalled; no republish/write.
   repeat(2100)sample(3000,-2000);
   if(writes!=512 || bank.memory[512]!==saved)$fatal(1,"pending frame overwritten");
   repeat(5)@(negedge pclk);frame=1;@(negedge pclk);frame=0;
   repeat(3)@(negedge pclk);if(!have)$fatal(1,"no committed frame");
   for(j=0;j<512;j=j+1)begin
      read_index=j;@(negedge pclk);
      if(rd!==expected[j])$fatal(1,"async bank sample %d got %h expected %h",j,rd,expected[j]);
   end
   if(amplitude==64 && last_extreme==0)begin
      render_mode=1;
      pixel(257,255,24'hD7BA7C);pixel(257,639,24'h78BEA1);
      pixel(257,300,24'h1C2225);
      character(51,8,"0");character(52,8,"0");character(53,8,"4");character(54,8,"0");
      character(53,21,"8");render_mode=0;
   end
 end endtask
 initial begin
   repeat(6)@(negedge clk);rst=0;
   run_case(64,64,8,0); // Old top-byte path: 0/-1. New trace: +64/-64.
   run_case(128,128,7,0);
   run_case(512,512,5,0);
   run_case(64,32767,0,32767); // Last sample must participate in gain.
   run_case(64,32768,0,-32768); // Unsigned abs(-32768), no overflow.
   run_case(0,0,0,0); // Silence remains zero; no fabricated waveform.
   if(publications!=6)$fatal(1,"publication count");
   $display("AV_WAVE_AUTO_TB_PASS six windows exact512 stereo scale peak lastsample negativefullscale silence async-bank backpressure");$finish;
 end
 initial begin #10000000;$fatal(1,"timeout");end
endmodule

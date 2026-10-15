`timescale 1ns/1ps
module av_wave_units_tb;
 reg clk=0,pclk=0,rst=1;always #10 clk=~clk;always #3.333 pclk=~pclk;
 reg button_n=1;wire audio_button,page;
 av_navigation #(.DEBOUNCE_CYCLES(3),.LONG_CYCLES(60),.PULSE_CYCLES(15)) nav(clk,rst,button_n,audio_button,page);
 // Exercise the same debouncer that the unchanged audio panel uses.
 wire core_down,core_press,core_release;
 playable_button #(.DEBOUNCE_CYCLES(3)) core_filter(clk,rst,audio_button,core_down,core_press,core_release);
 integer short_count=0,page_count=0;reg last_page=0;
 always @(posedge clk)if(!rst)begin
   if(core_release)short_count=short_count+1;
   if(page!=last_page)begin page_count=page_count+1;last_page=page;end
 end
 wire selected;reg frame=0;
 av_page_select select(pclk,rst,page,frame,selected);
 task tick;input integer n;begin repeat(n)@(negedge clk);end endtask
 task swap;begin @(negedge pclk);frame=1;@(negedge pclk);frame=0;end endtask
 reg ready=1,sample_valid=0;reg signed [15:0] left=0,right=0;
 wire wr,publish;wire [8:0] addr;wire [31:0] data;
 av_pcm_window capture(clk,rst,ready,sample_valid,left,right,wr,addr,data,publish);
 integer writes=0,pubs=0;reg [31:0] memory[0:511];
 always @(posedge clk)if(wr)begin
   if(addr!==writes[8:0])$fatal(1,"nonconsecutive PCM addresses");
   memory[addr]=data;writes=writes+1;
   if(publish)begin if(writes!=512)$fatal(1,"short capture");pubs=pubs+1;writes=0;end
 end
 task sample;input signed [15:0] l,r;
 begin @(negedge clk);left=l;right=r;sample_valid=1;@(negedge clk);sample_valid=0;end endtask
 integer i;integer old_pubs;
 initial begin
   tick(6);rst=0;tick(5);
   // A bounce shorter than the stable interval must not reach audio or page.
   button_n=0;tick(1);button_n=1;tick(10);
   if(short_count!=0 || page_count!=0)$fatal(1,"bounce generated action");
   button_n=0;tick(20);button_n=1;tick(35);
   if(short_count!=1 || page_count!=0)$fatal(1,"short key action");
   button_n=0;tick(100);
   if(!page || page_count!=1 || short_count!=1 || !audio_button)$fatal(1,"long key leaked to audio");
   tick(150);if(page_count!=1)$fatal(1,"long hold repeats");
   if(selected!==0)$fatal(1,"page changed before frame boundary");swap();tick(3);
   if(selected!==1)$fatal(1,"page did not commit");
   button_n=1;tick(30);if(short_count!=1)$fatal(1,"long release changes timbre");
   button_n=0;tick(100);button_n=1;tick(30);swap();tick(3);
   if(page_count!=2 || selected!==0 || short_count!=1)$fatal(1,"return page");
   // Rising zero crossing is sample zero, with exact independent L/R words.
   sample(-123,16'h3456);sample(0,16'h7654);
   for(i=1;i<512;i=i+1)sample(i*37,-i*51);
   if(pubs!=1 || memory[0]!==32'h76540000)$fatal(1,"trigger sample not included");
   for(i=1;i<512;i=i+1)if($signed(memory[i][15:0])!==i*37 || $signed(memory[i][31:16])!==-i*51)$fatal(1,"PCM channel/data mismatch %d",i);
   ready=0;old_pubs=pubs;
   for(i=0;i<2100;i=i+1)sample(i[0] ? 100 : -100,200);
   if(pubs!=old_pubs || writes!=0)$fatal(1,"unowned bank overwritten");
   ready=1;sample(-1,1);sample(1,-1);for(i=1;i<512;i=i+1)sample(1,-1);
   if(pubs!=2)$fatal(1,"capture not resumed");
   // Silence has a bounded timeout and must publish a new zero window.
   rst=1;tick(4);rst=0;writes=0;
   for(i=0;i<2560;i=i+1)sample(0,0);
   if(pubs!=3 || writes!=0)$fatal(1,"silence timeout/capture length");
   for(i=0;i<512;i=i+1)if(memory[i]!==0)$fatal(1,"silence data");
   $display("AV_WAVE_UNITS_TB_PASS bounce short/long isolation frame-only page 512 exact PCM stereo trigger silence ownership resume");$finish;
 end
 initial begin #1000000;$fatal(1,"timeout");end
endmodule

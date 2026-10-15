`timescale 1ns/1ps
// Test-only source: synthetic snapshot/PCM. The physical top uses real core.
module av_video_tb;
 reg clk=0,pclk=0,rst=1;always #10 clk=~clk;always #3.333 pclk=~pclk;
 wire [10:0] x,y;wire de,hs,vs,frame;
 av_timing timing(pclk,rst,x,y,de,hs,vs,frame);
 reg valid=0;reg [2367:0] snapshot=0;reg [255:0] extension=0;reg [15:0] keys=16'h8125;
 wire tw,tp,tr,tv,tc;wire [10:0] ta,tra;wire [11:0] td,trd;
 av_page_writer page(clk,rst,tr,valid,snapshot,extension,keys,tw,ta,td,tp);
 av_frame_ram #(.AW(11),.DW(12)) text_frames(clk,rst,pclk,rst,tw,ta,td,tp,tr,frame,tra,trd,tv,tc);
 wire [8:0] unused_scope_address;
 wire [23:0] rgb;wire ode,ohs,ovs;
 av_renderer renderer(pclk,rst,x,y,de,hs,vs,tv,1'b0,tc,frame,tra,trd,unused_scope_address,18'd0,rgb,ode,ohs,ovs);
 reg [7:0] de_history=0,hs_history=0,vs_history=0;
 integer pixels=0,frames=0,cycles=0,last_frame=0,active=0,fd=0;
 always @(posedge pclk) begin
  if(rst)begin de_history=0;hs_history=0;vs_history=0;end
  else begin
   de_history={de_history[6:0],de};hs_history={hs_history[6:0],hs};vs_history={vs_history[6:0],vs};
   cycles=cycles+1;
   if(frame)begin
     if(frames>0 && cycles-last_frame!=2475000)$fatal(1,"wrong frame length");
     if(frames>0 && active!=2073600)$fatal(1,"wrong active pixel count %d",active);
     if(frames==2)begin
       if(pixels!=2073600)$fatal(1,"wrong rendered pixel count");
       $fclose(fd);$display("AV_VIDEO_TB_PASS 25-key Chinese performance page 2200x1125 active1920x1080 RGB-control latency8");$finish;
     end
     frames=frames+1;last_frame=cycles;active=0;
   end
   if(de)begin
    active=active+1;
    if(x>=1920 || y>=1080)$fatal(1,"invalid active coordinates");
   end
   #0.1;
   if(ode!==de_history[7] || ohs!==hs_history[7] || ovs!==vs_history[7])$fatal(1,"RGB/control alignment");
   if(!ode && rgb!==0)$fatal(1,"nonblack blanking");
   if(frames==2 && ode)begin pixels=pixels+1;$fwrite(fd,"%c%c%c",rgb[23:16],rgb[15:8],rgb[7:0]);end
  end
 end
 initial begin
   fd=$fopen("av_preview.ppm","wb");$fwrite(fd,"P6\n1920 1080\n255\n");
   repeat(6)@(negedge clk);rst=0;
   snapshot[31:0]=32'h1234;snapshot[80:64]=17'h10000;snapshot[97:81]=17'h8000;
   snapshot[100:98]=0;snapshot[113:109]=0;snapshot[101]=1;snapshot[102]=1;
   snapshot[120:114]=48;snapshot[127:121]=60;snapshot[174:166]=256;snapshot[183:175]=64;
   snapshot[192:184]=32;snapshot[201:193]=16;snapshot[105]=1;snapshot[165:157]=32;
   snapshot[362]=1;snapshot[363]=1;snapshot[359+:3]=0;snapshot[352+:7]=52;
   snapshot[362+64]=1;snapshot[364+64]=1;snapshot[359+64+:3]=2;snapshot[352+64+:7]=61;
   snapshot[362+128]=1;snapshot[359+128+:3]=3;snapshot[352+128+:7]=72;
   extension[119:108]=512;extension[47:32]=68;extension[63:48]=6;extension[79:64]=32768;extension[95:80]=3;
   valid=1;@(negedge clk);valid=0;
 end
 initial begin #40000000;$fatal(1,"timeout");end
endmodule


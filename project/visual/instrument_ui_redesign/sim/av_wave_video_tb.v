`timescale 1ns/1ps
// Known test-only PCM bank: verify independent amplitude endpoints/zero,
// connected segments, frame-selected page, and complete raster timing.
module av_wave_video_tb;
 reg clk=0,rst=1;always #3.333 clk=~clk;
 reg [10:0] px=0,py=0;reg hd=1,hh=0,hv=0;
 wire [8:0] sample_addr;reg [39:0] sample_data;
 wire [23:0] prgb;wire pd,ph,pv;
 always @(posedge clk)case(sample_addr)
    0:sample_data<=40'hA080807F00;1:sample_data<=40'hA07F808000;
    2:sample_data<=0;default:sample_data<=0;
 endcase
 av_wave_renderer probe(clk,rst,px,py,hd,hh,hv,1'b1,1'b0,1'b0,sample_addr,sample_data,prgb,pd,ph,pv);
 task pixel;input [10:0] x,y;input [23:0] expected;
 begin @(negedge clk);px=x;py=y;repeat(7)@(negedge clk);if(prgb!==expected)$fatal(1,"wave pixel (%d,%d) got %h expected %h",x,y,prgb,expected);end endtask
 wire [10:0] x,y;wire de,hs,vs,frame;
 av_timing timing(clk,rst,x,y,de,hs,vs,frame);
 reg requested=0;wire selected;
 av_page_select select(clk,rst,requested,frame,selected);
 wire [10:0] text_addr;wire [8:0] addr;wire [39:0] data;
 // Test-only stereo sawtooth window crosses the actual 512-pair bank.
 reg [9:0] write_index=0;
 wire ready,have,changed;
 wire write_enable=!rst && !write_index[9] && ready;
 wire [39:0] fixture={8'hA0,~write_index[7:0],8'h80,write_index[7:0],8'd0};
 always @(posedge clk)if(rst)write_index<=0;else if(write_enable)write_index<=write_index+1'b1;
 av_frame_ram #(.AW(9),.DW(40)) banks(clk,rst,clk,rst,write_enable,write_index[8:0],fixture,
     write_enable && write_index==511,ready,frame,addr,data,have,changed);
 wire [23:0] rgb;wire ode,ohs,ovs;
 av_display display(clk,rst,selected,x,y,de,hs,vs,1'b0,have,1'b0,changed,frame,text_addr,12'd32,addr,data,rgb,ode,ohs,ovs);
 reg [8:0] dh=0,hhist=0,vhist=0;integer frames=0,cycles=0,last_frame=0,active=0,pixels=0,fd=0;
 reg tests_done=0;integer checked_samples=0;reg [39:0] expected_data;
 always @(posedge clk)if(!rst && have && checked_samples<512 && addr==checked_samples)begin
   expected_data={8'hA0,~addr[7:0],8'h80,addr[7:0],8'd0};
   #0.1;if(data!==expected_data)$fatal(1,"frame PCM bank data");checked_samples=checked_samples+1;
 end
 always @(posedge clk)if(!rst)begin
   dh={dh[7:0],de};hhist={hhist[7:0],hs};vhist={vhist[7:0],vs};cycles=cycles+1;
   if(frame)begin
     if(frames>0 && (cycles-last_frame!=2475000 || active!=2073600))$fatal(1,"raster counts");
     if(frames==2)begin
       if(pixels!=2073600 || !tests_done || checked_samples!=512)$fatal(1,"preview/test coverage");
       $fclose(fd);$display("AV_WAVE_VIDEO_TB_PASS complete1920x1080 latency9 page-frame fullscale/zero stereo pixels blanking");$finish;
     end
     frames=frames+1;last_frame=cycles;active=0;
   end
   if(de)active=active+1;
   #0.1;
   if(ode!==dh[8] || ohs!==hhist[8] || ovs!==vhist[8])$fatal(1,"control pipeline alignment");
   if(!ode && rgb!==0)$fatal(1,"blanking RGB");
   if(frames==0 && selected!==0)$fatal(1,"midframe navigation");
   if(frames==2 && ode)begin pixels=pixels+1;$fwrite(fd,"%c%c%c",rgb[23:16],rgb[15:8],rgb[7:0]);end
 end
 initial begin
   fd=$fopen("wave_preview.ppm","wb");$fwrite(fd,"P6\n1920 1080\n255\n");
   repeat(6)@(negedge clk);rst=0;
   pixel(257,192,24'hD7BA7C); // L + fullscale (sample 0).
   pixel(257,799,24'h78BEA1); // R - fullscale (sample 0).
   pixel(261,319,24'hD7BA7C);pixel(261,671,24'h78BEA1); // independent zero centers.
   pixel(270,300,24'h1C2225); // no fabricated trace away from zero.
   tests_done=1;requested=1;
 end
 initial begin #40000000;$fatal(1,"timeout");end
endmodule

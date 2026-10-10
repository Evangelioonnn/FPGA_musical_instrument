`timescale 1ns/1ps
// Behavioral clock/lock stimulus only, not a PLL analog or vendor primitive model.
module Gowin_PLL(input wire clkin,mdclk,output reg clkout0=0,
 output wire clkout1,output reg lock=0);
 assign clkout1=1'b0;
 always #3.333 clkout0=~clkout0;
 initial begin #700;lock=1;#25000;lock=0;#700;lock=1;end
endmodule

module pll_clock_model_tb;
 reg sys_clk=0;always #10 sys_clk=~sys_clk;
 wire [3:0] rows;wire bck,ws,din,pa,led,sclk,mosi,cs,digest;
 refinement_pll_audit_top dut(.sys_clk(sys_clk),.arst(1'b0),.enc_a(1'b1),.enc_b(1'b1),
   .adc_miso(1'b0),.client_seed(1'b1),.button_n(3'b111),.matrix_col_n(4'b1111),
   .matrix_row_n(rows),.hp_bck(bck),.hp_ws(ws),.hp_din(din),.pa_en(pa),.status_led(led),
   .adc_sclk(sclk),.adc_mosi(mosi),.adc_cs_n(cs),.audit_digest(digest));
 integer frames=0,epochs=0;
 always @(posedge sys_clk) if(dut.harness.link.raw_pcm_valid) frames=frames+1;
 always @(negedge dut.pll.lock) begin
   #2;
   if(dut.reset_epoch!==1'b1 || dut.harness.link.platform.reset_active!==1'b1)
     $fatal(1,"PLL loss did not assert platform reset");
   epochs=epochs+1;
 end
 initial begin
   #100;
   if(dut.reset_epoch!==1'b1 || dut.harness.link.rst!==1'b1)
     $fatal(1,"unlocked startup not held in reset");
   @(posedge dut.pll.lock);wait(dut.harness.link.rst===1'b0);
   #1000;
   if((^digest)===1'bx) $fatal(1,"clock consumer unknown after startup");
   @(negedge dut.pll.lock);#100;
   if(dut.harness.link.state_valid || dut.harness.link.pcm_valid || dut.harness.link.reply_valid)
     $fatal(1,"stale transport valid during PLL reset");
   @(posedge dut.pll.lock);wait(dut.harness.link.rst===1'b0);
   #90000;
   if(epochs<1 || frames<3 || dut.harness.link.protocol_error || (^digest)===1'bx)
     $fatal(1,"PLL lock recovery failed frames=%0d",frames);
   $display("PLL_CLOCK_MODEL_TB_PASS actual_wrapper unlocked_startup lock_loss epoch_reset recovery PCM; behavioral_clock_only");
   $finish;
 end
 initial begin #200000;$fatal(1,"PLL wrapper watchdog");end
endmodule

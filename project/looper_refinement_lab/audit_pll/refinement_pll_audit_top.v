// Audit only. The reused, board-tested display PLL supplies the observer domain.
// This is not a display implementation and its placeholder GPIO cannot be wired.
module refinement_pll_audit_top(
 input wire sys_clk,arst,enc_a,enc_b,adc_miso,client_seed,
 input wire [2:0] button_n,input wire [3:0] matrix_col_n,output wire [3:0] matrix_row_n,
 output wire hp_bck,hp_ws,hp_din,pa_en,status_led,adc_sclk,adc_mosi,adc_cs_n,audit_digest);
 wire observer_clk,unused_serial_clk,pll_lock;
 Gowin_PLL pll(.clkin(sys_clk),.clkout0(observer_clk),.clkout1(unused_serial_clk),
   .lock(pll_lock),.mdclk(sys_clk));
 wire reset_epoch=arst||!pll_lock;
 refinement_audit_top harness(.sys_clk(sys_clk),.observer_clk(observer_clk),.arst(reset_epoch),
   .enc_a(enc_a),.enc_b(enc_b),.adc_miso(adc_miso),.client_seed(client_seed),
   .button_n(button_n),.matrix_col_n(matrix_col_n),.matrix_row_n(matrix_row_n),
   .hp_bck(hp_bck),.hp_ws(hp_ws),.hp_din(hp_din),.pa_en(pa_en),.status_led(status_led),
   .adc_sclk(adc_sclk),.adc_mosi(adc_mosi),.adc_cs_n(adc_cs_n),.audit_digest(audit_digest));
endmodule

module looper_refinement_top #(
    parameter ROW_CYCLES=2500,DEBOUNCE_FRAMES=8,BUTTON_CYCLES=150000,
    AUDIO_N=32,PLUCK_N=12,LONG_CYCLES=50000000,ENCODER_CYCLES=2500
)(input wire sys_clk,enc_a,enc_b,input wire [2:0] button_n,input wire [3:0] matrix_col_n,
    output wire [3:0] matrix_row_n,output wire hp_bck,hp_ws,hp_din,pa_en,status_led);
looper_platform #(.ROW_CYCLES(ROW_CYCLES),.DEBOUNCE_FRAMES(DEBOUNCE_FRAMES),.BUTTON_CYCLES(BUTTON_CYCLES),
    .AUDIO_N(AUDIO_N),.PLUCK_N(PLUCK_N),.LONG_CYCLES(LONG_CYCLES),.ENCODER_CYCLES(ENCODER_CYCLES)) platform(
    .sys_clk(sys_clk),.reset_request(1'b0),.enc_a(enc_a),.enc_b(enc_b),.button_n(button_n),.matrix_col_n(matrix_col_n),
    .matrix_row_n(matrix_row_n),.hp_bck(hp_bck),.hp_ws(hp_ws),.hp_din(hp_din),.pa_en(pa_en),.status_led(status_led),
    .adc_valid(1'b0),.adc_data(60'd0),.mixer_valid(1'b0),.mixer_data(68'd0),
    .remote_valid(1'b0),.remote_addr(5'd0),.remote_value(32'd0));
endmodule

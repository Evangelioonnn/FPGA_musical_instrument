module ram8_top(
    input wire sys_clk,enc_a,enc_b,input wire [2:0] button_n,
    input wire [3:0] matrix_col_n,output wire [3:0] matrix_row_n,
    output wire hp_bck,hp_ws,hp_din,pa_en,status_led
);
    audio_v2_top #(.PLUCK_N(8)) instrument(
        sys_clk,enc_a,enc_b,button_n,matrix_col_n,matrix_row_n,
        hp_bck,hp_ws,hp_din,pa_en,status_led);
endmodule

module five_01_balance(
    input wire sys_clk,enc_a,enc_b,input wire [2:0] button_n,
    input wire [3:0] matrix_col_n,output wire [3:0] matrix_row_n,
    output wire hp_bck,hp_ws,hp_din,pa_en,status_led);
    gallery_top #(.BALANCE_MODE(1)) dut(sys_clk,enc_a,enc_b,button_n,matrix_col_n,matrix_row_n,
        hp_bck,hp_ws,hp_din,pa_en,status_led);
endmodule

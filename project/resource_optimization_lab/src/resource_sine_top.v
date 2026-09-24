module resource_shared_sine_top(
    input wire sys_clk,enc_a,enc_b,input wire [2:0] button_n,
    input wire [3:0] matrix_col_n,output wire [3:0] matrix_row_n,
    output wire hp_bck,hp_ws,hp_din,pa_en,status_led
);
    reg [5:0] startup=0;
    wire rst=!startup[5];
    always @(posedge sys_clk) if(rst) startup<=startup+1'b1;
    assign matrix_row_n=4'b1111;
    wire signed [31:0] mix;
    wire valid;
    wire sample_ce;
    // Eight notes spanning the same useful range as the matrix candidate.
    wire [255:0] steps={32'd77454108,32'd73192711,32'd69148468,32'd65301915,
                        32'd61647784,32'd58178948,32'd54898533,32'd51899744};
    shared_sine8_probe probe(sys_clk,rst,sample_ce,8'hff,steps,valid,mix);
    wire signed [15:0] sample = mix[15:0];
    pt8211_tx tx(sys_clk,rst,sample,sample,sample_ce,hp_bck,hp_ws,hp_din);
    assign pa_en=1'b0;
    assign status_led=valid ^ enc_a ^ enc_b ^ button_n[0] ^ matrix_col_n[0];
endmodule

module resource_duplicated_sine_top(
    input wire sys_clk,enc_a,enc_b,input wire [2:0] button_n,
    input wire [3:0] matrix_col_n,output wire [3:0] matrix_row_n,
    output wire hp_bck,hp_ws,hp_din,pa_en,status_led
);
    reg [5:0] startup=0;
    wire rst=!startup[5];
    always @(posedge sys_clk) if(rst) startup<=startup+1'b1;
    assign matrix_row_n=4'b1111;
    wire signed [31:0] mix;
    wire valid;
    wire sample_ce;
    wire [255:0] steps={32'd77454108,32'd73192711,32'd69148468,32'd65301915,
                        32'd61647784,32'd58178948,32'd54898533,32'd51899744};
    duplicated_sine8_probe probe(sys_clk,rst,sample_ce,8'hff,steps,valid,mix);
    wire signed [15:0] sample = mix[15:0];
    pt8211_tx tx(sys_clk,rst,sample,sample,sample_ce,hp_bck,hp_ws,hp_din);
    assign pa_en=1'b0;
    assign status_led=valid ^ enc_a ^ enc_b ^ button_n[0] ^ matrix_col_n[0];
endmodule

module resource_shared_mult_top(
    input wire sys_clk,enc_a,enc_b,input wire [2:0] button_n,
    input wire [3:0] matrix_col_n,output wire [3:0] matrix_row_n,
    output wire hp_bck,hp_ws,hp_din,pa_en,status_led
);
    reg [5:0] startup=0; wire rst=!startup[5];
    always @(posedge sys_clk) if(rst) startup<=startup+1'b1;
    assign matrix_row_n=4'b1111;
    reg [255:0] a_bus=256'h0000000100000002000000030000000400000005000000060000000700000008;
    reg [255:0] b_bus=256'h0000001100000012000000130000001400000015000000160000001700000018;
    wire sample_ce; wire valid; wire [511:0] products;
    always @(posedge sys_clk) if(sample_ce) begin
        a_bus<=a_bus+256'h0000000100000002000000030000000400000005000000060000000700000008;
        b_bus<=b_bus+256'h0000001100000012000000130000001400000015000000160000001700000018;
    end
    shared_mult8_probe probe(sys_clk,rst,sample_ce,a_bus,b_bus,valid,products);
    wire signed [15:0] sample=products[15:0];
    wire [15:0] checksum=products[15:0]^products[31:16]^products[47:32]^products[63:48]^
        products[79:64]^products[95:80]^products[111:96]^products[127:112]^
        products[143:128]^products[159:144]^products[175:160]^products[191:176]^
        products[207:192]^products[223:208]^products[239:224]^products[255:240]^
        products[271:256]^products[287:272]^products[303:288]^products[319:304]
        ^products[335:320]^products[351:336]^products[367:352]^products[383:368]
        ^products[399:384]^products[415:400]^products[431:416]^products[447:432]
        ^products[463:448]^products[479:464]^products[495:480]^products[511:496];
    pt8211_tx tx(sys_clk,rst,sample,sample,sample_ce,hp_bck,hp_ws,hp_din);
    assign pa_en=1'b0;assign status_led=valid^checksum[0]^enc_a^enc_b^button_n[0]^matrix_col_n[0];
endmodule

module resource_duplicated_mult_top(
    input wire sys_clk,enc_a,enc_b,input wire [2:0] button_n,
    input wire [3:0] matrix_col_n,output wire [3:0] matrix_row_n,
    output wire hp_bck,hp_ws,hp_din,pa_en,status_led
);
    reg [5:0] startup=0; wire rst=!startup[5];
    always @(posedge sys_clk) if(rst) startup<=startup+1'b1;
    assign matrix_row_n=4'b1111;
    reg [255:0] a_bus=256'h0000000100000002000000030000000400000005000000060000000700000008;
    reg [255:0] b_bus=256'h0000001100000012000000130000001400000015000000160000001700000018;
    wire sample_ce; wire valid; wire [511:0] products;
    always @(posedge sys_clk) if(sample_ce) begin
        a_bus<=a_bus+256'h0000000100000002000000030000000400000005000000060000000700000008;
        b_bus<=b_bus+256'h0000001100000012000000130000001400000015000000160000001700000018;
    end
    duplicated_mult8_probe probe(sys_clk,rst,sample_ce,a_bus,b_bus,valid,products);
    wire signed [15:0] sample=products[15:0];
    wire [15:0] checksum=products[15:0]^products[31:16]^products[47:32]^products[63:48]^
        products[79:64]^products[95:80]^products[111:96]^products[127:112]^
        products[143:128]^products[159:144]^products[175:160]^products[191:176]
        ^products[207:192]^products[223:208]^products[239:224]^products[255:240]
        ^products[271:256]^products[287:272]^products[303:288]^products[319:304]
        ^products[335:320]^products[351:336]^products[367:352]^products[383:368]
        ^products[399:384]^products[415:400]^products[431:416]^products[447:432]
        ^products[463:448]^products[479:464]^products[495:480]^products[511:496];
    pt8211_tx tx(sys_clk,rst,sample,sample,sample_ce,hp_bck,hp_ws,hp_din);
    assign pa_en=1'b0;assign status_led=valid^checksum[0]^enc_a^enc_b^button_n[0]^matrix_col_n[0];
endmodule

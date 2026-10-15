// C-local PHY wrapper. Original colorbar source remains unchanged.
module av_dvi_tx(input wire sys_clk, startup_reset, pixel_clock, ddr_bit_clock, rstn,
 input wire den,hsync,vsync,input wire [23:0] pixel_data,
 output wire [1:0] tmds_clk,tmds_d0,tmds_d1,tmds_d2);
 wire enable_clocks,serializer_reset,phy_pixel_clock,phy_serial_clock;
 av_serializer_start startup(sys_clk,startup_reset,enable_clocks,serializer_reset);
 DCE pixel_gate(.CLKIN(pixel_clock),.CE(enable_clocks),.CLKOUT(phy_pixel_clock));
 DHCE serial_gate(.CLKIN(ddr_bit_clock),.CEN(!enable_clocks),.CLKOUT(phy_serial_clock));
 wire [5:0] ctrl={4'b0,vsync,hsync};
 wire [29:0] codes;
 wire [2:0] serial_bits;
 wire [1:0] lanes[0:2];
 genvar i;
 generate for(i=0;i<3;i=i+1) begin: lanes_gen
  dvi_tx_tmds_enc encoder(pixel_clock,rstn,den,pixel_data[8*i+:8],ctrl[2*i+:2],codes[10*i+:10]);
  OSER10 serializer(.Q(serial_bits[i]),
   .D0(codes[10*i]),.D1(codes[10*i+1]),.D2(codes[10*i+2]),.D3(codes[10*i+3]),.D4(codes[10*i+4]),
   .D5(codes[10*i+5]),.D6(codes[10*i+6]),.D7(codes[10*i+7]),.D8(codes[10*i+8]),.D9(codes[10*i+9]),
   .PCLK(phy_pixel_clock),.FCLK(phy_serial_clock),.RESET(serializer_reset));
  ELVDS_OBUF data_buffer(.I(serial_bits[i]),.O(lanes[i][1]),.OB(lanes[i][0]));
 end endgenerate
 assign tmds_d0=lanes[0];assign tmds_d1=lanes[1];assign tmds_d2=lanes[2];
 ELVDS_OBUF clock_buffer(.I(phy_pixel_clock),.O(tmds_clk[1]),.OB(tmds_clk[0]));
endmodule

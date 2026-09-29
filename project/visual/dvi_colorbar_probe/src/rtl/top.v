module top_mod (
    input clk,
    input rstn,

    output       tmds_clk_n_0,
    output       tmds_clk_p_0,
    output [2:0] tmds_d_n_0,
    output [2:0] tmds_d_p_0
);

parameter video_hlength		= 2200;// Total H length
parameter video_vlength		= 1125;// Total v length
parameter video_hsync_pol	= 1;   // 
parameter video_hsync_len	= 44;  // HSYNC pulse width
parameter video_hbp_len		= 148; // horizontal backporch

parameter video_h_visible	= 1920;// horizontal visible
parameter video_vsync_pol	= 1;   
parameter video_vsync_len	= 5;   // VSYNC pulse width
parameter video_vbp_len		= 36;  // vertical back porch
parameter video_v_visible	= 1080; // vertical visible

/* PLL wires */
wire pll_lock;
wire clk_p;  // DIV clk
wire clk_p5; // TMDS clk

/* video timing */
wire		 den_int;
wire [13: 0] pixel_x;
wire [13: 0] pixel_y;
wire        dvi_den;
wire        dvi_hsync;
wire        dvi_vsync;

/* Test pattern */
wire [23:0] dvi_data;
wire        video_line_start;
        
Gowin_PLL hdmi_pll (
    .clkin  (clk),
    .mdclk  (1'b0),
    .lock   (pll_lock),
    .clkout0(clk_p),
    .clkout1(clk_p5)
);

// First pixel @(h_pos, v_pos) = (192,41)
video_timing_ctrl #(
    .video_hlength      (video_hlength),
    .video_vlength      (video_vlength),

    .video_hsync_pol    (video_hsync_pol),
    .video_hsync_len    (video_hsync_len),
    .video_hbp_len      (video_hbp_len),
    .video_h_visible    (video_h_visible),

    .video_vsync_pol    (video_vsync_pol),
    .video_vsync_len    (video_vsync_len),
    .video_vbp_len      (video_vbp_len),
    .video_v_visible    (video_v_visible)
)   video_timing_ctrl(
    .pixel_clock		(clk_p),
    .rstn				(rstn),
    .ext_sync			(1'b0),

    .timing_h_pos		(),
    .timing_v_pos		(),
    .pixel_x			(pixel_x),
    .pixel_y			(pixel_y),

    .video_hsync		(dvi_hsync),
    .video_vsync		(dvi_vsync),
    .video_den			(dvi_den),
    .video_line_start	(video_line_start)
);

test_pattern_gen colorbar_pattern (
    .den_int          (dvi_den),
    .pixel_x          (pixel_x),
    .pixel_y          (pixel_y),

    .video_pixel_even (dvi_data)
);

dvi_tx_top dvi_tx (
    .pixel_clock  (clk_p),
    .ddr_bit_clock(clk_p5),
    .rstn         (rstn),
    .den          (dvi_den),
    .hsync        (dvi_hsync),
    .vsync        (dvi_vsync),
    .pixel_data   (dvi_data),

    .tmds_clk     ({tmds_clk_p_0, tmds_clk_n_0}),
    .tmds_d0      ({tmds_d_p_0[0], tmds_d_n_0[0]}),
    .tmds_d1      ({tmds_d_p_0[1], tmds_d_n_0[1]}),
    .tmds_d2      ({tmds_d_p_0[2], tmds_d_n_0[2]})
);

endmodule

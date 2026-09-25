module test_pattern_gen (
	input				den_int,
	input	[13	: 0]	pixel_x,
	input	[13	: 0]	pixel_y,

	output	[23 : 0]	video_pixel_even
);
/*
	What Happens on Every Pixel Clock?
	1. h_pos increments
	2. timing signals updated
	3. visible region checked
	4. current pixel generated
	5. RGB values transmitted
*/

wire [3: 0]		pattern_index;
wire [23: 0]	pattern_value;

reg	[23: 0]	pattern_colours_t [15: 0];
	
	
initial begin
	// Color Format = 			 R__G__B
	pattern_colours_t[0]  = 24'hFF_00_00; // Red
	pattern_colours_t[1]  = 24'hFF_7F_00; // Orange
	pattern_colours_t[2]  = 24'hFF_FF_00; // Yellow
	pattern_colours_t[3]  = 24'h7F_FF_00; // Lime
	pattern_colours_t[4]  = 24'h00_FF_00; // Green
	pattern_colours_t[5]  = 24'h00_FF_7F; // Spring Green
	pattern_colours_t[6]  = 24'h00_FF_FF; // Cyan
	pattern_colours_t[7]  = 24'h00_7F_FF; // Sky Blue
	pattern_colours_t[8]  = 24'h00_00_FF; // Blue
	pattern_colours_t[9]  = 24'h7F_00_FF; // Violet
	pattern_colours_t[10] = 24'hFF_00_FF; // Magenta
	pattern_colours_t[11] = 24'hFF_00_7F; // Pink

	pattern_colours_t[12] = 24'hFF_FF_FF; // White
	pattern_colours_t[13] = 24'hC0_C0_C0; // Silver
	pattern_colours_t[14] = 24'h40_40_40; // Dark Gray
	pattern_colours_t[15] = 24'h00_00_00; // Black
end
	
assign pattern_index = pixel_x[7 +: 4];
assign pattern_value = pattern_colours_t[pattern_index];

assign video_pixel_even = (den_int) ? pattern_value : 24'h000000;

endmodule

// 1024 mathematical sine points with 16-bit fractional linear interpolation.
// ROM reads are synchronous. The two neighbouring addresses share one ROM.
// delta is within [-202,202], so the interpolation multiply is 9 x 17 bits.
module fm_sine_interp(
    input wire clk, input wire rst, input wire request,
    input wire [31:0] phase,
    output reg valid, output reg signed [15:0] value
);
wire [9:0] address_a = phase[31:22];
wire [9:0] address_b = address_a + 10'd1;
wire signed [15:0] sine_a, sine_b;
wire signed [16:0] difference = {sine_b[15], sine_b} - {sine_a[15], sine_a};
reg [15:0] fraction;
reg pending_rom, pending_product;
reg signed [15:0] base;
reg signed [25:0] delta_product;
wire signed [25:0] rounded_delta = delta_product + 26'sd32768;
fm_sine_rom rom(.clk(clk), .address_a(address_a), .address_b(address_b),
    .value_a(sine_a), .value_b(sine_b));
always @(posedge clk) begin
    if (rst) begin
        pending_rom <= 1'b0; pending_product <= 1'b0; valid <= 1'b0;
        fraction <= 16'd0; base <= 16'sd0; delta_product <= 26'sd0;
        value <= 16'sd0;
    end else begin
        pending_rom <= request;
        pending_product <= pending_rom;
        valid <= pending_product;
        if (request) fraction <= phase[21:6];
        if (pending_rom) begin
            base <= sine_a;
            delta_product <= $signed(difference[8:0]) * $signed({1'b0, fraction});
        end
        if (pending_product) value <= $signed(base) + (rounded_delta >>> 16);
    end
end
endmodule

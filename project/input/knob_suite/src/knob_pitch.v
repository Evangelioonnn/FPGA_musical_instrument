// Optional pitch control for future input binding. Not connected to the five
// board modes. Q16 bend clamps to 0.5..2; glide is phase-step units per sample.
module knob_pitch(
    input wire clk,rst,sample_ce,fresh,
    input wire [31:0] base_step,input wire [17:0] bend_q16,
    input wire [30:0] glide_delta,
    output reg [31:0] current_step
);
    wire [17:0] bend=bend_q16<32768 ? 18'd32768 : bend_q16>131072 ? 18'd131072 : bend_q16;
    reg [49:0] product;
    wire [33:0] scaled=product[49:16];
    wire [31:0] target=scaled>2147483647 ? 32'h7fffffff : scaled[31:0];
    reg fresh_pending;
    always @(posedge clk) begin
        if(rst)begin product<=0;current_step<=0;fresh_pending<=0;end
        else begin
            product<=base_step*bend;
            if(fresh)fresh_pending<=1;
            if(sample_ce)begin
                fresh_pending<=0;
                if(fresh || fresh_pending || glide_delta==0)current_step<=target;
                else if(current_step<target)
                    current_step<=target-current_step<=glide_delta ? target : current_step+glide_delta;
                else current_step<=current_step-target<=glide_delta ? target : current_step-glide_delta;
            end
        end
    end
endmodule

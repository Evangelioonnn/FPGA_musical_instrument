// Diagnostic only: suppress padding clocks while retaining the exact sample grid.
module pt8211_format_tx (
    input wire clk, rst,
    input wire signed [15:0] sample_left, sample_right,
    input wire format16_request,
    output wire sample_ce,
    output reg hp_bck=0, hp_ws=0, hp_din=0,
    output reg format16_active=0
);
    reg [4:0] bck_div=0;
    reg [5:0] bit_count=0;
    reg half_phase=0;
    reg [15:0] left_hold=0, right_hold=0;
    wire padding=(bit_count<4) || (bit_count>=20 && bit_count<24);
    assign sample_ce=!rst && bck_div==12 && half_phase && bit_count==39;
    always @(posedge clk) begin
        if(rst) begin
            bck_div<=0; bit_count<=0; half_phase<=0;
            left_hold<=0; right_hold<=0;
            hp_bck<=0; hp_ws<=0; hp_din<=0; format16_active<=0;
        end else if(bck_div==12) begin
            bck_div<=0;
            half_phase<=~half_phase;
            // Registered pin, not combinational gating. Data-slot edges are unchanged.
            if(half_phase || (format16_active && padding)) hp_bck<=0;
            else hp_bck<=1;
            if(half_phase) begin
                if(bit_count==19) begin
                    hp_ws<=1; bit_count<=20; hp_din<=0;
                end else if(bit_count==39) begin
                    hp_ws<=0; bit_count<=0; hp_din<=0;
                    left_hold<=sample_left; right_hold<=sample_right;
                    format16_active<=format16_request;
                end else if(bit_count>=3 && bit_count<=18) begin
                    bit_count<=bit_count+1'b1;
                    hp_din<=right_hold[18-bit_count];
                end else if(bit_count>=23 && bit_count<=38) begin
                    bit_count<=bit_count+1'b1;
                    hp_din<=left_hold[38-bit_count];
                end else begin
                    bit_count<=bit_count+1'b1; hp_din<=0;
                end
            end
        end else bck_div<=bck_div+1'b1;
    end
endmodule

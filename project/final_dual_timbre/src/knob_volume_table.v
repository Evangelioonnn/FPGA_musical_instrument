// 0=mute; 1..24: -69..0 dB in 3 dB increments. Q16 amplitude.
module knob_volume_table(input wire [4:0] index,output reg [16:0] gain);
    always @* case(index)
        5'd0: gain=17'd0;
        5'd1: gain=17'd23;
        5'd2: gain=17'd33;
        5'd3: gain=17'd46;
        5'd4: gain=17'd66;
        5'd5: gain=17'd93;
        5'd6: gain=17'd131;
        5'd7: gain=17'd185;
        5'd8: gain=17'd261;
        5'd9: gain=17'd369;
        5'd10: gain=17'd521;
        5'd11: gain=17'd735;
        5'd12: gain=17'd1039;
        5'd13: gain=17'd1467;
        5'd14: gain=17'd2072;
        5'd15: gain=17'd2927;
        5'd16: gain=17'd4135;
        5'd17: gain=17'd5841;
        5'd18: gain=17'd8250;
        5'd19: gain=17'd11654;
        5'd20: gain=17'd16462;
        5'd21: gain=17'd23253;
        5'd22: gain=17'd32846;
        5'd23: gain=17'd46396;
        5'd24: gain=17'd65536;
        default:gain=17'd65536;
    endcase
endmodule

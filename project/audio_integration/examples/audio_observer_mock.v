`include "../include/audio_api_v2.vh"
// Synthetic observation-only source for C. It does not claim musical output.
module audio_observer_mock #(parameter KEYS=25,FRAME_CYCLES=1040,SNAPSHOT_FRAMES=1024)(
    input wire clk,rst,
    output reg pcm_valid,
    output reg signed [15:0] pcm_left,pcm_right,
    output reg [31:0] pcm_index,
    output reg snapshot_valid,
    output reg [2367:0] snapshot_data,
    output reg [255:0] snapshot_extension,
    output reg [KEYS-1:0] snapshot_keys,
    output wire [127:0] capabilities
);
    localparam [15:0] KEY_WIDTH=KEYS;
    assign capabilities={16'd320,16'd2368,8'd64,8'd0,8'd2,8'h3d,KEY_WIDTH,16'd12,16'd32,16'd2};
    integer frame_clock,snapshot_clock;
    reg [31:0] next_index,next_sequence;
    reg [4:0] key_position;
    wire signed [15:0] triangle_value=next_index[11] ?
        $signed({1'b0,~next_index[10:0],4'b0})-16'sd16384 :
        $signed({1'b0,next_index[10:0],4'b0})-16'sd16384;
    always @(posedge clk) begin
        if(rst) begin
            frame_clock<=0;snapshot_clock<=0;next_index<=0;next_sequence<=0;key_position<=0;
            pcm_valid<=0;pcm_left<=0;pcm_right<=0;pcm_index<=0;
            snapshot_valid<=0;snapshot_data<=0;snapshot_extension<=0;snapshot_keys<=0;
        end else begin
            pcm_valid<=0;snapshot_valid<=0;
            if(frame_clock==FRAME_CYCLES-1) begin
                frame_clock<=0;pcm_valid<=1;pcm_left<=triangle_value;pcm_right<=triangle_value;
                pcm_index<=next_index;next_index<=next_index+1'b1;
                if(snapshot_clock==SNAPSHOT_FRAMES-1) begin
                    snapshot_clock<=0;snapshot_valid<=1;snapshot_data<=0;snapshot_extension<=0;
                    snapshot_keys<=1'b1<<key_position;
                    snapshot_data[31:0]<=next_sequence;snapshot_data[63:32]<=next_sequence;
                    snapshot_data[80:64]<=17'd8249;snapshot_data[97:81]<=17'd8249;
                    snapshot_data[100:98]<=`AUDIO_PRESET_PIANO;
                    snapshot_data[120:114]<=7'd48;snapshot_data[127:121]<=7'd60;
                    snapshot_data[166+:36]<={9'd16,9'd32,9'd64,9'd256};
                    snapshot_data[281:266]<=16'd16384;
                    snapshot_data[320+:64]<={2'd0,16'd32768,1'b0,1'b1,1'b1,1'b1,3'd0,7'd48+key_position,next_sequence};
                    snapshot_extension[31:0]<=next_index;
                    snapshot_extension[47:32]<=16'd68;snapshot_extension[63:48]<=16'd6;
                    snapshot_extension[79:64]<=16'd32768;snapshot_extension[95:80]<=16'd3;
                    snapshot_extension[177:146]<=0;snapshot_extension[183:178]<=6'd32;
                    snapshot_extension[189:184]<=6'd12;snapshot_extension[197:190]<=8'd2;
                    snapshot_extension[205:198]<=8'd2;
                    next_sequence<=next_sequence+1'b1;
                    key_position<=key_position==KEYS-1 ? 0 : key_position+1'b1;
                end else snapshot_clock<=snapshot_clock+1;
            end else frame_clock<=frame_clock+1;
        end
    end
endmodule

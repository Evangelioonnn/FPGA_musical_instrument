// One on-board WS2812B: 50MHz, 1.26us/bit, >=100us reset, 50Hz refresh.
module playable_led #(parameter REFRESH_CYCLES=1000000)(
    input wire clk,rst,input wire [1:0] timbre,
    input wire sustain,release_mode,blocked,rejected,
    output reg led
);
    reg [19:0] refresh;
    reg [5:0] bit_tick;
    reg [4:0] bit_index;
    reg transmitting;
    reg [23:0] shift;
    reg [4:0] blink;
    reg [2:0] overload;
    reg [7:0] red,green,blue,brightness;
    always @* begin
        brightness=sustain?8'd32:8'd8;
        red=0;green=0;blue=0;
        case(timbre)
            0:blue=brightness;
            1:green=brightness;
            default:begin red=brightness;blue=brightness;end
        endcase
        if(release_mode && timbre==1) begin red=brightness;green=brightness;blue=0;end
        if(release_mode && blink>=12) begin red=0;green=0;blue=0;end
        if(overload!=0) begin red=32;green=8;blue=0;end
        if(blocked) begin red=16;green=0;blue=0;end
    end
    always @(posedge clk) begin
        if(rst) begin
            refresh<=0;bit_tick<=0;bit_index<=0;transmitting<=0;shift<=0;
            led<=0;blink<=0;overload<=0;
        end else begin
            if(rejected) overload<=5;
            if(refresh==REFRESH_CYCLES-1) begin
                refresh<=0;transmitting<=1;bit_tick<=0;bit_index<=23;shift<={green,red,blue};
                blink<=blink==24?0:blink+1'b1;
                if(overload!=0 && !rejected) overload<=overload-1'b1;
            end else refresh<=refresh+1'b1;
            if(transmitting) begin
                led<=bit_tick<(shift[23]?35:18);
                if(bit_tick==62) begin
                    bit_tick<=0;shift<={shift[22:0],1'b0};
                    if(bit_index==0) begin transmitting<=0;led<=0;end
                    else bit_index<=bit_index-1'b1;
                end else bit_tick<=bit_tick+1'b1;
            end else led<=0;
        end
    end
endmodule

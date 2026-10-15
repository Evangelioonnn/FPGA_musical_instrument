// Y12: a short release generates one filtered audio timbre-key pulse;
// a long hold changes only the page. No audio reset is generated.
module av_navigation #(
    parameter DEBOUNCE_CYCLES=150000,LONG_CYCLES=40000000,PULSE_CYCLES=500000,
    parameter LW=(LONG_CYCLES>1?$clog2(LONG_CYCLES):1),
    parameter PW=(PULSE_CYCLES>1?$clog2(PULSE_CYCLES+1):1)
)(input wire clk,rst,button_n,output wire audio_button_n,output reg page=0);
    wire down,pressed,released;
    playable_button #(.DEBOUNCE_CYCLES(DEBOUNCE_CYCLES)) filter(clk,rst,button_n,down,pressed,released);
    reg [LW-1:0] held=0;
    reg fired=0;
    reg [PW-1:0] pulse=0;
    assign audio_button_n=(pulse==0);
    always @(posedge clk) begin
        if(rst)begin held<=0;fired<=0;pulse<=0;page<=0;end
        else begin
            if(pulse!=0)pulse<=pulse-1'b1;
            if(down && !fired)begin
                if(held==LONG_CYCLES-1)begin page<=!page;fired<=1;end
                else held<=held+1'b1;
            end
            if(released)begin
                if(!fired)pulse<=PULSE_CYCLES;
                held<=0;fired<=0;
            end
        end
    end
endmodule

// A scalar page selection crosses domains, then commits in vertical blanking.
module av_page_select(input wire clk,rst,requested,frame_start,output reg selected=0);
    (* async_reg="true" *) reg page_meta=0,page_sync=0;
    always @(posedge clk)begin
        if(rst)begin page_meta<=0;page_sync<=0;selected<=0;end
        else begin
            page_meta<=requested;page_sync<=page_meta;
            if(frame_start)selected<=page_sync;
        end
    end
endmodule

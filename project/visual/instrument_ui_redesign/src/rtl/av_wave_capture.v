// Display-only, two-pass normalization. Audio never consumes ready from here.
// Packet: {4'hA, gain_log2[3:0], scaled_R[7:0], peak[15:8],
//          scaled_L[7:0], peak[7:0]}. Metadata belongs to this exact window.
module av_wave_capture(input wire clk,rst,ready,sample_valid,
    input wire signed [15:0] left,right,
    output wire wr_en,output wire [8:0] wr_addr,
    output wire [39:0] wr_data,output wire publish);
    localparam COLLECT=0,PREP=1,PRIME=2,WRITE=3;
    reg [1:0] state=COLLECT;
    wire raw_we,raw_done;wire [8:0] raw_addr;wire [31:0] raw_data;
    av_pcm_window raw(clk,rst,ready && state==COLLECT,sample_valid,left,right,
        raw_we,raw_addr,raw_data,raw_done);
    (* syn_ramstyle="block_ram" *) reg [31:0] samples[0:511];
    reg [31:0] read_data;
    reg [8:0] read_addr=0,index=0;
    reg [15:0] peak=0,frame_peak=0;
    reg [3:0] shift=0;
    wire [15:0] abs_l=left[15] ? (~left+16'd1) : left;
    wire [15:0] abs_r=right[15] ? (~right+16'd1) : right;
    wire [15:0] pair_peak=abs_l>abs_r ? abs_l : abs_r;
    wire [15:0] next_peak=pair_peak>peak ? pair_peak : peak;
    function [3:0] choose_shift;
        input [15:0] p;
        begin
            if(p==0 || p>=16384)choose_shift=0;
            else if(p>=8192)choose_shift=1;
            else if(p>=4096)choose_shift=2;
            else if(p>=2048)choose_shift=3;
            else if(p>=1024)choose_shift=4;
            else if(p>=512)choose_shift=5;
            else if(p>=256)choose_shift=6;
            else if(p>=128)choose_shift=7;
            else choose_shift=8;
        end
    endfunction
    // The peak-selected gain guarantees signed 16-bit range, including -32768.
    wire [15:0] scaled_l=read_data[15:0]<<shift;
    wire [15:0] scaled_r=read_data[31:16]<<shift;
    assign wr_en=!rst && state==WRITE && ready;
    assign wr_addr=index;
    assign wr_data={4'hA,shift,scaled_r[15:8],frame_peak[15:8],scaled_l[15:8],frame_peak[7:0]};
    assign publish=wr_en && (&index);
    always @(posedge clk)begin
        if(raw_we)samples[raw_addr]<=raw_data;
        // Request the next word on the edge that consumes the current word.
        if(state==PRIME || (state==WRITE && ready))read_data<=samples[read_addr];
        if(rst)begin state<=COLLECT;peak<=0;frame_peak<=0;shift<=0;index<=0;read_addr<=0;end
        else case(state)
            COLLECT:if(raw_we)begin
                peak<=next_peak;
                if(raw_done)begin frame_peak<=next_peak;state<=PREP;end
            end
            PREP:begin shift<=choose_shift(frame_peak);read_addr<=0;index<=0;state<=PRIME;end
            PRIME:begin read_addr<=1;state<=WRITE;end
            WRITE:if(ready)begin
                read_addr<=read_addr+1'b1;index<=index+1'b1;
                if(&index)begin state<=COLLECT;peak<=0;end
            end
        endcase
    end
endmodule

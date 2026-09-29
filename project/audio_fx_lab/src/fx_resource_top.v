// Resource/clock probe only; these pins are not a playable-control interface.
module fx_resource_top(
    input wire sys_clk,enc_a,enc_b,
    input wire [2:0] button_n,
    input wire [3:0] matrix_col_n,
    output wire [3:0] matrix_row_n,
    output wire hp_bck,hp_ws,hp_din,pa_en,status_led
);
    reg [5:0] startup=0;
    wire rst=!startup[5];
    always @(posedge sys_clk) if(rst) startup<=startup+1'b1;
    reg [8:0] io_first,io_sync;
    always @(posedge sys_clk) begin
        io_first<={enc_a,enc_b,button_n,matrix_col_n};
        io_sync<=io_first;
    end
    wire sample_ce;
    wire [16:0] factor;
    wire [6:0] depth;
    vibrato_factor lfo(sys_clk,rst,sample_ce,!io_sync[5],
        {2'b00,io_sync[8:7],io_sync[3:0]},io_sync[8:6],factor,depth);
    reg [23:0] phase;
    reg signed [15:0] sample;
    reg sample_valid;
    always @(posedge sys_clk) begin
        if(rst) begin phase<=0;sample<=0;sample_valid<=0;end
        else begin
            sample_valid<=sample_ce;
            if(sample_ce) begin
                phase<=phase+factor;
                sample<=phase[23] ? -16'sd4096 : 16'sd4096;
            end
        end
    end
    wire valid,clip,ready,busy,overrun;
    wire signed [15:0] left,right;
    wire [8:0] wet;
    short_room_reverb room(sys_clk,rst,sample_valid,sample,!io_sync[6],
        {2'b00,~io_sync[3:0],3'b000},valid,left,right,clip,ready,busy,overrun,wet);
    pt8211_tx tx(sys_clk,rst,left,right,sample_ce,hp_bck,hp_ws,hp_din);
    assign pa_en=1'b0;
    assign status_led=ready && !overrun && !clip;
    assign matrix_row_n[0]=wet[5]?1'b0:1'bz;
    assign matrix_row_n[1]=depth[5]?1'b0:1'bz;
    assign matrix_row_n[2]=factor[8]?1'b0:1'bz;
    assign matrix_row_n[3]=valid?1'b0:1'bz;
endmodule

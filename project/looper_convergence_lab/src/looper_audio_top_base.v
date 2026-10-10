module audio_v2_top #(
    parameter PLUCK_N=12,ROW_CYCLES=2500,DEBOUNCE_FRAMES=8,BUTTON_CYCLES=150000,
    parameter LONG_CYCLES=50000000,EC11_CYCLES=2500,EC11_SAMPLES=2,WITH_FX=1
)(
    input wire sys_clk,enc_a,enc_b,input wire [2:0] button_n,
    input wire [3:0] matrix_col_n,output wire [3:0] matrix_row_n,
    output wire hp_bck,hp_ws,hp_din,pa_en,status_led
);
    reg [5:0] startup=0;
    wire rst=!startup[5];
    always @(posedge sys_clk) if(rst) startup<=startup+1'b1;
    wire [3:0] row_low;
    genvar r;
    generate for(r=0;r<4;r=r+1) begin: rows
        assign matrix_row_n[r]=row_low[r] ? 1'b0 : 1'bz;
    end endgenerate
    wire [15:0] keys;
    wire changed,frame,ghost,all_released;
    matrix_scanner #(.ROW_CYCLES(ROW_CYCLES),.DEBOUNCE_FRAMES(DEBOUNCE_FRAMES)) scanner(
        sys_clk,rst,matrix_col_n,row_low,keys,changed,frame,ghost,all_released);
    wire step_valid;wire signed [1:0] step;
    ec11_input #(.SAMPLE_CYCLES(EC11_CYCLES),.AB_SAMPLES(EC11_SAMPLES)) encoder(
        sys_clk,rst,enc_a,enc_b,1'b1,step_valid,step,,,);
    wire sample_ce,final_valid;
    wire signed [15:0] final_left,final_right;
    wire [2:0] timbre;wire [4:0] control_mode;
    wire sustain,sostenuto,blocked,rejected,deadline,muting,clip_seen;
    wire [31:0] occupied,held,gated;
    audio_v2_core #(.PLUCK_N(PLUCK_N),.BUTTON_CYCLES(BUTTON_CYCLES),.LONG_CYCLES(LONG_CYCLES),.WITH_FX(WITH_FX)) core(
        .clk(sys_clk),.rst(rst),.sample_ce(sample_ce),.keys(keys),.changed(changed),
        .ghost(ghost),.all_released(all_released),.button_n(button_n),.step_valid(step_valid),.step(step),
        .host_valid(1'b0),.host_addr(5'd0),.host_value(32'd0),
        .adc_valid(1'b0),.adc_ch0(12'd0),.adc_ch1(12'd0),.adc_ch2(12'd0),.adc_ch3(12'd0),.adc_ch4(12'd0),
        .final_valid(final_valid),.final_left(final_left),.final_right(final_right),
        .selected_preset(timbre),.control_mode(control_mode),.sustain(sustain),.sostenuto(sostenuto),
        .blocked(blocked),.rejected(rejected),.deadline_missed(deadline),.occupied(occupied),.held(held),.gated(gated),
        .muting(muting),.clip_seen(clip_seen));
    output_tx tx(sys_clk,rst,final_left,final_right,sample_ce,hp_bck,hp_ws,hp_din);
    gallery_led indicator(sys_clk,rst,timbre,sustain,control_mode[2:0],
        blocked||muting||deadline,rejected,status_led);
    assign pa_en=1'b0;
endmodule

// Local playable-gallery fork; baseline sources remain unchanged.
// Isolated fork of palette module at db653ef; see SPEC.md.
module gallery_top #(parameter PROFILE=6,parameter TONE_SHIFT=0,parameter BALANCE_MODE=0,parameter EDGE_SPACING=0,parameter INVERT=0,parameter ROW_CYCLES=2500,parameter DEBOUNCE_FRAMES=8,
    parameter BUTTON_CYCLES=150000,parameter LONG_CYCLES=50000000,
    parameter EC11_CYCLES=2500,parameter EC11_SAMPLES=2)(
    input wire sys_clk,enc_a,enc_b,input wire [2:0] button_n,
    input wire [3:0] matrix_col_n,output wire [3:0] matrix_row_n,
    output wire hp_bck,hp_ws,hp_din,pa_en,status_led
);
    reg [5:0] startup=0;
    wire rst=!startup[5];
    always @(posedge sys_clk) if(rst) startup<=startup+1'b1;
    wire [3:0] row_low;
    genvar row;
    generate for(row=0;row<4;row=row+1) begin: row_drivers
        assign matrix_row_n[row]=row_low[row]?1'b0:1'bz;
    end endgenerate
    wire [15:0] keys;
    wire changed,frame,ghost,all_released;
    matrix_scanner #(.ROW_CYCLES(ROW_CYCLES),.DEBOUNCE_FRAMES(DEBOUNCE_FRAMES)) scanner(
        sys_clk,rst,matrix_col_n,row_low,keys,changed,frame,ghost,all_released);
    wire step_valid;
    wire signed [1:0] step;
    wire encoder_pressed,encoder_changed,encoder_invalid;
    ec11_input #(.SAMPLE_CYCLES(EC11_CYCLES),.AB_SAMPLES(EC11_SAMPLES)) encoder(
        sys_clk,rst,enc_a,enc_b,1'b1,step_valid,step,encoder_pressed,
        encoder_changed,encoder_invalid);
    wire sample_ce,final_valid;
    wire signed [15:0] final_sample;
    wire [2:0] timbre,control_mode;
    wire sustain,release_mode,blocked,rejected,fault,deadline,muting;
    wire [4:0] volume_index;
    wire [2:0] reference_release_index;
    wire [7:0] occupied;
    gallery_engine #(.PROFILE(PROFILE),.TONE_SHIFT(TONE_SHIFT),.BALANCE_MODE(BALANCE_MODE),.N(8),.BUTTON_CYCLES(BUTTON_CYCLES),.LONG_CYCLES(LONG_CYCLES)) engine(
        sys_clk,rst,sample_ce,keys,changed,ghost,all_released,button_n,step_valid,step,
        final_valid,final_sample,timbre,control_mode,sustain,release_mode,blocked,volume_index,
        reference_release_index,rejected,fault,occupied,deadline,muting);
    wire signed [15:0] dac_sample;
    output_polarity #(.INVERT(INVERT)) polarity(final_sample,dac_sample);
    output_tx #(.EDGE_SPACING(EDGE_SPACING)) tx(sys_clk,rst,dac_sample,dac_sample,sample_ce,hp_bck,hp_ws,hp_din);
    gallery_led indicator(sys_clk,rst,timbre,sustain,control_mode,
        blocked||muting||deadline,rejected,status_led);
    assign pa_en=1'b0;
endmodule

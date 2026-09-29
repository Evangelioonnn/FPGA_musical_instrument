module noise_lab_core #(parameter ROW_CYCLES=2500,DEBOUNCE_FRAMES=8,
    parameter BUTTON_CYCLES=150000,LONG_CYCLES=50000000,
    parameter GATE_UNUSED=0,GAIN_SHIFT=0,OSR=1)(
    input wire sys_clk,timbre_button_n,
    input wire [3:0] matrix_col_n,
    output wire [3:0] matrix_row_n,
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

    wire tx_frame_ce,render_ce,final_valid;
    wire signed [15:0] final_sample,dac_sample;
    wire [1:0] timbre;
    wire sustain,release_mode,blocked,rejected,fault,deadline,muting;
    wire [4:0] volume_index;
    wire [2:0] reference_release_index,fm_release_index;
    wire [7:0] occupied;
    wire gain_clipped;
    wire [2:0] lab_buttons={timbre_button_n,2'b11};

    playable_engine #(.N(8),.BUTTON_CYCLES(BUTTON_CYCLES),
        .LONG_CYCLES(LONG_CYCLES),.GATE_UNUSED(GATE_UNUSED)) engine(
        sys_clk,rst,render_ce,keys,changed,ghost,all_released,lab_buttons,1'b0,2'b00,
        final_valid,final_sample,timbre,sustain,release_mode,blocked,volume_index,
        reference_release_index,fm_release_index,rejected,fault,occupied,deadline,muting);

    noise_pt8211_tx #(.OSR(OSR)) tx(
        sys_clk,rst,dac_sample,dac_sample,tx_frame_ce,hp_bck,hp_ws,hp_din);
    noise_audio_output #(.OSR(OSR),.GAIN_SHIFT(GAIN_SHIFT)) output_stage(
        sys_clk,rst,tx_frame_ce,final_valid,final_sample,render_ce,dac_sample,gain_clipped);
    playable_led indicator(sys_clk,rst,timbre,sustain,release_mode,
        blocked||muting||deadline,rejected,status_led);
    assign pa_en=1'b0;
endmodule

module noise_lab_top_baseline(
    input wire sys_clk,timbre_button_n,input wire [3:0] matrix_col_n,
    output wire [3:0] matrix_row_n,output wire hp_bck,hp_ws,hp_din,pa_en,status_led);
    noise_lab_core #(.GATE_UNUSED(0),.GAIN_SHIFT(0),.OSR(1)) core(
        sys_clk,timbre_button_n,matrix_col_n,matrix_row_n,hp_bck,hp_ws,hp_din,pa_en,status_led);
endmodule

module noise_lab_top_activity_gate(
    input wire sys_clk,timbre_button_n,input wire [3:0] matrix_col_n,
    output wire [3:0] matrix_row_n,output wire hp_bck,hp_ws,hp_din,pa_en,status_led);
    noise_lab_core #(.GATE_UNUSED(1),.GAIN_SHIFT(0),.OSR(1)) core(
        sys_clk,timbre_button_n,matrix_col_n,matrix_row_n,hp_bck,hp_ws,hp_din,pa_en,status_led);
endmodule

module noise_lab_top_gain_x2(
    input wire sys_clk,timbre_button_n,input wire [3:0] matrix_col_n,
    output wire [3:0] matrix_row_n,output wire hp_bck,hp_ws,hp_din,pa_en,status_led);
    noise_lab_core #(.GATE_UNUSED(0),.GAIN_SHIFT(1),.OSR(1)) core(
        sys_clk,timbre_button_n,matrix_col_n,matrix_row_n,hp_bck,hp_ws,hp_din,pa_en,status_led);
endmodule

module noise_lab_top_gain_x4(
    input wire sys_clk,timbre_button_n,input wire [3:0] matrix_col_n,
    output wire [3:0] matrix_row_n,output wire hp_bck,hp_ws,hp_din,pa_en,status_led);
    noise_lab_core #(.GATE_UNUSED(0),.GAIN_SHIFT(2),.OSR(1)) core(
        sys_clk,timbre_button_n,matrix_col_n,matrix_row_n,hp_bck,hp_ws,hp_din,pa_en,status_led);
endmodule

module noise_lab_top_oversample_x2(
    input wire sys_clk,timbre_button_n,input wire [3:0] matrix_col_n,
    output wire [3:0] matrix_row_n,output wire hp_bck,hp_ws,hp_din,pa_en,status_led);
    noise_lab_core #(.GATE_UNUSED(0),.GAIN_SHIFT(0),.OSR(2)) core(
        sys_clk,timbre_button_n,matrix_col_n,matrix_row_n,hp_bck,hp_ws,hp_din,pa_en,status_led);
endmodule

module noise_lab_top_oversample_x4(
    input wire sys_clk,timbre_button_n,input wire [3:0] matrix_col_n,
    output wire [3:0] matrix_row_n,output wire hp_bck,hp_ws,hp_din,pa_en,status_led);
    noise_lab_core #(.GATE_UNUSED(0),.GAIN_SHIFT(0),.OSR(4)) core(
        sys_clk,timbre_button_n,matrix_col_n,matrix_row_n,hp_bck,hp_ws,hp_din,pa_en,status_led);
endmodule

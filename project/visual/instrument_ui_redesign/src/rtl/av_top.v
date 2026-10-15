// Independent C integration. Audio timing/reset/control match the validated
// audio_v2_top. Display loss of lock resets observation only, never audio.
module instrument_ui_top(
    input wire sys_clk,enc_a,enc_b,input wire [2:0] button_n,
    input wire [3:0] matrix_col_n,output wire [3:0] matrix_row_n,
    output wire hp_bck,hp_ws,hp_din,pa_en,
    output wire tmds_clk_n_0,tmds_clk_p_0,
    output wire [2:0] tmds_d_n_0,tmds_d_p_0
);
    reg [5:0] startup=0;
    wire audio_rst=!startup[5];
    always @(posedge sys_clk) if(audio_rst) startup<=startup+1'b1;
    wire [3:0] row_low;
    genvar r;
    generate for(r=0;r<4;r=r+1) begin: rows
        assign matrix_row_n[r]=row_low[r] ? 1'b0 : 1'bz;
    end endgenerate
    wire [15:0] keys;
    wire changed,input_frame,ghost,all_released,step_valid;
    wire signed [1:0] step;
    matrix_scanner #(.ROW_CYCLES(2500),.DEBOUNCE_FRAMES(8)) scanner(
        sys_clk,audio_rst,matrix_col_n,row_low,keys,changed,input_frame,ghost,all_released);
    ec11_input #(.SAMPLE_CYCLES(2500),.AB_SAMPLES(2)) encoder(
        .clk(sys_clk),.rst(audio_rst),.a(enc_a),.b(enc_b),.button_n(1'b1),.step_valid(step_valid),.step(step));
    wire sample_ce,final_valid,snapshot_valid;
    wire signed [15:0] left,right;
    wire [2367:0] snapshot;
    wire [255:0] extension;
    wire [15:0] snapshot_keys;
    wire timbre_button_n,requested_page;
    av_navigation navigation(sys_clk,audio_rst,button_n[2],timbre_button_n,requested_page);
    audio_v2_core #(.KEYS(16),.SPLIT(8),.DIATONIC(1),.N(32),.PLUCK_N(12)) core(
        .clk(sys_clk),.rst(audio_rst),.sample_ce(sample_ce),.keys(keys),.changed(changed),
        .ghost(ghost),.all_released(all_released),.button_n({timbre_button_n,button_n[1:0]}),.step_valid(step_valid),.step(step),
        .host_valid(1'b0),.host_addr(5'd0),.host_value(32'd0),
        .adc_valid(1'b0),.adc_ch0(12'd0),.adc_ch1(12'd0),.adc_ch2(12'd0),.adc_ch3(12'd0),.adc_ch4(12'd0),
        .final_valid(final_valid),.final_left(left),.final_right(right),
        .snapshot_valid(snapshot_valid),.snapshot_data(snapshot),.snapshot_extension(extension),.snapshot_keys(snapshot_keys));
    output_tx tx(sys_clk,audio_rst,left,right,sample_ce,hp_bck,hp_ws,hp_din);
    assign pa_en=1'b0;

    wire pixel_clk,serial_clk,locked,ui_rst,pixel_rst;
    Gowin_PLL pll(.clkin(sys_clk),.mdclk(sys_clk),.clkout0(pixel_clk),.clkout1(serial_clk),.lock(locked));
    wire observation_reset=audio_rst || !locked;
    audio_transport_reset ui_reset(sys_clk,observation_reset,ui_rst);
    audio_transport_reset video_reset(pixel_clk,observation_reset,pixel_rst);
    wire [10:0] x,y;
    wire de,hs,vs,frame_start;
    av_timing timing(pixel_clk,pixel_rst,x,y,de,hs,vs,frame_start);

    wire text_write,text_publish,text_ready,text_valid,text_changed;
    wire [10:0] text_write_address,text_read_address;
    wire [11:0] text_write_data,text_read_data;
    av_page_writer page(sys_clk,ui_rst,text_ready,snapshot_valid,snapshot,extension,snapshot_keys,
        text_write,text_write_address,text_write_data,text_publish);
    av_frame_ram #(.AW(11),.DW(12)) text_frames(
        sys_clk,ui_rst,pixel_clk,pixel_rst,text_write,text_write_address,text_write_data,text_publish,text_ready,
        frame_start,text_read_address,text_read_data,text_valid,text_changed);
    wire selected_page;
    av_page_select page_select(pixel_clk,pixel_rst,requested_page,frame_start,selected_page);
    wire scope_write,scope_publish,scope_ready,scope_valid,scope_changed;
    wire [8:0] scope_write_address;
    wire [39:0] scope_write_data,scope_read_data;
    wire [8:0] scope_read_address;
    av_wave_capture capture(sys_clk,ui_rst,scope_ready,final_valid,left,right,
        scope_write,scope_write_address,scope_write_data,scope_publish);
    av_frame_ram #(.AW(9),.DW(40)) scope_frames(
        sys_clk,ui_rst,pixel_clk,pixel_rst,scope_write,scope_write_address,scope_write_data,scope_publish,scope_ready,
        frame_start,scope_read_address,scope_read_data,scope_valid,scope_changed);
    wire [23:0] rgb;
    wire video_de,video_hs,video_vs;
    av_display renderer(pixel_clk,pixel_rst,selected_page,x,y,de,hs,vs,text_valid,scope_valid,text_changed,scope_changed,frame_start,
        text_read_address,text_read_data,scope_read_address,scope_read_data,rgb,video_de,video_hs,video_vs);
    av_dvi_tx transport(.sys_clk(sys_clk),.startup_reset(ui_rst),.pixel_clock(pixel_clk),.ddr_bit_clock(serial_clk),.rstn(!pixel_rst),
        .den(video_de),.hsync(video_hs),.vsync(video_vs),.pixel_data(rgb),
        .tmds_clk({tmds_clk_p_0,tmds_clk_n_0}),
        .tmds_d0({tmds_d_p_0[0],tmds_d_n_0[0]}),
        .tmds_d1({tmds_d_p_0[1],tmds_d_n_0[1]}),
        .tmds_d2({tmds_d_p_0[2],tmds_d_n_0[2]}));
endmodule

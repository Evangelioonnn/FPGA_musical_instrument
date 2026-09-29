// Synthesis-only wrapper. Hundreds of observation ports are not physical pins.
module interface_audit #(
    parameter PLUCK_N=12
)(
    input wire sys_clk,enc_a,enc_b,
    input wire [2:0] button_n,input wire [3:0] matrix_col_n,
    input wire [8:0] extra_keys,input wire extra_changed,
    output wire [3:0] matrix_row_n,
    output wire hp_bck,hp_ws,hp_din,pa_en,status_led,
    input wire host_valid,output wire host_ready,
    input wire [4:0] host_addr,input wire [31:0] host_value,
    input wire adc_valid,output wire adc_ready,
    input wire [11:0] adc_ch0,adc_ch1,adc_ch2,adc_ch3,adc_ch4,
    output wire ack_valid,ack_source,ack_accepted,ack_applied,
    output wire [4:0] ack_addr,output wire [31:0] ack_value,
    output wire final_valid,output wire signed [15:0] final_left,final_right,
    output wire [31:0] sample_index,output wire snapshot_valid,
    output wire [2367:0] snapshot_data,output wire [255:0] snapshot_extension,
    output wire [24:0] snapshot_keys,output wire [127:0] capabilities,
    output wire [2:0] selected_preset,output wire [4:0] control_mode,
    output wire sustain,sostenuto,blocked,rejected,deadline_missed,muting,clip_seen,
    output wire [31:0] occupied,held,gated
);
    reg [5:0] startup=0;
    wire rst=!startup[5];
    always @(posedge sys_clk) if(rst) startup<=startup+1'b1;
    wire [3:0] row_low;
    genvar r;
    generate for(r=0;r<4;r=r+1) begin: rows
        assign matrix_row_n[r]=row_low[r] ? 1'b0 : 1'bz;
    end endgenerate
    wire [15:0] matrix_keys;
    wire changed,frame,ghost,all_released;
    matrix_scanner scanner(sys_clk,rst,matrix_col_n,row_low,matrix_keys,
        changed,frame,ghost,all_released);
    wire step_valid;wire signed [1:0] step;
    ec11_input encoder(sys_clk,rst,enc_a,enc_b,1'b1,step_valid,step,,,);
    wire sample_ce;
    audio_v2_core #(.KEYS(25),.SPLIT(12),.DIATONIC(0),.PLUCK_N(PLUCK_N)) core(
        .clk(sys_clk),.rst(rst),.sample_ce(sample_ce),.keys({extra_keys,matrix_keys}),
        .changed(changed||extra_changed),.ghost(ghost),
        .all_released(all_released&&extra_keys==0),.button_n(button_n),
        .step_valid(step_valid),.step(step),
        .host_valid(host_valid),.host_ready(host_ready),.host_addr(host_addr),.host_value(host_value),
        .adc_valid(adc_valid),.adc_ready(adc_ready),.adc_ch0(adc_ch0),.adc_ch1(adc_ch1),
        .adc_ch2(adc_ch2),.adc_ch3(adc_ch3),.adc_ch4(adc_ch4),
        .ack_valid(ack_valid),.ack_source(ack_source),.ack_accepted(ack_accepted),
        .ack_applied(ack_applied),.ack_addr(ack_addr),.ack_value(ack_value),
        .final_valid(final_valid),.final_left(final_left),.final_right(final_right),
        .sample_index(sample_index),.snapshot_valid(snapshot_valid),.snapshot_data(snapshot_data),
        .snapshot_extension(snapshot_extension),.snapshot_keys(snapshot_keys),.capabilities(capabilities),
        .selected_preset(selected_preset),.control_mode(control_mode),.sustain(sustain),.sostenuto(sostenuto),
        .blocked(blocked),.rejected(rejected),.deadline_missed(deadline_missed),.occupied(occupied),
        .held(held),.gated(gated),.muting(muting),.clip_seen(clip_seen));
    output_tx tx(sys_clk,rst,final_left,final_right,sample_ce,hp_bck,hp_ws,hp_din);
    gallery_led indicator(sys_clk,rst,selected_preset,sustain,control_mode[2:0],
        blocked||muting||deadline_missed,rejected,status_led);
    assign pa_en=1'b0;
endmodule

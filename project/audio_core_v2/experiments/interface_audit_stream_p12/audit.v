// Audio-domain integration API; the board top only adapts physical inputs.
module interface_audit #(
    parameter KEYS=25,SPLIT=12,DIATONIC=0,N=32,PLUCK_N=12,
    parameter BUTTON_CYCLES=150000,LONG_CYCLES=50000000,
    parameter WITH_FX=1, SNAPSHOT_W=320+N*64
)(
    input wire clk,rst,sample_ce,
    input wire [KEYS-1:0] keys,input wire changed,ghost,all_released,
    input wire [2:0] button_n,input wire step_valid,input wire signed [1:0] step,
    input wire host_valid,output wire host_ready,
    input wire [4:0] host_addr,input wire [31:0] host_value,
    input wire adc_valid,output wire adc_ready,
    input wire [11:0] adc_ch0,adc_ch1,adc_ch2,adc_ch3,adc_ch4,
    output wire ack_valid,ack_source,ack_accepted,ack_applied,
    output wire [4:0] ack_addr,output wire [31:0] ack_value,
    output wire final_valid,output wire signed [15:0] final_left,final_right,
    output wire [31:0] sample_index,
    output wire snapshot_valid,output wire [SNAPSHOT_W-1:0] snapshot_data,
    output wire [2:0] selected_preset,output wire [4:0] control_mode,
    output wire sustain,sostenuto,blocked,rejected,deadline_missed,
    output wire [N-1:0] occupied,held,gated,
    output wire muting,output wire clip_seen,
    output wire [127:0] capabilities,
    output wire [255:0] snapshot_extension,
    output wire [KEYS-1:0] snapshot_keys
);
    assign capabilities[15:0]=16'd2;
    assign capabilities[31:16]=N;
    assign capabilities[47:32]=PLUCK_N;
    assign capabilities[63:48]=KEYS;
    assign capabilities[71:64]=8'h3d;
    assign capabilities[79:72]=8'd2;
    assign capabilities[87:80]=8'd0;
    assign capabilities[95:88]=8'd64;
    assign capabilities[111:96]=320+64*N;
    assign capabilities[127:112]=16'd320;
    audio_v2_core #(.KEYS(KEYS),.SPLIT(SPLIT),.DIATONIC(DIATONIC),.N(N),.PLUCK_N(PLUCK_N)) core(
        .clk(clk),
        .rst(rst),
        .sample_ce(sample_ce),
        .keys(keys),
        .changed(changed),
        .ghost(ghost),
        .all_released(all_released),
        .button_n(button_n),
        .step_valid(step_valid),
        .step(step),
        .host_valid(host_valid),
        .host_ready(host_ready),
        .host_addr(host_addr),
        .host_value(host_value),
        .adc_valid(adc_valid),
        .adc_ready(adc_ready),
        .adc_ch0(adc_ch0),
        .adc_ch1(adc_ch1),
        .adc_ch2(adc_ch2),
        .adc_ch3(adc_ch3),
        .adc_ch4(adc_ch4),
        .ack_valid(ack_valid),
        .ack_source(ack_source),
        .ack_accepted(ack_accepted),
        .ack_applied(ack_applied),
        .ack_addr(ack_addr),
        .ack_value(ack_value),
        .final_valid(final_valid),
        .final_left(final_left),
        .final_right(final_right),
        .sample_index(sample_index),
        .snapshot_valid(snapshot_valid),
        .snapshot_data(snapshot_data),
        .selected_preset(selected_preset),
        .control_mode(control_mode),
        .sustain(sustain),
        .sostenuto(sostenuto),
        .blocked(blocked),
        .rejected(rejected),
        .deadline_missed(deadline_missed),
        .occupied(occupied),
        .held(held),
        .gated(gated),
        .muting(muting),
        .clip_seen(clip_seen),
        .capabilities(capabilities),
        .snapshot_extension(snapshot_extension),
        .snapshot_keys(snapshot_keys));
endmodule

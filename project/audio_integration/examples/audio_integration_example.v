`include "../include/audio_api_v2.vh"
// Logical integration example, not a physical board top or pin allocation.
module audio_integration_example #(
    parameter KEYS=25, SPLIT=12, DIATONIC=0, PLUCK_N=12,
    parameter PCM_ADDR_W=6
)(
    input wire audio_clk, observer_clk, client_clk, arst,
    input wire [KEYS-1:0] keys,
    input wire changed, ghost, all_released,
    input wire [2:0] button_n,
    input wire step_valid,
    input wire signed [1:0] step,
    input wire adc_valid,
    output wire adc_ready,
    input wire [11:0] adc_ch0, adc_ch1, adc_ch2, adc_ch3, adc_ch4,
    input wire client_valid,
    output wire client_ready,
    input wire [4:0] client_addr,
    input wire [31:0] client_value,
    input wire [15:0] client_tag,
    output wire reply_valid,
    input wire reply_ready,
    output wire [4:0] reply_addr,
    output wire [31:0] reply_value,
    output wire [15:0] reply_tag,
    output wire reply_accepted, reply_applied,
    output wire state_valid,
    input wire state_ready,
    output wire [63:0] state_data,
    output wire [5:0] state_word_index,
    output wire state_first, state_last, state_session_start,
    output wire pcm_valid,
    input wire pcm_ready,
    output wire signed [15:0] pcm_left, pcm_right,
    output wire [31:0] pcm_index,
    output wire pcm_gap, pcm_session_start,
    output wire [31:0] state_drops, pcm_drops,
    output wire pcm_overflow, command_protocol_error,
    output wire final_valid,
    output wire signed [15:0] final_left, final_right,
    output wire [31:0] sample_index,
    output wire [2:0] selected_preset,
    output wire [4:0] control_mode,
    output wire sustain, sostenuto, blocked, rejected, deadline_missed,
    output wire muting, clip_seen,
    output wire [31:0] occupied, held, gated
);
    wire audio_rst;
    audio_transport_reset reset_audio(.clk(audio_clk),.arst(arst),.rst(audio_rst));
    reg [10:0] frame_count;
    wire sample_ce=frame_count==`AUDIO_FRAME_CLOCKS-1;
    always @(posedge audio_clk) begin
        if(audio_rst) frame_count<=0;
        else if(sample_ce) frame_count<=0;
        else frame_count<=frame_count+1'b1;
    end

    wire host_valid, host_ready, ack_valid, ack_source, ack_accepted, ack_applied;
    wire [4:0] host_addr, ack_addr;
    wire [31:0] host_value, ack_value;
    audio_command_bridge commands(
        .client_clk(client_clk),.audio_clk(audio_clk),.arst(arst),
        .client_valid(client_valid),.client_ready(client_ready),
        .client_addr(client_addr),.client_value(client_value),.client_tag(client_tag),
        .reply_valid(reply_valid),.reply_ready(reply_ready),.reply_addr(reply_addr),
        .reply_value(reply_value),.reply_tag(reply_tag),
        .reply_accepted(reply_accepted),.reply_applied(reply_applied),
        .host_valid(host_valid),.host_ready(host_ready),.host_addr(host_addr),.host_value(host_value),
        .ack_valid(ack_valid),.ack_source(ack_source),.ack_addr(ack_addr),.ack_value(ack_value),
        .ack_accepted(ack_accepted),.ack_applied(ack_applied),
        .audio_protocol_error(command_protocol_error));

    wire snapshot_valid;
    wire [`AUDIO_SNAPSHOT_BITS-1:0] snapshot_data;
    wire [`AUDIO_EXTENSION_BITS-1:0] snapshot_extension;
    wire [KEYS-1:0] snapshot_keys;
    wire [127:0] capabilities;
    audio_v2_core #(.KEYS(KEYS),.SPLIT(SPLIT),.DIATONIC(DIATONIC),.N(32),.PLUCK_N(PLUCK_N)) core(
        .clk(audio_clk),.rst(audio_rst),.sample_ce(sample_ce),.keys(keys),.changed(changed),
        .ghost(ghost),.all_released(all_released),.button_n(button_n),.step_valid(step_valid),.step(step),
        .host_valid(host_valid),.host_ready(host_ready),.host_addr(host_addr),.host_value(host_value),
        .adc_valid(adc_valid),.adc_ready(adc_ready),.adc_ch0(adc_ch0),.adc_ch1(adc_ch1),
        .adc_ch2(adc_ch2),.adc_ch3(adc_ch3),.adc_ch4(adc_ch4),
        .ack_valid(ack_valid),.ack_source(ack_source),.ack_accepted(ack_accepted),
        .ack_applied(ack_applied),.ack_addr(ack_addr),.ack_value(ack_value),
        .final_valid(final_valid),.final_left(final_left),.final_right(final_right),.sample_index(sample_index),
        .snapshot_valid(snapshot_valid),.snapshot_data(snapshot_data),
        .snapshot_extension(snapshot_extension),.snapshot_keys(snapshot_keys),.capabilities(capabilities),
        .selected_preset(selected_preset),.control_mode(control_mode),.sustain(sustain),.sostenuto(sostenuto),
        .blocked(blocked),.rejected(rejected),.deadline_missed(deadline_missed),
        .occupied(occupied),.held(held),.gated(gated),.muting(muting),.clip_seen(clip_seen));

    audio_snapshot_bridge #(.KEYS(KEYS)) states(
        .src_clk(audio_clk),.dst_clk(observer_clk),.arst(arst),
        .src_snapshot_valid(snapshot_valid),.src_snapshot_data(snapshot_data),
        .src_snapshot_extension(snapshot_extension),.src_snapshot_keys(snapshot_keys),
        .src_capabilities(capabilities),.src_busy(),.src_drop_count(state_drops),
        .dst_valid(state_valid),.dst_ready(state_ready),.dst_data(state_data),
        .dst_word_index(state_word_index),.dst_first(state_first),.dst_last(state_last),
        .dst_session_start(state_session_start));
    audio_pcm_bridge #(.ADDR_W(PCM_ADDR_W)) waveform(
        .src_clk(audio_clk),.dst_clk(observer_clk),.arst(arst),
        .src_valid(final_valid),.src_left(final_left),.src_right(final_right),.src_index(sample_index),
        .src_drop_count(pcm_drops),.src_overflow(pcm_overflow),
        .dst_valid(pcm_valid),.dst_ready(pcm_ready),.dst_left(pcm_left),.dst_right(pcm_right),
        .dst_index(pcm_index),.dst_gap(pcm_gap),.dst_session_start(pcm_session_start));
endmodule

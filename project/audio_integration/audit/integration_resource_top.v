// Resource/timing harness only. Extra logical keys are not board wiring.
module integration_resource_top(
    input wire sys_clk,observer_clk,arst,enc_a,enc_b,
    input wire [2:0] button_n,
    input wire [3:0] matrix_col_n,
    input wire [8:0] extra_keys,
    input wire extra_changed,
    output wire [3:0] matrix_row_n,
    output wire hp_bck,hp_ws,hp_din,pa_en,status_led,
    output wire audit_digest
);
    wire audio_rst,observer_rst;
    audio_transport_reset source_reset(sys_clk,arst,audio_rst);
    audio_transport_reset sink_reset(observer_clk,arst,observer_rst);
    wire [3:0] row_low;
    genvar r;
    generate for(r=0;r<4;r=r+1) begin: rows
        assign matrix_row_n[r]=row_low[r] ? 1'b0 : 1'bz;
    end endgenerate
    wire [15:0] matrix_keys;
    wire changed,frame,ghost,all_released;
    matrix_scanner scanner(sys_clk,audio_rst,matrix_col_n,row_low,matrix_keys,
        changed,frame,ghost,all_released);
    wire step_valid;
    wire signed [1:0] step;
    ec11_input encoder(sys_clk,audio_rst,enc_a,enc_b,1'b1,step_valid,step,,,);

    // Internal dynamic stimuli keep the parallel ADC and host interfaces in
    // the resource cone without turning mock buses into dozens of fake pins.
    reg [12:0] adc_divider;
    reg [11:0] adc_code;
    reg adc_valid;
    wire adc_ready;
    always @(posedge sys_clk) begin
        if(audio_rst) begin adc_divider<=0;adc_code<=0;adc_valid<=0;end
        else if(adc_valid) begin
            if(adc_ready) begin adc_valid<=0;adc_code<=adc_code+12'd37;end
        end else if(adc_divider==13'd4999) begin adc_divider<=0;adc_valid<=1;end
        else adc_divider<=adc_divider+1'b1;
    end
    wire [11:0] adc_ch0=adc_code;
    wire [11:0] adc_ch1={adc_code[5:0],adc_code[11:6]};
    wire [11:0] adc_ch2=adc_code^12'h555;
    wire [11:0] adc_ch3={adc_code[2:0],adc_code[11:3]};
    wire [11:0] adc_ch4=~adc_code;

    reg client_valid;
    wire client_ready;
    reg [4:0] client_addr;
    reg [31:0] client_value;
    reg [15:0] client_tag;
    reg [31:0] request_counter;
    always @(posedge observer_clk) begin
        if(observer_rst) begin
            client_valid<=0;client_addr<=0;client_value<=0;client_tag<=0;request_counter<=0;
        end else if(client_ready) begin
            client_valid<=1;
            client_addr<=request_counter[4:0];
            client_value<={request_counter[14:0],request_counter[16:0]};
            client_tag<=request_counter[15:0];
            request_counter<=request_counter+1'b1;
        end
    end

    wire final_valid;
    wire signed [15:0] final_left,final_right;
    wire [31:0] sample_index;
    wire [2:0] selected_preset;
    wire [4:0] control_mode;
    wire sustain,sostenuto,blocked,rejected,deadline_missed,muting,clip_seen;
    wire [4:0] reply_addr;
    wire [31:0] reply_value;
    wire [15:0] reply_tag;
    wire reply_valid,reply_accepted,reply_applied;
    wire state_valid,state_first,state_last,state_session_start;
    wire [63:0] state_data;
    wire [5:0] state_word_index;
    wire pcm_valid,pcm_gap,pcm_session_start,pcm_overflow,command_protocol_error;
    wire signed [15:0] pcm_left,pcm_right;
    wire [31:0] pcm_index,state_drops,pcm_drops;
    audio_integration_example integration(
        .audio_clk(sys_clk),.observer_clk(observer_clk),.client_clk(observer_clk),.arst(arst),
        .keys({extra_keys,matrix_keys}),.changed(changed||extra_changed),.ghost(ghost),
        .all_released(all_released&&extra_keys==0),.button_n(button_n),
        .step_valid(step_valid),.step(step),.adc_valid(adc_valid),.adc_ready(adc_ready),
        .adc_ch0(adc_ch0),.adc_ch1(adc_ch1),.adc_ch2(adc_ch2),.adc_ch3(adc_ch3),.adc_ch4(adc_ch4),
        .client_valid(client_valid),.client_ready(client_ready),.client_addr(client_addr),
        .client_value(client_value),.client_tag(client_tag),.reply_valid(reply_valid),.reply_ready(1'b1),
        .reply_addr(reply_addr),.reply_value(reply_value),.reply_tag(reply_tag),
        .reply_accepted(reply_accepted),.reply_applied(reply_applied),
        .state_valid(state_valid),.state_ready(1'b1),.state_data(state_data),
        .state_word_index(state_word_index),.state_first(state_first),.state_last(state_last),
        .state_session_start(state_session_start),.pcm_valid(pcm_valid),.pcm_ready(1'b1),
        .pcm_left(pcm_left),.pcm_right(pcm_right),.pcm_index(pcm_index),.pcm_gap(pcm_gap),
        .pcm_session_start(pcm_session_start),.state_drops(state_drops),.pcm_drops(pcm_drops),
        .pcm_overflow(pcm_overflow),.command_protocol_error(command_protocol_error),
        .final_valid(final_valid),.final_left(final_left),.final_right(final_right),
        .sample_index(sample_index),.selected_preset(selected_preset),.control_mode(control_mode),
        .sustain(sustain),.sostenuto(sostenuto),.blocked(blocked),.rejected(rejected),
        .deadline_missed(deadline_missed),.muting(muting),.clip_seen(clip_seen));
    wire sample_ce;
    output_tx tx(sys_clk,audio_rst,final_left,final_right,sample_ce,hp_bck,hp_ws,hp_din);
    gallery_led indicator(sys_clk,audio_rst,selected_preset,sustain,control_mode[2:0],
        blocked||muting||deadline_missed,rejected,status_led);
    assign pa_en=1'b0;
    reg [31:0] observer_digest;
    wire [31:0] state_fold=state_data[31:0]^state_data[63:32]^
        {23'd0,state_word_index,state_first,state_last,state_session_start};
    wire [31:0] pcm_fold=pcm_index^{pcm_right,pcm_left}^{30'd0,pcm_gap,pcm_session_start};
    wire [31:0] reply_fold=reply_value^{9'd0,reply_tag,reply_addr,reply_accepted,reply_applied};
    wire [31:0] audio_diagnostics=state_drops^pcm_drops^
        {26'd0,pcm_overflow,command_protocol_error,deadline_missed,clip_seen,muting,blocked};
    always @(posedge observer_clk) begin
        if(observer_rst) observer_digest<=0;
        else observer_digest<={observer_digest[30:0],observer_digest[31]}^
            ((state_valid) ? state_fold : 32'd0)^((pcm_valid) ? pcm_fold : 32'd0)^
            ((reply_valid) ? reply_fold : 32'd0)^audio_diagnostics;
    end
    assign audit_digest=^observer_digest;
endmodule

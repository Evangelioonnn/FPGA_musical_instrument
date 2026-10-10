// Resource harness. NOT a board image; observer clock and extra pins are audit placeholders.
module refinement_audit_top(input wire sys_clk,observer_clk,arst,enc_a,enc_b,adc_miso,client_seed,
 input wire [2:0] button_n,input wire [3:0] matrix_col_n,output wire [3:0] matrix_row_n,
 output wire hp_bck,hp_ws,hp_din,pa_en,status_led,adc_sclk,adc_mosi,adc_cs_n,audit_digest);
wire client_ready,reply_valid,reply_accepted,reply_applied;wire [4:0] reply_addr;
wire [31:0] reply_value;wire [15:0] reply_tag;reg cv;reg [31:0] rng;reg [15:0] tag;
wire state_valid,state_first,state_last,state_session_start;wire [63:0] state_data;wire [5:0] state_word_index;
wire pcm_valid,pcm_gap,pcm_session_start,pcm_overflow,protocol_error;wire signed [15:0] left,right;
wire [31:0] index,state_drops,pcm_drops,adc_skipped;
always @(posedge observer_clk or posedge arst) begin
 if(arst) begin cv<=0;rng<=32'h159a9e37;tag<=0;end
 else if(cv) begin if(client_ready) begin cv<=0;rng<={rng[30:0],rng[31]^rng[21]^rng[1]^rng[0]^client_seed};tag<=tag+1'b1;end end
 else cv<=1;
end
refinement_link link(.sys_clk(sys_clk),.observer_clk(observer_clk),.arst(arst),.enc_a(enc_a),.enc_b(enc_b),
 .button_n(button_n),.matrix_col_n(matrix_col_n),.matrix_row_n(matrix_row_n),.hp_bck(hp_bck),.hp_ws(hp_ws),.hp_din(hp_din),.pa_en(pa_en),.status_led(status_led),
 .adc_miso(adc_miso),.adc_sclk(adc_sclk),.adc_mosi(adc_mosi),.adc_cs_n(adc_cs_n),
 .client_valid(cv),.client_ready(client_ready),.client_addr(rng[4:0]),.client_value(rng),.client_tag(tag),
 .reply_valid(reply_valid),.reply_ready(1'b1),.reply_addr(reply_addr),.reply_value(reply_value),.reply_tag(reply_tag),.reply_accepted(reply_accepted),.reply_applied(reply_applied),
 .state_valid(state_valid),.state_ready(1'b1),.state_data(state_data),.state_word_index(state_word_index),.state_first(state_first),.state_last(state_last),.state_session_start(state_session_start),
 .pcm_valid(pcm_valid),.pcm_ready(1'b1),.pcm_left(left),.pcm_right(right),.pcm_index(index),.pcm_gap(pcm_gap),.pcm_session_start(pcm_session_start),
 .state_drops(state_drops),.pcm_drops(pcm_drops),.adc_skipped(adc_skipped),.pcm_overflow(pcm_overflow),.protocol_error(protocol_error));
reg [31:0] digest;
always @(posedge observer_clk or posedge arst) begin
 if(arst) digest<=0;
 else digest<={digest[30:0],digest[31]} ^ (state_valid ? state_data[31:0]^state_data[63:32]^{21'd0,state_word_index,state_first,state_last,state_session_start} : 32'd0)
    ^ (pcm_valid ? {left,right}^index^{30'd0,pcm_gap,pcm_session_start} : 32'd0)
    ^ (reply_valid ? reply_value^{9'd0,reply_tag,reply_addr,reply_accepted,reply_applied} : 32'd0)
    ^ state_drops^pcm_drops^adc_skipped^{30'd0,pcm_overflow,protocol_error};
end
assign audit_digest=^digest;
endmodule

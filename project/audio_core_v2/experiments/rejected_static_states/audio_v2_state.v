// Per-voice phase, glide and envelope. The original piano ADSR stays intact.
module audio_v2_state #(parameter PROFILE=6)(
    input wire clk,rst,sample_ce,note_on,note_off,
    input wire [31:0] phase_step,glide_start_step,input wire [2:0] glide_index,timbre,
    input wire [15:0] release_step,
    input wire [16:0] bend_factor,
    input wire [1:0] lead_attack_index,
    input wire envelope_override,custom_hold,
    input wire [15:0] adsr_attack,adsr_decay,adsr_sustain,
    output reg [31:0] phase,output wire [15:0] envelope,
    output reg [15:0] brightness,output wire [2:0] env_state,
    output reg [31:0] current_step, input wire [48:0] shared_bend_product,
    output wire [16:0] current_slew
);
    reg [31:0] target_step;
    reg signed [32:0] glide_delta;
    reg [13:0] glide_left;
    reg [31:0] bent_step;
    reg [16:0] bend_slewed;
    wire [48:0] bend_product=shared_bend_product;
    assign current_slew=bend_slewed;
    wire signed [32:0] step_difference=$signed({1'b0,phase_step})-$signed({1'b0,glide_start_step});
    always @(posedge clk) begin
        if(rst) begin
            phase<=0;current_step<=0;bent_step<=0;bend_slewed<=17'd65536;
            target_step<=0;glide_delta<=0;glide_left<=0;brightness<=65535;
        end else begin
            if(note_on) begin
                target_step<=phase_step;
                current_step<=glide_start_step;
                bent_step<=glide_start_step;
                bend_slewed<=17'd65536;
                glide_delta<=step_difference >>> (9+glide_index);
                glide_left<=glide_index!=0 && timbre==4 &&
                    phase_step!=glide_start_step ? (14'd1 << (9+glide_index)) : 0;
                brightness<=65535;
            end else if(sample_ce) begin
                bent_step<=bend_product[47:16];
                if(bend_slewed+17'd64<bend_factor) bend_slewed<=bend_slewed+17'd64;
                else if(bend_slewed>bend_factor+17'd64) bend_slewed<=bend_slewed-17'd64;
                else bend_slewed<=bend_factor;
                if(timbre==3 && brightness!=0)
                    brightness<=brightness-((brightness>>11)+1'b1);
                if(glide_left!=0) begin
                    glide_left<=glide_left-1'b1;
                    current_step<=glide_left==1 ? target_step : current_step+glide_delta[31:0];
                end
            end
            if(sample_ce) phase<=phase+(timbre!=3 && bend_slewed!=17'd65536 ? bent_step : current_step);
        end
    end
    wire sustained_shape=timbre==4 || (timbre==5 && custom_hold);
    wire [15:0] attack_step=envelope_override ? adsr_attack : sustained_shape ?
        (lead_attack_index==0 ? 16'd128 : lead_attack_index==1 ? 16'd256 :
         lead_attack_index==2 ? 16'd512 : 16'd1024) : 16'd68;
    wire [15:0] decay_step=envelope_override ? adsr_decay : sustained_shape ? 16'd2 : 16'd6;
    wire [15:0] sustain_level=envelope_override ? adsr_sustain : sustained_shape ? 16'd56000 : 16'd32768;
    wire [15:0] adsr_level;
    wire [2:0] adsr_state;
    adsr_envelope adsr(clk,rst,sample_ce,note_on,note_off,
        attack_step,decay_step,sustain_level,release_step,adsr_level,adsr_state);
    reg [23:0] natural_level;
    reg [2:0] natural_state;
    wire [24:0] attack_sum={1'b0,natural_level}+25'd200000;
    wire [24:0] natural_loss=timbre==3 ?
        ({9'd0,natural_level[23:14]}+1'b1) : ({9'd0,natural_level[23:13]}+1'b1);
    wire [24:0] release_loss={9'd0,release_step}<<9;
    always @(posedge clk) begin
        if(rst) begin natural_level<=0;natural_state<=0;end
        else if(note_on) natural_state<=1;
        else if(note_off && natural_state!=0) natural_state<=4;
        else if(sample_ce) case(natural_state)
            0:natural_level<=0;
            1:if(attack_sum>=25'd16777215) begin natural_level<=24'hffffff;natural_state<=2;end
              else natural_level<=attack_sum[23:0];
            2:if(natural_level<=natural_loss) begin natural_level<=0;natural_state<=0;end
              else natural_level<=natural_level-natural_loss;
            4:if(natural_level<=release_loss+natural_loss) begin natural_level<=0;natural_state<=0;end
              else natural_level<=natural_level-release_loss-natural_loss;
            default:begin natural_level<=0;natural_state<=0;end
        endcase
    end
    assign envelope=timbre==3 ? natural_level[23:8] : adsr_level;
    assign env_state=timbre==3 ? natural_state : adsr_state;
endmodule

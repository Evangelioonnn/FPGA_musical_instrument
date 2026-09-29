// Audio-domain integration API; the board top only adapts physical inputs.
module audio_v2_core #(
    parameter KEYS=16,SPLIT=8,DIATONIC=1,N=32,PLUCK_N=12,
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
    output reg [31:0] sample_index,
    output reg snapshot_valid,output reg [SNAPSHOT_W-1:0] snapshot_data,
    output wire [2:0] selected_preset,output wire [4:0] control_mode,
    output wire sustain,sostenuto,blocked,rejected,deadline_missed,
    output wire [N-1:0] occupied,held,gated,
    output reg muting,output reg clip_seen,
    output wire [127:0] capabilities,
    output reg [255:0] snapshot_extension,
    output reg [KEYS-1:0] snapshot_keys
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
    wire panel_valid,panel_ready,panel_overflow,local_ready;
    wire event_valid,event_ready,event_off,fault;
    reg fault_pending;
    wire [4:0] panel_addr;
    wire [31:0] panel_value,revision;
    wire [16:0] master_target,gain_left,gain_right;
    wire [6:0] left_base,right_base;
    wire [2:0] release_index,glide_index;
    wire signed [4:0] bend_index;
    wire [1:0] lead_attack_index;
    wire [15:0] adsr_a,adsr_d,adsr_s,adsr_r;
    wire override_env,custom_hold,effect_enable,panic;
    wire [6:0] vibrato_depth;
    wire [2:0] vibrato_speed;
    wire [7:0] effect_mix;
    wire [11:0] raw1,raw2,raw3,raw4;
    wire harmonic_valid,harmonic_ready;
    wire [11:0] harmonic1,harmonic2,harmonic3,harmonic4;
    wire [4:0] fader_acquired;
    wire [1:0] master_owner;
    wire adc_overrun,params_updated;
    audio_panel #(.BUTTON_CYCLES(BUTTON_CYCLES),.LONG_CYCLES(LONG_CYCLES)) panel(
        clk,rst,button_n,step_valid,step,selected_preset,master_target,left_base,right_base,
        sustain,sostenuto,release_index,glide_index,bend_index,lead_attack_index,
        vibrato_depth,vibrato_speed,effect_enable,effect_mix,adsr_a,adsr_d,adsr_s,adsr_r,
        override_env,custom_hold,raw1,raw2,raw3,raw4,
        panel_valid,panel_ready,panel_addr,panel_value,control_mode,panel_overflow);
    audio_parameter_service parameters(
        .clk(clk),.rst(rst),.sample_ce(sample_ce),
        .local_valid(panel_valid||fault_pending),.local_ready(local_ready),
        .local_addr(fault_pending ? 5'd30 : panel_addr),.local_value(fault_pending ? 32'd1 : panel_value),
        .host_valid(host_valid),.host_ready(host_ready),.host_addr(host_addr),.host_value(host_value),
        .adc_valid(adc_valid),.adc_ready(adc_ready),.adc_ch0(adc_ch0),.adc_ch1(adc_ch1),
        .adc_ch2(adc_ch2),.adc_ch3(adc_ch3),.adc_ch4(adc_ch4),
        .ack_valid(ack_valid),.ack_source(ack_source),.ack_addr(ack_addr),
        .ack_value(ack_value),.ack_accepted(ack_accepted),.ack_applied(ack_applied),
        .master_volume_target(master_target),.selected_preset(selected_preset),
        .zone_left(left_base),.zone_right(right_base),.ordinary_sustain(sustain),.selective_sustain(sostenuto),
        .release_index(release_index),.glide_index(glide_index),.bend_index(bend_index),
        .lead_attack_index(lead_attack_index),.adsr_attack(adsr_a),.adsr_decay(adsr_d),
        .adsr_sustain(adsr_s),.adsr_release(adsr_r),.envelope_override(override_env),.custom_hold(custom_hold),
        .vibrato_depth(vibrato_depth),.vibrato_speed(vibrato_speed),
        .effect_enable(effect_enable),.effect_mix(effect_mix),.panic_pulse(panic),
        .params_updated(params_updated),.parameter_revision(revision),
        .raw_ch1(raw1),.raw_ch2(raw2),.raw_ch3(raw3),.raw_ch4(raw4),
        .harmonic_snapshot_valid(harmonic_valid),.harmonic_snapshot_ready(harmonic_ready),
        .harmonic_snapshot_ch1(harmonic1),.harmonic_snapshot_ch2(harmonic2),
        .harmonic_snapshot_ch3(harmonic3),.harmonic_snapshot_ch4(harmonic4),
        .fader_acquired(fader_acquired),.master_owner(master_owner),.adc_overrun(adc_overrun));
    wire params_busy,harmonic_overrun;
    wire [15:0] unused_volume,unused_target;
    wire [8:0] coeff0,coeff1,coeff2,coeff3,tc0,tc1,tc2,tc3;
    wire harmonic_updated;
    assign harmonic_ready=!params_busy;
    custom_harmonic_params harmonic_parameters(clk,rst,sample_ce,harmonic_valid&&harmonic_ready,
        12'd4095,harmonic1,harmonic2,harmonic3,harmonic4,
        unused_volume,coeff0,coeff1,coeff2,coeff3,unused_target,tc0,tc1,tc2,tc3,
        harmonic_updated,params_busy,harmonic_overrun);
    reg [16:0] bend_factor;
    always @(posedge clk) begin
        if(rst) bend_factor<=65536;
        else case(bend_index)
            -8:bend_factor<=58386;-7:bend_factor<=59235;-6:bend_factor<=60097;
            -5:bend_factor<=60971;-4:bend_factor<=61858;-3:bend_factor<=62757;
            -2:bend_factor<=63670;-1:bend_factor<=64596;
            1:bend_factor<=66489;2:bend_factor<=67456;3:bend_factor<=68438;
            4:bend_factor<=69433;5:bend_factor<=70443;6:bend_factor<=71468;
            7:bend_factor<=72507;8:bend_factor<=73562;default:bend_factor<=65536;
        endcase
    end
    wire [16:0] vibrato_factor_value;
    wire [6:0] vibrato_depth_applied;
    vibrato_factor vibrato(.clk(clk),.rst(rst),.sample_ce(sample_ce),.enable(vibrato_depth!=0),
        .depth({1'b0,vibrato_depth}),.speed_index(vibrato_speed),.factor_q16(vibrato_factor_value),
        .depth_applied(vibrato_depth_applied));
    reg [16:0] lead_bend_factor;
    wire [33:0] pitch_product=bend_factor*vibrato_factor_value;
    always @(posedge clk) if(rst) lead_bend_factor<=65536;else lead_bend_factor<=pitch_product[32:16];
    reg [15:0] reference_release;
    always @* case(release_index)
        0:reference_release=96;1:reference_release=48;2:reference_release=24;
        3:reference_release=12;4:reference_release=6;5:reference_release=3;
        6:reference_release=2;default:reference_release=1;
    endcase
    wire [31:0] event_token,fault_count;
    wire [6:0] event_note;
    wire [2:0] event_preset;
    wire overflow_seen,token_exhausted;
    gallery_keys #(.KEYS(KEYS),.SPLIT(SPLIT),.DIATONIC(DIATONIC)) key_events(
        clk,rst,panic||muting,changed,ghost,all_released,keys,selected_preset,left_base,right_base,
        event_valid,event_ready,event_off,event_token,event_note,event_preset,
        fault,blocked,overflow_seen,token_exhausted,fault_count);
    wire bank_valid,bank_ready,accepted,bank_clip,bank_deadline;
    wire signed [15:0] bank_sample;
    wire [31:0] rejected_count,unmatched_count;
    wire [N-1:0] sost_latched;
    wire [N*7-1:0] voice_notes;
    wire [N*3-1:0] voice_presets;
    wire [N*32-1:0] voice_tokens;
    wire [N*16-1:0] voice_envelopes;
    reg clear_bank,prior_panel_overflow;
    wire panel_fault=panel_overflow&&!prior_panel_overflow;
    assign panel_ready=local_ready&&!fault_pending;
    assign event_ready=bank_ready&&!muting&&!panic&&!fault;
    audio_v2_bank #(.N(N),.PLUCK_N(PLUCK_N)) bank(
        clk,rst||clear_bank,sample_ce,event_valid&&!muting&&!panic&&!fault,
        bank_ready,event_off,event_token,event_note,event_preset,sustain,sostenuto,
        reference_release,glide_index,lead_attack_index,bend_factor,lead_bend_factor,
        override_env,custom_hold,adsr_a,adsr_d,adsr_s,adsr_r,
        coeff0,coeff1,coeff2,coeff3,accepted,rejected,rejected_count,unmatched_count,
        occupied,held,gated,sost_latched,voice_notes,voice_presets,voice_tokens,voice_envelopes,
        bank_valid,bank_sample,bank_clip,bank_deadline);
    wire room_valid,room_clip,room_ready,room_busy,room_overrun;
    wire signed [15:0] room_left,room_right;
    wire [8:0] wet_applied;
    generate if(WITH_FX) begin: room
        short_room_reverb effect(.clk(clk),.rst(rst||clear_bank),.in_valid(bank_valid),.in_sample(bank_sample),
            .fx_enable(effect_enable),.wet_q8({1'b0,effect_mix}),.out_valid(room_valid),
            .out_left(room_left),.out_right(room_right),.clip(room_clip),.ready(room_ready),
            .busy(room_busy),.overrun(room_overrun),.wet_applied(wet_applied));
    end else begin: no_room
        assign room_valid=bank_valid;assign room_left=bank_sample;assign room_right=bank_sample;
        assign room_clip=0;assign room_ready=1;assign room_busy=0;assign room_overrun=0;assign wet_applied=0;
    end endgenerate
    wire final_right_valid;
    knob_gain left_gain(clk,rst,room_valid,room_left,muting ? 17'd0 : master_target,
        final_valid,final_left,gain_left);
    knob_gain right_gain(clk,rst,room_valid,room_right,muting ? 17'd0 : master_target,
        final_right_valid,final_right,gain_right);
    assign deadline_missed=bank_deadline||room_overrun;
    reg [9:0] snapshot_div;
    reg [31:0] snapshot_sequence;
    reg [31:0] frame_number;
    reg gain_pending;
    reg reset_gap_pending;
    reg [15:0] stream_reset_count;
    reg [15:0] meter_peak;
    reg meter_clipped;
    wire [15:0] left_absolute=final_left<0 ? -final_left : final_left;
    wire [15:0] right_absolute=final_right<0 ? -final_right : final_right;
    wire [15:0] current_peak=left_absolute>right_absolute ? left_absolute : right_absolute;
    wire [15:0] next_peak=current_peak>meter_peak ? current_peak : meter_peak;
    integer k;
    always @(posedge clk) begin
        if(rst) begin
            muting<=0;clear_bank<=0;prior_panel_overflow<=0;clip_seen<=0;fault_pending<=0;
            sample_index<=0;snapshot_valid<=0;snapshot_data<=0;snapshot_div<=0;snapshot_sequence<=0;
            snapshot_extension<=0;snapshot_keys<=0;
            meter_peak<=0;meter_clipped<=0;
            frame_number<=0;gain_pending<=0;reset_gap_pending<=0;stream_reset_count<=0;
        end else begin
            prior_panel_overflow<=panel_overflow;
            if(fault||panel_fault) fault_pending<=1;
            else if(fault_pending&&local_ready) fault_pending<=0;
            clear_bank<=0;snapshot_valid<=0;
            if(sample_ce) frame_number<=frame_number+1'b1;
            gain_pending<=room_valid;
            if(gain_pending) sample_index<=frame_number-1'b1;
            if(clear_bank) begin reset_gap_pending<=1;stream_reset_count<=stream_reset_count+1'b1;end
            if(bank_clip||room_clip) clip_seen<=1;
            if(bank_clip||room_clip) meter_clipped<=1;
            if(panic||fault||panel_fault) muting<=1;
            else if(muting&&gain_left==0&&gain_right==0&&bank_valid) begin clear_bank<=1;muting<=0;end
            if(final_valid) begin
                reset_gap_pending<=0;
                snapshot_div<=snapshot_div+1'b1;
                meter_peak<=next_peak;
                if(snapshot_div==1023) begin
                    snapshot_valid<=1;snapshot_sequence<=snapshot_sequence+1'b1;
                    meter_peak<=0;meter_clipped<=0;
                    snapshot_data<=0;
                    snapshot_extension<=0;snapshot_keys<=keys;
                    snapshot_extension[31:0]<=sample_index;
                    snapshot_extension[47:32]<=adsr_a;snapshot_extension[63:48]<=adsr_d;
                    snapshot_extension[79:64]<=adsr_s;snapshot_extension[95:80]<=adsr_r;
                    snapshot_extension[107:96]<=raw1;snapshot_extension[119:108]<=raw2;
                    snapshot_extension[131:120]<=raw3;snapshot_extension[143:132]<=raw4;
                    snapshot_extension[145:144]<=lead_attack_index;
                    snapshot_extension[177:146]<=unmatched_count;
                    snapshot_extension[183:178]<=N;snapshot_extension[189:184]<=PLUCK_N;
                    snapshot_extension[197:190]<=8'd2;
                    snapshot_extension[205:198]<=8'd2;
                    snapshot_data[31:0]<=snapshot_sequence;
                    snapshot_data[63:32]<=revision;
                    snapshot_data[80:64]<=master_target;
                    snapshot_data[97:81]<=gain_left;
                    snapshot_data[100:98]<=selected_preset;
                    snapshot_data[101]<=sustain;snapshot_data[102]<=sostenuto;
                    snapshot_data[103]<=override_env;snapshot_data[104]<=custom_hold;
                    snapshot_data[105]<=effect_enable;snapshot_data[106]<=clip_seen;
                    snapshot_data[107]<=deadline_missed;snapshot_data[108]<=blocked;
                    snapshot_data[113:109]<=control_mode;
                    snapshot_data[120:114]<=left_base;snapshot_data[127:121]<=right_base;
                    snapshot_data[130:128]<=release_index;snapshot_data[133:131]<=glide_index;
                    snapshot_data[138:134]<=bend_index;snapshot_data[145:139]<=vibrato_depth;
                    snapshot_data[148:146]<=vibrato_speed;snapshot_data[156:149]<=effect_mix;
                    snapshot_data[165:157]<=wet_applied;snapshot_data[201:166]<={coeff3,coeff2,coeff1,coeff0};
                    snapshot_data[233:202]<=rejected_count;snapshot_data[265:234]<=fault_count;
                    snapshot_data[281:266]<=next_peak;snapshot_data[282]<=meter_clipped||bank_clip||room_clip;
                    snapshot_data[283]<=adc_overrun;snapshot_data[284]<=harmonic_overrun;
                    snapshot_data[285]<=panel_overflow;snapshot_data[290:286]<=fader_acquired;
                    snapshot_data[291]<=room_ready;snapshot_data[292]<=muting;
                    snapshot_data[294]<=reset_gap_pending;snapshot_data[310:295]<=stream_reset_count;
                    snapshot_data[312:311]<=master_owner;snapshot_data[319:313]<=vibrato_depth_applied;
                    for(k=0;k<N;k=k+1) begin
                        snapshot_data[320+k*64+:32]<=voice_tokens[k*32+:32];
                        snapshot_data[352+k*64+:7]<=voice_notes[k*7+:7];
                        snapshot_data[359+k*64+:3]<=voice_presets[k*3+:3];
                        snapshot_data[362+k*64]<=occupied[k];snapshot_data[363+k*64]<=held[k];
                        snapshot_data[364+k*64]<=gated[k];snapshot_data[365+k*64]<=sost_latched[k];
                        snapshot_data[366+k*64+:16]<=voice_envelopes[k*16+:16];
                    end
                end
            end
        end
    end
endmodule

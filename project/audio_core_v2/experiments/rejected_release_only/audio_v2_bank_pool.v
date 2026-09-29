// Shared state datapath, independent strike storage and a bounded pluck pool.
module audio_v2_bank #(parameter N=32,PLUCK_N=8,SW=(N>1?$clog2(N):1))(
    input wire clk,rst,sample_ce,event_valid,output wire event_ready,
    input wire event_off,input wire [31:0] event_token,input wire [6:0] event_note,
    input wire [2:0] event_timbre,input wire pedal,sostenuto,
    input wire [15:0] reference_release,input wire [2:0] glide_index,
    input wire [1:0] lead_attack_index,input wire [16:0] bend_factor,lead_bend_factor,
    input wire envelope_override,custom_hold,
    input wire [15:0] adsr_attack,adsr_decay,adsr_sustain,adsr_release,
    input wire [8:0] coeff0,coeff1,coeff2,coeff3,
    output reg accepted,rejected,output reg [31:0] rejected_count,unmatched_off_count,
    output wire [N-1:0] occupied,held,gated,sost_latched,
    output wire [N*7-1:0] notes_snapshot,output wire [N*3-1:0] presets_snapshot,
    output wire [N*32-1:0] tokens_snapshot,output wire [N*16-1:0] envelopes_snapshot,
    output reg out_valid,output reg signed [15:0] out_sample,
    output reg clipped,deadline_missed
);
    localparam IDLE=0,E_SCAN=1,E_COMMIT=2,R_READ=3,R_MULT=4,R_WRITE=5,
               T_START=6,T_WAIT=7,P_MIX=8,FINISH=9,E_READ=10;
    reg [3:0] state;
    reg [SW-1:0] index,scan_index,free_slot,match_slot;
    reg [N-1:0] hbusy,hheld,hgated,hsost,override_mask;
    reg [PLUCK_N-1:0] pstart,pstop;
    wire [PLUCK_N-1:0] pbusy,pheld,pgated,psost;
    wire [PLUCK_N*20-1:0] psamples;
    wire [PLUCK_N-1:0] release_request;
    wire [PLUCK_N*16-1:0] release_operands;
    wire [PLUCK_N*17-1:0] release_factors;
    reg [PLUCK_N-1:0] release_grants;
    reg [2:0] release_state;
    reg [SW-1:0] release_index;
    reg signed [15:0] release_operand;
    reg [16:0] release_factor;
    reg signed [33:0] release_product;
    wire signed [33:0] release_next=release_operand*$signed({1'b0,release_factor});
    always @(posedge clk) begin
        if(rst) begin
            release_state<=0;release_index<=0;release_grants<=0;
            release_operand<=0;release_factor<=0;release_product<=0;
        end else begin
            release_grants<=0;
            case(release_state)
                0:if(release_request[release_index]) begin
                    release_operand<=release_operands[release_index*16+:16];
                    release_factor<=release_factors[release_index*17+:17];release_state<=1;
                end else release_index<=release_index==PLUCK_N-1 ? 0 : release_index+1'b1;
                1:begin release_product<=release_next;release_state<=2;end
                2:begin release_grants[release_index]<=1;release_state<=3;end
                3:begin release_index<=release_index==PLUCK_N-1 ? 0 : release_index+1'b1;release_state<=0;end
                default:release_state<=0;
            endcase
        end
    end
    reg [SW-1:0] powner[0:PLUCK_N-1];
    reg [31:0] tokens[0:N-1],phase_mem[0:N-1];
    reg [23:0] level_mem[0:N-1];
    reg [15:0] bright_mem[0:N-1];
    reg [2:0] presets[0:N-1];
    // One synchronous read and one synchronous write. Invalid slots are masked;
    // each strike writes a complete initial record, so RAM needs no bulk reset.
    reg [228:0] state_mem[0:N-1];
    reg [228:0] work_data,match_data;
    reg mem_write;
    reg [SW-1:0] mem_index;
    reg [228:0] mem_data;
    wire [SW-1:0] read_index=state==E_READ ? scan_index : index;
    always @(posedge clk) begin
        work_data<=state_mem[read_index];
        if(mem_write && !rst && !sample_ce) state_mem[mem_index]<=mem_data;
    end
    reg [6:0] notes[0:N-1];
    reg [N-1:0] pmapped,pmapped_held,pmapped_gated,pmapped_sost;
    integer map_i,reset_i;
    always @* begin
        pmapped=0;pmapped_held=0;pmapped_gated=0;pmapped_sost=0;
        for(map_i=0;map_i<PLUCK_N;map_i=map_i+1)
            if(pbusy[map_i] || pstart[map_i]) begin
                pmapped[powner[map_i]]=1;pmapped_held[powner[map_i]]=pheld[map_i];
                pmapped_gated[powner[map_i]]=pgated[map_i];pmapped_sost[powner[map_i]]=psost[map_i];
            end
    end
    assign occupied=hbusy|pmapped;
    assign held=hheld|pmapped_held;
    assign gated=hgated|pmapped_gated;
    assign sost_latched=hsost|pmapped_sost;
    wire [N*32-1:0] phases;
    wire [N*16-1:0] envs,brightness;
    genvar g;
    generate for(g=0;g<N;g=g+1) begin: observation
        assign tokens_snapshot[g*32+:32]=tokens[g];
        assign notes_snapshot[g*7+:7]=notes[g];
        assign presets_snapshot[g*3+:3]=presets[g];
        assign phases[g*32+:32]=phase_mem[g];
        assign envs[g*16+:16]=hbusy[g] ? (presets[g]==3 ? level_mem[g][23:8] : level_mem[g][15:0]) : 16'd0;
        assign brightness[g*16+:16]=bright_mem[g];
        assign envelopes_snapshot[g*16+:16]=envs[g*16+:16];
    end endgenerate
    reg command_pending,command_off,free_found,match_found,lead_found;
    reg [31:0] command_token,latest_token,latest_step;
    reg [6:0] command_note;
    reg [2:0] command_timbre;
    reg pluck_free_found;
    integer pluck_free_slot,free_i;
    always @* begin
        pluck_free_found=0;pluck_free_slot=0;
        for(free_i=0;free_i<PLUCK_N;free_i=free_i+1)
            if(!pbusy[free_i] && !pstart[free_i] && !pluck_free_found) begin
                pluck_free_found=1;pluck_free_slot=free_i;
            end
    end
    assign event_ready=!rst && !sample_ce && state==IDLE && !command_pending && !(|pstart);
    wire [31:0] lookup_step;
    wire [9:0] lookup_length;
    wire [15:0] lookup_fraction;
    wire [24:0] lookup_reciprocal;
    note_table note_lookup(command_note,lookup_step);
    pluck_note_table pluck_lookup(command_note,lookup_length,lookup_fraction,lookup_reciprocal);
    reg [6:0] new_note;
    reg [31:0] new_step;
    reg [9:0] new_length;
    reg [15:0] new_fraction;
    reg [24:0] new_reciprocal;
    reg sostenuto_prev;
    reg [N-1:0] sost_eligible;
    integer eligible_i;
    always @* begin
        sost_eligible=0;
        for(eligible_i=0;eligible_i<N;eligible_i=eligible_i+1)
            sost_eligible[eligible_i]=presets[eligible_i]==0 || presets[eligible_i]==4 || presets[eligible_i]==5;
    end
    reg [31:0] phase_w;
    wire [31:0] step_w,target_w,delta_w,bent_w;
    wire [16:0] slew_w;
    wire [13:0] glide_w;
    reg [23:0] level_w;
    reg [15:0] bright_w;
    wire [15:0] attack_w,decay_w,sustain_w,release_w;
    wire [2:0] env_w;
    reg [2:0] preset_w;
    wire [1:0] drain_w;
    wire override_w;
    assign {override_w,drain_w,env_w,release_w,sustain_w,decay_w,attack_w,
            glide_w,slew_w,bent_w,delta_w,target_w,step_w}=work_data;
    reg [48:0] bend_product;
    wire [48:0] bend_next=step_w*slew_w;
    wire [16:0] bend_target=preset_w==4 ? lead_bend_factor : bend_factor;
    wire [31:0] phase_next=phase_w+(preset_w!=3 && slew_w!=65536 ? bent_w : step_w);
    wire [16:0] attack_sum={1'b0,level_w[15:0]}+{1'b0,attack_w};
    wire [16:0] decay_floor={1'b0,sustain_w}+{1'b0,decay_w};
    wire [24:0] natural_attack={1'b0,level_w}+25'd200000;
    wire [24:0] natural_loss={15'd0,level_w[23:14]}+1'b1;
    wire [24:0] natural_release={9'd0,release_w}<<9;
    wire [25:0] natural_total_loss={1'b0,natural_loss}+{1'b0,natural_release};
    reg [23:0] next_level;
    reg [2:0] next_env;
    always @* begin
        next_level=level_w;next_env=env_w;
        if(preset_w==3) case(env_w)
            0:next_level=0;
            1:if(natural_attack>=25'd16777215) begin next_level=24'hffffff;next_env=2;end
              else next_level=natural_attack[23:0];
            2:if(level_w<=natural_loss) begin next_level=0;next_env=0;end
              else next_level=level_w-natural_loss;
            4:if({2'd0,level_w}<=natural_total_loss) begin next_level=0;next_env=0;end
              else next_level=level_w-natural_loss-natural_release;
            default:begin next_level=0;next_env=0;end
        endcase else case(env_w)
            0:next_level=0;
            1:if(attack_sum>=65535) begin next_level=65535;next_env=2;end
              else next_level={8'd0,attack_sum[15:0]};
            2:if({1'b0,level_w[15:0]}<=decay_floor) begin next_level={8'd0,sustain_w};next_env=3;end
              else next_level={8'd0,level_w[15:0]-decay_w};
            3:next_level={8'd0,sustain_w};
            4:if(level_w[15:0]<=release_w) begin next_level=0;next_env=0;end
              else next_level={8'd0,level_w[15:0]-release_w};
            default:begin next_level=0;next_env=0;end
        endcase
    end
    reg tone_ce;
    wire signed [19:0] tone_sample;
    wire [N-1:0] tone_valid;
    wire tone_deadline;
    custom_gallery_shared_tone #(.PROFILE(6),.N(N)) tones(clk,rst,tone_ce,
        phases,envs,brightness,notes_snapshot,presets_snapshot,coeff0,coeff1,coeff2,coeff3,
        tone_sample,tone_valid,tone_deadline);
    generate for(g=0;g<PLUCK_N;g=g+1) begin: plucks
        audio_v2_pool_slot #(.PLUCK_ONLY(1)) slot(.clk(clk),.rst(rst),.sample_ce(sample_ce),
            .start(pstart[g]),.stop(pstop[g]),.note(new_note),.timbre(3'd2),
            .new_step(new_step),.new_length(new_length),.new_fraction(new_fraction),.new_reciprocal(new_reciprocal),
            .glide_start_step(32'd0),.glide_index(3'd0),.harmonic_sample(20'sd0),.harmonic_valid(1'b0),
            .pedal(pedal),.sostenuto(sostenuto),.reference_release(reference_release),
            .bend_factor(bend_factor),.lead_bend_factor(lead_bend_factor),.lead_attack_index(lead_attack_index),
            .envelope_override(envelope_override),.custom_hold(custom_hold),
            .adsr_attack(adsr_attack),.adsr_decay(adsr_decay),.adsr_sustain(adsr_sustain),.adsr_release(adsr_release),
            .busy(pbusy[g]),.held(pheld[g]),.gated(pgated[g]),.sost_latched(psost[g]),
            .sample(psamples[g*20+:20]),.proc_ce(1'b0),.shared_bend_product(49'd0),
            .release_request(release_request[g]),.release_operand(release_operands[g*16+:16]),
            .release_factor(release_factors[g*17+:17]),.release_grant(release_grants[g]),
            .shared_release_product(release_product));
    end endgenerate
    // Retained only by equivalence benches; physical top does not consume this.
    reg [N*20-1:0] hsamples;
    reg signed [31:0] sum;
    wire signed [19:0] pluck_term=psamples[index*20+:20];
    wire signed [31:0] pluck_extended={{12{pluck_term[19]}},pluck_term};
    wire signed [31:0] rounded_sum=sum<0 ? -(((-sum)+32)>>>6) : (sum+32)>>>6;
    wire [31:0] source_step=command_timbre==4 && glide_index!=0 && lead_found ? latest_step : lookup_step;
    wire signed [32:0] start_difference=$signed({1'b0,lookup_step})-$signed({1'b0,source_step});
    wire sustained_shape=command_timbre==4 || (command_timbre==5 && custom_hold);
    wire legal_on=free_found && !match_found && command_token!=0 && command_note>=36 && command_note<=84 &&
        (command_timbre==0 || command_timbre==2 || command_timbre==3 || command_timbre==4 || command_timbre==5) &&
        (command_timbre!=2 || pluck_free_found);
    wire [15:0] start_attack=envelope_override ? adsr_attack : sustained_shape ?
        (lead_attack_index==0 ? 16'd128 : lead_attack_index==1 ? 16'd256 : lead_attack_index==2 ? 16'd512 : 16'd1024) : 16'd68;
    wire [15:0] start_decay=envelope_override ? adsr_decay : sustained_shape ? 16'd2 : 16'd6;
    wire [15:0] start_sustain=envelope_override ? adsr_sustain : sustained_shape ? 16'd56000 : 16'd32768;
    wire [31:0] start_delta=start_difference >>> (9+glide_index);
    wire [13:0] start_glide=command_timbre==4 && glide_index!=0 && source_step!=lookup_step ? (14'd1 << (9+glide_index)) : 0;
    always @* begin
        mem_write=0;mem_index=index;mem_data=work_data;
        if(state==E_COMMIT) begin
            if(!command_off && legal_on && command_timbre!=2) begin
                mem_write=1;mem_index=free_slot;
                mem_data={envelope_override,2'd0,3'd1,16'd3,start_sustain,start_decay,start_attack,
                    start_glide,17'd65536,source_step,start_delta,lookup_step,source_step};
            end else if(command_off && match_found && command_token!=0 && presets[match_slot]!=2 &&
                (presets[match_slot]==3 || !(pedal || (sostenuto && hsost[match_slot])))) begin
                mem_write=1;mem_index=match_slot;mem_data=match_data;
                mem_data[225:223]=match_data[225:223]!=0 ? 3'd4 : 3'd0;
                mem_data[222:207]=match_data[228] ? adsr_release :
                    presets[match_slot]==4 ? (reference_release<<3) : reference_release;
            end
        end else if(state==R_WRITE && hbusy[index]) begin
            mem_write=1;
            mem_data[127:96]=bend_product[47:16];
            mem_data[144:128]=slew_w+17'd64<bend_target ? slew_w+17'd64 :
                slew_w>bend_target+17'd64 ? slew_w-17'd64 : bend_target;
            if(glide_w!=0) begin
                mem_data[158:145]=glide_w-1'b1;mem_data[31:0]=glide_w==1 ? target_w : step_w+delta_w;
            end
            if(hgated[index] && !hheld[index] && (preset_w==3 || !(pedal || (sostenuto && hsost[index])))) begin
                mem_data[225:223]=env_w!=0 ? 3'd4 : 3'd0;
                mem_data[222:207]=override_w ? adsr_release : preset_w==4 ? (reference_release<<3) : reference_release;
            end else mem_data[225:223]=next_env;
            if(!hgated[index] && next_env==0) mem_data[227:226]=drain_w+1'b1;
        end
    end
    always @(posedge clk) begin
        if(rst) begin
            state<=IDLE;index<=0;scan_index<=0;free_slot<=0;match_slot<=0;
            hbusy<=0;hheld<=0;hgated<=0;hsost<=0;override_mask<=0;
            pstart<=0;pstop<=0;sostenuto_prev<=0;command_pending<=0;
            command_off<=0;command_token<=0;command_note<=60;command_timbre<=0;
            free_found<=0;match_found<=0;lead_found<=0;latest_token<=0;latest_step<=0;
            new_note<=60;new_step<=0;new_length<=0;new_fraction<=0;new_reciprocal<=0;
            phase_w<=0;level_w<=0;bright_w<=65535;preset_w<=0;bend_product<=0;match_data<=0;
            tone_ce<=0;hsamples<=0;sum<=0;accepted<=0;rejected<=0;
            rejected_count<=0;unmatched_off_count<=0;
            out_valid<=0;out_sample<=0;clipped<=0;deadline_missed<=0;
            for(reset_i=0;reset_i<N;reset_i=reset_i+1) begin
                tokens[reset_i]<=0;notes[reset_i]<=60;presets[reset_i]<=0;
                phase_mem[reset_i]<=0;level_mem[reset_i]<=0;bright_mem[reset_i]<=65535;
            end
            for(reset_i=0;reset_i<PLUCK_N;reset_i=reset_i+1) powner[reset_i]<=0;
        end else begin
            pstart<=0;pstop<=0;tone_ce<=0;accepted<=0;rejected<=0;out_valid<=0;clipped<=0;
            sostenuto_prev<=sostenuto;
            if(!sostenuto) hsost<=0;
            else if(!sostenuto_prev) hsost<=hheld&hbusy&sost_eligible;
            else hsost<=hsost&hbusy;
            if(tone_deadline) deadline_missed<=1;
            if(sample_ce) begin
                if(state>=R_READ && state<=FINISH) deadline_missed<=1;
                if(command_pending) begin scan_index<=0;free_found<=0;match_found<=0;lead_found<=0;latest_token<=0;end
                state<=R_READ;index<=0;sum<=0;
            end else case(state)
                IDLE:if(event_valid && event_ready) begin
                    command_pending<=1;command_off<=event_off;command_token<=event_token;
                    command_note<=event_note;command_timbre<=event_timbre;
                    scan_index<=0;free_found<=0;match_found<=0;lead_found<=0;latest_token<=0;state<=E_READ;
                end
                E_READ:state<=E_SCAN;
                E_SCAN:begin
                    if(!occupied[scan_index] && !free_found) begin free_found<=1;free_slot<=scan_index;end
                    if(occupied[scan_index] && tokens[scan_index]==command_token) begin match_found<=1;match_slot<=scan_index;match_data<=work_data;end
                    if(hheld[scan_index] && presets[scan_index]==4 && (!lead_found || tokens[scan_index]>latest_token)) begin
                        lead_found<=1;latest_token<=tokens[scan_index];latest_step<=step_w;
                    end
                    if(scan_index==N-1) state<=E_COMMIT;else begin scan_index<=scan_index+1'b1;state<=E_READ;end
                end
                E_COMMIT:begin
                    command_pending<=0;state<=IDLE;
                    if(command_off) begin
                        if(match_found && command_token!=0) begin
                            if(presets[match_slot]==2) begin
                                for(reset_i=0;reset_i<PLUCK_N;reset_i=reset_i+1)
                                    if(pbusy[reset_i] && powner[reset_i]==match_slot) pstop[reset_i]<=1;
                            end else begin
                                hheld[match_slot]<=0;
                                if(presets[match_slot]==3 || !(pedal || (sostenuto && hsost[match_slot]))) begin
                                    hgated[match_slot]<=0;
                                end
                            end
                            accepted<=1;
                        end else unmatched_off_count<=unmatched_off_count+1'b1;
                    end else if(legal_on) begin
                        tokens[free_slot]<=command_token;notes[free_slot]<=command_note;presets[free_slot]<=command_timbre;
                        if(command_timbre==2) begin
                            pstart[pluck_free_slot]<=1;powner[pluck_free_slot]<=free_slot;
                            new_note<=command_note;new_step<=lookup_step;new_length<=lookup_length;
                            new_fraction<=lookup_fraction;new_reciprocal<=lookup_reciprocal;
                        end else begin
                            hbusy[free_slot]<=1;hheld[free_slot]<=1;hgated[free_slot]<=1;
                            phase_mem[free_slot]<=0;level_mem[free_slot]<=0;bright_mem[free_slot]<=65535;
                            override_mask[free_slot]<=envelope_override;
                        end
                        accepted<=1;
                    end else begin rejected<=1;rejected_count<=rejected_count+1'b1;end
                end
                R_READ:begin
                    phase_w<=phase_mem[index];level_w<=level_mem[index];bright_w<=bright_mem[index];preset_w<=presets[index];
                    state<=R_MULT;
                end
                R_MULT:begin bend_product<=bend_next;state<=R_WRITE;end
                R_WRITE:begin
                    if(hbusy[index]) begin
                        phase_mem[index]<=phase_next;
                        if(preset_w==3 && bright_w!=0) bright_mem[index]<=bright_w-((bright_w>>11)+1'b1);
                        if(hgated[index] && !hheld[index] && (preset_w==3 || !(pedal || (sostenuto && hsost[index])))) begin
                            hgated[index]<=0;
                        end else level_mem[index]<=next_level;
                        if(!hgated[index] && next_env==0) begin
                            if(drain_w==2) begin hbusy[index]<=0;hheld[index]<=0;phase_mem[index]<=0;level_mem[index]<=0;end
                        end
                    end
                    if(index==N-1) state<=T_START;else begin index<=index+1'b1;state<=R_READ;end
                end
                T_START:begin tone_ce<=1;state<=T_WAIT;end
                T_WAIT:if(|tone_valid) begin
                    sum<=sum+{{12{tone_sample[19]}},tone_sample};
                    for(reset_i=0;reset_i<N;reset_i=reset_i+1)
                        if(tone_valid[reset_i]) hsamples[reset_i*20+:20]<=tone_sample;
                    if(tone_valid[N-1]) begin index<=0;state<=P_MIX;end
                end
                P_MIX:begin
                    if(pbusy[index]) sum<=sum+(pluck_extended<<<2);
                    if(index==PLUCK_N-1) state<=FINISH;else index<=index+1'b1;
                end
                FINISH:begin
                    if(rounded_sum>32767) begin out_sample<=32767;clipped<=1;end
                    else if(rounded_sum< -32768) begin out_sample<=-32768;clipped<=1;end
                    else out_sample<=rounded_sum[15:0];
                    out_valid<=1;state<=command_pending ? E_READ : IDLE;
                end
                default:state<=IDLE;
            endcase
        end
    end
endmodule

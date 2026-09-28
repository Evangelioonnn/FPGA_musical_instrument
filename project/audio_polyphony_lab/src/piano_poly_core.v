// Independent piano voices serviced by one state/render datapath.
// Accepted harmonic-piano weights and symmetric Q4 rounding are unchanged.
module piano_poly_core #(
    parameter integer N=16,
    parameter integer OUTPUT_SHIFT=1,
    parameter integer IW=(N>1?$clog2(N):1)
)(
    input wire clk,rst,sample_ce,
    input wire event_valid,output wire event_ready,
    input wire event_off,input wire [31:0] event_token,
    input wire [6:0] event_note,
    input wire [15:0] attack_step,decay_step,sustain_level,release_step,
    input wire sustain,sostenuto,
    output reg accepted,rejected,
    output reg [31:0] rejected_count,unmatched_off_count,
    output reg [N-1:0] occupied,held,gated,
    output reg out_valid,output reg signed [15:0] out_sample,
    output reg signed [31:0] mixed_q4,
    output reg clipped,deadline_missed
);
    localparam IDLE=0,E_SCAN=1,E_COMMIT=2,R_READ=3,R_UPDATE=4,
        R_ADDR=5,R_WAIT=6,R_GET=7,R_SHAPE=8,R_MULT=9,
        R_ACCUM=10,R_FINISH=11;
    localparam ENV_IDLE=0,ATTACK=1,DECAY=2,SUSTAIN=3,RELEASE=4;
    reg [3:0] state;
    reg [31:0] phases[0:N-1],steps[0:N-1],tokens[0:N-1];
    reg [15:0] levels[0:N-1],attacks[0:N-1],decays[0:N-1];
    reg [15:0] sustains[0:N-1],releases[0:N-1];
    reg [2:0] env_states[0:N-1];
    reg [6:0] notes[0:N-1];
    reg [N-1:0] sost_mask;
    reg sost_previous;
    reg event_pending,command_off;
    reg [31:0] command_token;
    reg [6:0] command_note;
    reg [IW-1:0] scan_index,free_index,match_index,voice_index;
    reg free_found,match_found;
    wire [31:0] command_step;
    note_table note_lookup(command_note,command_step);
    reg frame_sustain,frame_sostenuto;
    reg [N-1:0] frame_sost_mask;
    reg [15:0] frame_release;
    reg [31:0] phase_work,step_work;
    reg [15:0] level_work,attack_work,decay_work,sustain_work,release_work;
    reg [2:0] env_work;
    reg held_work,sost_work;
    reg [31:0] next_phase;
    reg [15:0] next_level,next_release;
    reg [2:0] next_env;
    wire [15:0] a_step=attack_work==0 ? 16'd1 : attack_work;
    wire [15:0] d_step=decay_work==0 ? 16'd1 : decay_work;
    wire [15:0] r_step=release_work==0 ? 16'd1 : release_work;
    wire [16:0] attack_sum={1'b0,level_work}+{1'b0,a_step};
    wire [16:0] decay_floor={1'b0,sustain_work}+{1'b0,d_step};
    always @* begin
        next_phase=phase_work+step_work;
        next_level=level_work;next_env=env_work;next_release=release_work;
        if(!held_work && !(frame_sustain || (frame_sostenuto && sost_work)) &&
            env_work!=ENV_IDLE && env_work!=RELEASE) begin
            next_env=RELEASE;next_release=frame_release;
        end else case(env_work)
            ENV_IDLE:next_level=0;
            ATTACK:if(attack_sum>=17'd65535) begin next_level=65535;next_env=DECAY;end
                   else next_level=attack_sum[15:0];
            DECAY:if({1'b0,level_work}<=decay_floor) begin next_level=sustain_work;next_env=SUSTAIN;end
                  else next_level=level_work-d_step;
            SUSTAIN:next_level=sustain_work;
            RELEASE:if(level_work<=r_step) begin next_level=0;next_env=ENV_IDLE;end
                    else next_level=level_work-r_step;
            default:begin next_level=0;next_env=ENV_IDLE;end
        endcase
    end
    reg [1:0] harmonic_index;
    reg [31:0] address_phase;
    wire signed [15:0] sine_data;
    palette_sine sine_lut(clk,address_phase[31:20],sine_data);
    wire signed [25:0] extended_sine={{10{sine_data[15]}},sine_data};
    reg signed [25:0] harmonic_sum;
    reg signed [42:0] envelope_product;
    reg signed [31:0] mix_sum;
    wire signed [42:0] rounded_voice=envelope_product<0 ?
        -(((-envelope_product)+43'sd4194304)>>>23) :
        (envelope_product+43'sd4194304)>>>23;
    wire signed [31:0] voice_q4=rounded_voice[31:0];
    wire signed [31:0] total_q4=mix_sum+voice_q4;
    wire signed [31:0] rounded_mix=mix_sum<0 ?
        -(((-mix_sum)+(32'sd8<<<OUTPUT_SHIFT))>>>(4+OUTPUT_SHIFT)) :
        (mix_sum+(32'sd8<<<OUTPUT_SHIFT))>>>(4+OUTPUT_SHIFT);
    assign event_ready=!rst && state==IDLE && !event_pending && !sample_ce;
    integer i;
    always @(posedge clk) begin
        if(rst) begin sost_previous<=0;sost_mask<=0;end
        else begin
            sost_previous<=sostenuto;
            if(!sostenuto) sost_mask<=0;
            else if(!sost_previous) sost_mask<=held&occupied;
            else sost_mask<=sost_mask&occupied;
        end
    end
    always @(posedge clk) begin
        if(rst) begin
            state<=IDLE;occupied<=0;held<=0;gated<=0;event_pending<=0;
            command_off<=0;command_token<=0;command_note<=60;
            scan_index<=0;free_index<=0;match_index<=0;voice_index<=0;
            free_found<=0;match_found<=0;accepted<=0;rejected<=0;
            rejected_count<=0;unmatched_off_count<=0;
            frame_sustain<=0;frame_sostenuto<=0;frame_sost_mask<=0;frame_release<=3;
            phase_work<=0;step_work<=0;level_work<=0;attack_work<=68;decay_work<=6;
            sustain_work<=32768;release_work<=3;env_work<=0;held_work<=0;sost_work<=0;
            harmonic_index<=0;address_phase<=0;harmonic_sum<=0;envelope_product<=0;
            mix_sum<=0;mixed_q4<=0;out_valid<=0;out_sample<=0;clipped<=0;deadline_missed<=0;
            for(i=0;i<N;i=i+1) begin
                phases[i]<=0;steps[i]<=0;tokens[i]<=0;levels[i]<=0;notes[i]<=60;
                attacks[i]<=68;decays[i]<=6;sustains[i]<=32768;releases[i]<=3;env_states[i]<=0;
            end
        end else begin
            accepted<=0;rejected<=0;out_valid<=0;clipped<=0;
            if(sample_ce) begin
                // Event scans may be paused, but a renderer overrun is an error.
                if(state>=R_READ) deadline_missed<=1;
                frame_sustain<=sustain;frame_sostenuto<=sostenuto;
                frame_sost_mask<=sost_mask;frame_release<=release_step;
                if(event_pending) begin scan_index<=0;free_found<=0;match_found<=0;end
                voice_index<=0;mix_sum<=0;state<=R_READ;
            end else case(state)
                IDLE:if(event_valid && event_ready) begin
                    event_pending<=1;command_off<=event_off;
                    command_token<=event_token;command_note<=event_note;
                    scan_index<=0;free_found<=0;match_found<=0;state<=E_SCAN;
                end
                E_SCAN:begin
                    if(!occupied[scan_index] && !free_found) begin
                        free_found<=1;free_index<=scan_index;
                    end
                    if(occupied[scan_index] && tokens[scan_index]==command_token) begin
                        match_found<=1;match_index<=scan_index;
                    end
                    if(scan_index==N-1) state<=E_COMMIT;
                    else scan_index<=scan_index+1'b1;
                end
                E_COMMIT:begin
                    if(command_off) begin
                        if(match_found && command_token!=0) begin
                            held[match_index]<=0;
                            if(!(sustain || (sostenuto && sost_mask[match_index]))) begin
                                env_states[match_index]<=RELEASE;gated[match_index]<=0;
                                releases[match_index]<=release_step;
                            end
                            accepted<=1;
                        end else unmatched_off_count<=unmatched_off_count+1'b1;
                    end else if(free_found && !match_found && command_token!=0 &&
                                command_note>=36 && command_note<=84) begin
                        phases[free_index]<=0;steps[free_index]<=command_step;
                        tokens[free_index]<=command_token;notes[free_index]<=command_note;
                        levels[free_index]<=0;env_states[free_index]<=ATTACK;
                        attacks[free_index]<=attack_step;decays[free_index]<=decay_step;
                        sustains[free_index]<=sustain_level;releases[free_index]<=release_step;
                        occupied[free_index]<=1;held[free_index]<=1;gated[free_index]<=1;
                        accepted<=1;
                    end else begin rejected<=1;rejected_count<=rejected_count+1'b1;end
                    event_pending<=0;state<=IDLE;
                end
                R_READ:begin
                    phase_work<=phases[voice_index];step_work<=steps[voice_index];
                    level_work<=levels[voice_index];env_work<=env_states[voice_index];
                    attack_work<=attacks[voice_index];decay_work<=decays[voice_index];
                    sustain_work<=sustains[voice_index];release_work<=releases[voice_index];
                    held_work<=held[voice_index];sost_work<=frame_sost_mask[voice_index];
                    state<=R_UPDATE;
                end
                R_UPDATE:begin
                    phases[voice_index]<=next_phase;levels[voice_index]<=next_level;
                    env_states[voice_index]<=next_env;releases[voice_index]<=next_release;
                    gated[voice_index]<=occupied[voice_index] && next_env!=RELEASE && next_env!=ENV_IDLE;
                    if(next_env==ENV_IDLE) begin occupied[voice_index]<=0;held[voice_index]<=0;end
                    phase_work<=next_phase;level_work<=next_level;
                    harmonic_index<=0;harmonic_sum<=0;state<=R_ADDR;
                end
                R_ADDR:begin
                    case(harmonic_index)
                        0:address_phase<=phase_work;
                        1:address_phase<=phase_work<<1;
                        2:address_phase<=phase_work+(phase_work<<1);
                        3:address_phase<=phase_work<<2;
                    endcase
                    state<=R_WAIT;
                end
                R_WAIT:state<=R_GET;
                R_GET:begin
                    case(harmonic_index)
                        0:harmonic_sum<=extended_sine<<<7;
                        1:harmonic_sum<=harmonic_sum+(extended_sine<<<5);
                        2:harmonic_sum<=harmonic_sum+(extended_sine<<<4);
                        3:harmonic_sum<=harmonic_sum+(extended_sine<<<3);
                    endcase
                    if(harmonic_index==3) state<=R_MULT;
                    else begin harmonic_index<=harmonic_index+1'b1;state<=R_ADDR;end
                end
                R_MULT:begin
                    envelope_product<=harmonic_sum*$signed({1'b0,level_work});state<=R_ACCUM;
                end
                R_ACCUM:begin
                    mix_sum<=total_q4;
                    if(voice_index==N-1) state<=R_FINISH;
                    else begin voice_index<=voice_index+1'b1;state<=R_READ;end
                end
                R_FINISH:begin
                    mixed_q4<=mix_sum;
                    if(rounded_mix>32767) begin out_sample<=32767;clipped<=1;end
                    else if(rounded_mix< -32768) begin out_sample<=-32768;clipped<=1;end
                    else out_sample<=rounded_mix[15:0];
                    out_valid<=1;state<=event_pending ? E_SCAN : IDLE;
                end
                default:state<=IDLE;
            endcase
        end
    end
endmodule

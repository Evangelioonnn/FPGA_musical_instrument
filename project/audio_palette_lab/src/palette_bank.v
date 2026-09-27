module palette_bank #(parameter PROFILE=0,parameter N=8,parameter SW=(N>1?$clog2(N):1))(
    input wire clk,rst,sample_ce,event_valid,
    output wire event_ready,
    input wire event_off,input wire [31:0] event_token,
    input wire [6:0] event_note,input wire [1:0] event_timbre,
    input wire pedal,input wire [15:0] reference_release,
    output reg accepted,rejected,output reg [31:0] rejected_count,unmatched_off_count,
    output wire [N-1:0] occupied,held,
    output reg out_valid,output reg signed [15:0] out_sample,
    output reg clipped,deadline_missed
);
    reg [6:0] note;
    reg [1:0] mix_state;
    reg [N-1:0] start_mask,stop_mask;
    wire [N-1:0] busy;
    wire [N*20-1:0] samples;
    wire [N*32-1:0] phases;
    wire [N*16-1:0] envelopes,brightness;
    wire [N-1:0] harmonic_valid;
    wire signed [19:0] harmonic_sample;
    wire tone_deadline;
    wire [31:0] new_step;wire [9:0] new_length;
    wire [15:0] new_fraction;wire [24:0] new_reciprocal;
    note_table notes(note,new_step);
    pluck_note_table strings(note,new_length,new_fraction,new_reciprocal);
    palette_shared_tone #(.PROFILE(PROFILE),.N(N)) tones(clk,rst,sample_ce,
        phases,envelopes,brightness,harmonic_sample,harmonic_valid,tone_deadline);
    reg [31:0] tokens[0:N-1];
    reg [1:0] timbre;
    reg free_found,duplicate,match_found;
    reg [SW-1:0] free_slot,match_slot;
    integer i,j;
    assign occupied=busy|start_mask;
    assign event_ready=!rst && !sample_ce && mix_state==0 && !(|start_mask) && !(|stop_mask);
    always @* begin
        free_found=0;free_slot=0;duplicate=0;match_found=0;match_slot=0;
        for(i=0;i<N;i=i+1) begin
            if(!occupied[i] && !free_found) begin free_found=1;free_slot=i;end
            if(occupied[i] && tokens[i]==event_token) begin
                duplicate=1;match_found=1;match_slot=i;
            end
        end
    end
    genvar g;
    generate for(g=0;g<N;g=g+1) begin: slots
        palette_slot #(.PROFILE(PROFILE)) slot(clk,rst,sample_ce,start_mask[g],stop_mask[g],note,timbre,
            new_step,new_length,new_fraction,new_reciprocal,harmonic_sample,harmonic_valid[g],
            phases[g*32+:32],envelopes[g*16+:16],brightness[g*16+:16],
            pedal,reference_release,busy[g],held[g],samples[g*20+:20]);
    end endgenerate
    always @(posedge clk) begin
        if(rst) begin
            start_mask<=0;stop_mask<=0;note<=60;timbre<=0;accepted<=0;rejected<=0;
            rejected_count<=0;unmatched_off_count<=0;
            for(j=0;j<N;j=j+1) tokens[j]<=0;
        end else begin
            start_mask<=0;stop_mask<=0;accepted<=0;rejected<=0;
            if(event_valid && event_ready) begin
                if(event_off) begin
                    if(match_found && event_token!=0) stop_mask[match_slot]<=1;
                    else unmatched_off_count<=unmatched_off_count+1'b1;
                end else if(free_found && !duplicate && event_token!=0 &&
                    event_note>=36 && event_note<=84 && event_timbre<=1) begin
                    start_mask[free_slot]<=1;tokens[free_slot]<=event_token;
                    note<=event_note;timbre<=event_timbre;accepted<=1;
                end else begin
                    rejected<=1;rejected_count<=rejected_count+1'b1;
                end
            end
        end
    end
    reg [15:0] wait_left;
    reg [SW-1:0] index;
    reg [N*20-1:0] frame;
    reg signed [31:0] sum;
    wire signed [19:0] term=frame[index*20+:20];
    wire signed [31:0] next_sum=sum+{{12{term[19]}},term};
    wire signed [31:0] rounded_sum = next_sum<0 ? -(((-next_sum)+8)>>>4) : (next_sum+8)>>>4;
    always @(posedge clk) begin
        if(rst) begin
            wait_left<=0;mix_state<=0;index<=0;frame<=0;sum<=0;
            out_valid<=0;out_sample<=0;clipped<=0;deadline_missed<=0;
        end else begin
            out_valid<=0;clipped<=0;
            if(tone_deadline) deadline_missed<=1;
            if(sample_ce) begin
                if(mix_state!=0) deadline_missed<=1;
                wait_left<=16+N*10;mix_state<=1;
            end else case(mix_state)
                1: if(wait_left==1) begin frame<=samples;sum<=0;index<=0;mix_state<=2;end
                   else wait_left<=wait_left-1'b1;
                2: begin
                    sum<=next_sum;
                    if(index==N-1) begin
                        if(rounded_sum>32767) begin out_sample<=32767;clipped<=1;end
                        else if(rounded_sum< -32768) begin out_sample<=-32768;clipped<=1;end
                        else out_sample<=rounded_sum[15:0];
                        out_valid<=1;mix_state<=0;
                    end else index<=index+1'b1;
                end
                default:mix_state<=0;
            endcase
        end
    end
endmodule

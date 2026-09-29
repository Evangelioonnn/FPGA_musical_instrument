// Bounded independent-strike allocator + time scheduled full-width mixer.
// Never steals a live slot; rejected pulses and count expose overload.
module knob_bank #(parameter N=16,MULTI=0,DYNAMIC_ADSR=0,
    parameter SLOT_W=(N>1?$clog2(N):1))(
    input wire clk,rst,sample_ce,strike_valid,
    output wire strike_ready,
    input wire [6:0] note,input wire [1:0] timbre,
    input wire [23:0] gate_samples,
    input wire [15:0] attack,decay,sustain_level,release_step,
    input wire pedal_sustain,pedal_sostenuto,all_release,
    output reg accepted,rejected,
    output reg [SLOT_W-1:0] accepted_slot,
    output reg [31:0] rejected_count,
    output wire [N-1:0] occupied,gated,sost_captured,
    output reg out_valid,output reg signed [15:0] out_sample,
    output reg clipped,deadline_missed
);
    reg [N-1:0] start_mask;
    wire [N-1:0] busy,done;
    wire [N*16-1:0] samples;
    reg [6:0] held_note;
    reg [1:0] held_timbre;
    reg [23:0] held_gate;
    reg [15:0] a,d,s,r;
    reg free_found;
    reg [SLOT_W-1:0] free_slot;
    integer i;
    wire default_adsr=attack==68 && decay==6 && sustain_level==32768 && release_step==3;
    wire legal_adsr=(DYNAMIC_ADSR && timbre==0) || default_adsr;
    assign occupied=busy|start_mask;
    assign strike_ready=!rst && !(|start_mask);
    always @* begin
        free_found=0;free_slot=0;
        for(i=0;i<N;i=i+1) if(!occupied[i] && !free_found) begin
            free_found=1;free_slot=i;
        end
    end
    genvar g;
    generate for(g=0;g<N;g=g+1) begin: slots
        knob_slot #(.MULTI(MULTI),.DYNAMIC_ADSR(DYNAMIC_ADSR)) slot(
            clk,rst,sample_ce,start_mask[g],held_note,held_timbre,held_gate,a,d,s,r,
            pedal_sustain,pedal_sostenuto,all_release,busy[g],gated[g],sost_captured[g],
            done[g],samples[g*16+:16]);
    end endgenerate
    always @(posedge clk) begin
        if(rst) begin
            start_mask<=0;held_note<=60;held_timbre<=0;held_gate<=31250;
            a<=68;d<=6;s<=32768;r<=3;accepted<=0;rejected<=0;accepted_slot<=0;rejected_count<=0;
        end else begin
            start_mask<=0;accepted<=0;rejected<=0;
            if(strike_valid && strike_ready) begin
                if(free_found && note>=48 && note<=84 && timbre<=2 &&
                    (MULTI || timbre==0) && legal_adsr && gate_samples!=0 && !all_release) begin
                    start_mask[free_slot]<=1;accepted<=1;accepted_slot<=free_slot;
                    held_note<=note;held_timbre<=timbre;held_gate<=gate_samples;
                    a<=attack;d<=decay;s<=sustain_level;r<=release_step;
                end else begin rejected<=1;rejected_count<=rejected_count+1'b1;end
            end
        end
    end
    // Voice paths finish within 16 clocks; 64 gives explicit settling margin.
    // Snapshot first, then accumulate one slot per clock. No N-deep adder chain.
    reg [6:0] wait_left;
    reg [1:0] mix_state;
    reg [SLOT_W-1:0] index;
    reg [N*16-1:0] frame;
    reg signed [31:0] sum;
    wire signed [15:0] term=frame[index*16+:16];
    wire signed [31:0] next_sum=sum+{{16{term[15]}},term};
    always @(posedge clk) begin
        if(rst) begin
            wait_left<=0;mix_state<=0;index<=0;frame<=0;sum<=0;
            out_valid<=0;out_sample<=0;clipped<=0;deadline_missed<=0;
        end else begin
            out_valid<=0;clipped<=0;
            if(sample_ce) begin
                if(mix_state!=0) deadline_missed<=1;
                wait_left<=64;mix_state<=1;
            end else case(mix_state)
                1: if(wait_left==1) begin frame<=samples;sum<=0;index<=0;mix_state<=2;end
                    else wait_left<=wait_left-1'b1;
                2: begin
                    sum<=next_sum;
                    if(index==N-1) begin
                        if(next_sum>32767) begin out_sample<=32767;clipped<=1;end
                        else if(next_sum< -32768) begin out_sample<= -32768;clipped<=1;end
                        else out_sample<=next_sum[15:0];
                        out_valid<=1;mix_state<=0;
                    end else index<=index+1'b1;
                end
                default: mix_state<=0;
            endcase
        end
    end
endmodule

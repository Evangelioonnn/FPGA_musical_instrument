module expressive_voice(
    input wire clk,rst,sample_ce,note_on,note_off,fresh,
    input wire [31:0] base_step,
    input wire [17:0] bend_ratio,
    input wire [30:0] glide_delta,
    input wire [8:0] velocity,
    input wire [14:0] weight2,weight3,
    input wire [15:0] attack_step,decay_step,sustain_level,release_step,
    output reg signed [15:0] sample,
    output reg sample_valid,
    output wire [15:0] envelope,
    output wire [2:0] env_state,
    output reg [31:0] current_step,phase
);
    reg [15:0] a,d,s,r,env_snapshot;
    reg [8:0] velocity_hold,velocity_snapshot;
    reg [49:0] pitch_product;
    wire [33:0] pitch_scaled=pitch_product[49:16];
    wire [31:0] target_step=(pitch_scaled>=34'h07fffffff) ? 32'h7fffffff : pitch_scaled[31:0];
    reg fresh_pending;
    reg [31:0] next_step;
    reg [5:0] pipe_ce;
    wire [31:0] phase2=phase<<1,phase3=phase+(phase<<1);
    wire signed [15:0] sine1,sine2,sine3;
    reg allow2,allow3;
    wire signed [15:0] coeff2=allow2 ? {1'b0,weight2} : 16'sd0;
    wire signed [15:0] coeff3=allow3 ? {1'b0,weight3} : 16'sd0;
    wire signed [16:0] difference2=$signed({sine2[15],sine2})-$signed({sine1[15],sine1});
    wire signed [16:0] difference3=$signed({sine3[15],sine3})-$signed({sine1[15],sine1});
    reg signed [15:0] fundamental;
    reg signed [32:0] p2,p3;
    // Exact algebraic refactor: one unscaled fundamental plus two weighted differences.
    wire signed [34:0] wave_sum=$signed({{3{fundamental[15]}},fundamental,16'b0})+
        $signed({{2{p2[32]}},p2})+$signed({{2{p3[32]}},p3});
    reg signed [15:0] wave;
    reg signed [32:0] envelope_product;
    wire signed [15:0] env_scaled=envelope_product[31:16];
    reg signed [25:0] velocity_product;
    // Direct on-cycle parameters and latched values thereafter.
    adsr_envelope env(clk,rst,sample_ce,note_on,note_off,
        note_on?attack_step:a,note_on?decay_step:d,note_on?sustain_level:s,note_on?release_step:r,
        envelope,env_state);
    sine_rom rom1(clk,phase[31:22],sine1);
    sine_rom rom2(clk,phase2[31:22],sine2);
    sine_rom rom3(clk,phase3[31:22],sine3);
    always @* begin
        if(fresh_pending || glide_delta==0) next_step=target_step;
        else if(current_step<target_step)
            next_step=(target_step-current_step<=glide_delta) ? target_step : current_step+glide_delta;
        else next_step=(current_step-target_step<=glide_delta) ? target_step : current_step-glide_delta;
    end
    always @(posedge clk) begin
        if(rst) begin
            a<=68;d<=6;s<=32768;r<=3;env_snapshot<=0;
            velocity_hold<=0;velocity_snapshot<=0;pitch_product<=0;
            current_step<=0;phase<=0;fresh_pending<=0;pipe_ce<=0;
            allow2<=0;allow3<=0;fundamental<=0;p2<=0;p3<=0;wave<=0;
            envelope_product<=0;velocity_product<=0;sample<=0;sample_valid<=0;
        end else begin
            pitch_product<=base_step*bend_ratio;
            if(note_on) begin
                a<=attack_step;d<=decay_step;s<=sustain_level;r<=release_step;
                velocity_hold<=velocity>256 ? 9'd256 : velocity;
            end
            if(sample_ce) begin
                current_step<=next_step;phase<=phase+next_step;fresh_pending<=0;
            end
            if(fresh) fresh_pending<=1;
            pipe_ce<={pipe_ce[4:0],sample_ce};sample_valid<=pipe_ce[5];
            if(pipe_ce[0]) begin
                env_snapshot<=envelope;velocity_snapshot<=velocity_hold;
                allow2<=current_step<32'h40000000;
                allow3<=current_step<32'h2aaaaaab;
            end
            if(pipe_ce[1]) begin
                fundamental<=sine1;
                p2<=difference2*coeff2;
                p3<=difference3*coeff3;
            end
            if(pipe_ce[2]) wave<=wave_sum[31:16];
            if(pipe_ce[3]) envelope_product<=wave*$signed({1'b0,env_snapshot});
            if(pipe_ce[4]) velocity_product<=env_scaled*$signed({1'b0,velocity_snapshot});
            if(pipe_ce[5]) sample<=velocity_product[23:8];
        end
    end
endmodule

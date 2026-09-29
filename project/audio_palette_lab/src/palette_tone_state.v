// Per-voice identity/phase/envelope only; no waveform ROM or audio multiplier.
module palette_tone_state #(parameter PROFILE=0)(
    input wire clk,rst,sample_ce,note_on,note_off,
    input wire [31:0] phase_step,input wire [15:0] release_step,
    output reg [31:0] phase,output wire [15:0] envelope,
    output reg [15:0] brightness,output wire [2:0] env_state
);
    reg [31:0] step_hold;
    always @(posedge clk) begin
        if(rst) begin phase<=0;step_hold<=0;brightness<=65535;end
        else begin
            if(note_on) begin step_hold<=phase_step;brightness<=65535;end
            else if(sample_ce && (PROFILE==2 || PROFILE==3)) begin
                if(brightness>0) brightness<=brightness-((brightness>>12)+1'b1);
            end
            if(sample_ce) phase<=phase+(note_on ? phase_step : step_hold);
        end
    end
    generate if(PROFILE==2 || PROFILE==3) begin: natural_piano
        // Q24 amplitude: 4 ms attack, about 1.36 s decay time constant.
        // Natural decay continues with the pedal down; release adds damping.
        reg [23:0] level;
        reg [2:0] state;
        wire [24:0] attack_sum={1'b0,level}+25'd85500;
        wire [24:0] damping=({9'd0,release_step}<<8);
        wire [24:0] natural_loss={17'd0,level[23:16]}+1'b1;
        assign envelope=level[23:8];assign env_state=state;
        always @(posedge clk) begin
            if(rst) begin level<=0;state<=0;end
            else if(note_on) state<=1;
            else if(note_off && state!=0) state<=4;
            else if(sample_ce) case(state)
                0:level<=0;
                1:if(attack_sum>=25'd16777215) begin level<=24'hffffff;state<=2;end
                  else level<=attack_sum[23:0];
                2:if(level<=natural_loss) begin level<=0;state<=0;end
                  else level<=level-natural_loss;
                4:if(level<=damping+natural_loss) begin level<=0;state<=0;end
                  else level<=level-damping-natural_loss;
                default:begin level<=0;state<=0;end
            endcase
        end
    end else begin: adsr
        adsr_envelope env(clk,rst,sample_ce,note_on,note_off,
            PROFILE==4 ? 16'd136 : 16'd68,16'd6,16'd32768,release_step,envelope,env_state);
    end endgenerate
endmodule

module noise_gain_stage #(parameter SHIFT=0)(
    input wire signed [15:0] in_sample,
    output reg signed [15:0] out_sample,
    output reg clipped
);
    reg signed [18:0] scaled;
    always @* begin
        scaled=$signed({{3{in_sample[15]}},in_sample}) <<< SHIFT;
        clipped=0;
        if(scaled>19'sd32767) begin out_sample=16'sd32767;clipped=1;end
        else if(scaled< -19'sd32768) begin out_sample=-16'sd32768;clipped=1;end
        else out_sample=scaled[15:0];
    end
endmodule

module noise_audio_output #(parameter OSR=1,GAIN_SHIFT=0,
    parameter PHASE_WIDTH=(OSR>1?$clog2(OSR):1))(
    input wire clk,rst,frame_ce,rendered_valid,
    input wire signed [15:0] rendered_sample,
    output wire render_ce,
    output wire signed [15:0] dac_sample,
    output wire gain_clipped
);
    wire signed [15:0] gained_sample;
    noise_gain_stage #(.SHIFT(GAIN_SHIFT)) gain(
        rendered_sample,gained_sample,gain_clipped);

    generate if(OSR==1) begin: native_rate
        assign render_ce=frame_ce;
        assign dac_sample=gained_sample;
    end else begin: interpolated_rate
        reg [PHASE_WIDTH-1:0] phase;
        reg signed [15:0] previous_sample,current_sample;
        wire signed [16:0] difference=
            $signed({current_sample[15],current_sample})-
            $signed({previous_sample[15],previous_sample});
        wire signed [18:0] difference_ext={{2{difference[16]}},difference};
        reg signed [18:0] numerator;
        wire signed [18:0] fraction=numerator >>> $clog2(OSR);
        wire signed [19:0] interpolated=
            $signed({{4{previous_sample[15]}},previous_sample})+
            $signed({fraction[18],fraction});

        assign render_ce=frame_ce && (phase==0);
        assign dac_sample=(phase==0)?current_sample:interpolated[15:0];

        always @* begin
            case(phase)
                1: numerator=difference_ext;
                2: numerator=difference_ext <<< 1;
                3: numerator=difference_ext + (difference_ext <<< 1);
                default: numerator=0;
            endcase
        end

        always @(posedge clk) begin
            if(rst) begin
                phase<=0;previous_sample<=0;current_sample<=0;
            end else begin
                if(frame_ce) begin
                    if(phase==OSR-1) phase<=0;
                    else phase<=phase+1'b1;
                end
                if(rendered_valid) begin
                    previous_sample<=current_sample;
                    current_sample<=gained_sample;
                end
            end
        end
    end endgenerate
endmodule

// Local playable-gallery fork; baseline sources remain unchanged.
// Isolated fork of palette module at db653ef; see SPEC.md.
// S1 selects five presets plus the editable harmonic sound. In that sound,
// S4/EC11 select and adjust the five simulated fader channels.
// S4 selects volume/octaves/release/glide/bend or panics on a long press.
// Encoder adjustments are relative and saturate at the configured endpoints.
module custom_gallery_controls #(parameter PROFILE=0,
    parameter BUTTON_CYCLES=150000,
    parameter LONG_CYCLES=50000000,
    parameter LW=(LONG_CYCLES>1?$clog2(LONG_CYCLES):1)
)(
    input wire clk,rst,
    input wire [2:0] button_n,
    input wire step_valid,
    input wire signed [1:0] step,
    input wire fault,
    output reg [2:0] timbre,
    output reg sustain,sostenuto,
    output wire release_mode,
    output reg [2:0] control_mode, output reg [6:0] left_base,right_base,
    output reg panic,
    output reg [4:0] volume_index,
    output reg [2:0] reference_release_index,glide_index,
    output reg [1:0] lead_attack_index,
    output reg signed [4:0] bend_index,
    output reg [16:0] bend_factor,
    output wire [16:0] volume_target,
    output reg [15:0] reference_release
);
    wire [2:0] down,press,up;
    genvar b;
    generate for(b=0;b<3;b=b+1) begin: filters
        playable_button #(.DEBOUNCE_CYCLES(BUTTON_CYCLES)) f(
            clk,rst,button_n[b],down[b],press[b],up[b]);
    end endgenerate

    assign release_mode=control_mode==3;
    reg [LW-1:0] held;
    reg long_fired;
    reg [LW-1:0] sustain_held;
    reg sustain_long_fired;
    wire rotate_up=step_valid && step==1;
    wire rotate_down=step_valid && step==-1;
    knob_volume_table volume(volume_index,volume_target);

    always @* begin
        case(reference_release_index)
            0:reference_release=16'd96;
            1:reference_release=16'd48;
            2:reference_release=16'd24;
            3:reference_release=16'd12;
            4:reference_release=16'd6;
            5:reference_release=16'd3;
            6:reference_release=16'd2;
            default:reference_release=16'd1;
        endcase
    end

    always @(posedge clk) begin
        if(rst) begin
            timbre<=0; // Uniform piano start; profile 6 preserves warm pluck.
            sustain<=0;
            sostenuto<=0;sustain_held<=0;sustain_long_fired<=0;bend_index<=0;
            bend_factor<=17'd65536;
            control_mode<=0;left_base<=48;right_base<=60;
            panic<=0;
            volume_index<=18; // Start below the reported three-note artifact threshold.
            reference_release_index<=5;
            glide_index<=0;
            lead_attack_index<=2;
            held<=0;
            long_fired<=0;
        end else begin
            panic<=0;
            case(bend_index)
                -5'sd8:bend_factor<=17'd58386;
                -5'sd7:bend_factor<=17'd59235;
                -5'sd6:bend_factor<=17'd60097;
                -5'sd5:bend_factor<=17'd60971;
                -5'sd4:bend_factor<=17'd61858;
                -5'sd3:bend_factor<=17'd62757;
                -5'sd2:bend_factor<=17'd63670;
                -5'sd1:bend_factor<=17'd64596;
                5'sd1:bend_factor<=17'd66489;
                5'sd2:bend_factor<=17'd67456;
                5'sd3:bend_factor<=17'd68438;
                5'sd4:bend_factor<=17'd69433;
                5'sd5:bend_factor<=17'd70443;
                5'sd6:bend_factor<=17'd71468;
                5'sd7:bend_factor<=17'd72507;
                5'sd8:bend_factor<=17'd73562;
                default:bend_factor<=17'd65536;
            endcase
            if(press[2]) begin
                if(timbre==5) begin timbre<=0;control_mode<=0;end
                else if(timbre==4) begin timbre<=5;control_mode<=0;end
                else timbre<=timbre+1'b1;
            end
            if(down[1] && !sustain_long_fired) begin
                if(sustain_held==LONG_CYCLES-1) begin
                    sustain_long_fired<=1;
                    sostenuto<=!sostenuto;
                end else sustain_held<=sustain_held+1'b1;
            end
            if(up[1]) begin
                if(!sustain_long_fired) sustain<=!sustain;
                sustain_held<=0;sustain_long_fired<=0;
            end
            if(down[0] && !long_fired) begin
                if(held==LONG_CYCLES-1) begin
                    long_fired<=1;
                    panic<=1;
                    sustain<=0;
                    sostenuto<=0;bend_index<=0;
                end else held<=held+1'b1;
            end
            if(up[0]) begin
                if(!long_fired) begin
                    if(timbre==5) control_mode<=control_mode==4 ? 0 : control_mode+1'b1;
                    else begin
                        control_mode<=control_mode==6 ? 0 : control_mode+1'b1;
                        if(control_mode==5) bend_index<=0;
                    end
                end
                held<=0;
                long_fired<=0;
            end
            if(timbre!=5 && control_mode==0) begin
                if(rotate_up && volume_index<24) volume_index<=volume_index+1'b1;
                if(rotate_down && volume_index>0) volume_index<=volume_index-1'b1;
            end else if(timbre!=5 && control_mode==1) begin
                if(rotate_up && left_base<72) left_base<=left_base+12;
                if(rotate_down && left_base>36) left_base<=left_base-12;
            end else if(timbre!=5 && control_mode==2) begin
                if(rotate_up && right_base<72) right_base<=right_base+12;
                if(rotate_down && right_base>36) right_base<=right_base-12;
            end else if(timbre!=5 && control_mode==3) begin
                if(rotate_up && reference_release_index<7)
                    reference_release_index<=reference_release_index+1'b1;
                if(rotate_down && reference_release_index>0)
                    reference_release_index<=reference_release_index-1'b1;
            end else if(timbre!=5 && control_mode==4) begin
                if(rotate_up && glide_index<4) glide_index<=glide_index+1'b1;
                if(rotate_down && glide_index>0) glide_index<=glide_index-1'b1;
            end else if(timbre!=5 && control_mode==5) begin
                if(rotate_up && bend_index<8) bend_index<=bend_index+1'b1;
                if(rotate_down && bend_index> -8) bend_index<=bend_index-1'b1;
            end else if(timbre!=5) begin
                if(rotate_up && lead_attack_index<3) lead_attack_index<=lead_attack_index+1'b1;
                if(rotate_down && lead_attack_index>0) lead_attack_index<=lead_attack_index-1'b1;
            end
            if(fault) begin sustain<=0;sostenuto<=0;bend_index<=0;end
        end
    end
endmodule

// Isolated fork of palette module at db653ef; see SPEC.md.
// Product control contract for the dual-timbre candidate.
// button_n[2] selects harmonic_piano/pluck, button_n[1] toggles sustain,
// button_n[0] switches volume/release mode on a short press and panics on a
// long press. The encoder is deliberately relative and saturating.
module output_controls #(parameter PROFILE=0,
    parameter BUTTON_CYCLES=150000,
    parameter LONG_CYCLES=50000000,
    parameter LW=(LONG_CYCLES>1?$clog2(LONG_CYCLES):1)
)(
    input wire clk,rst,
    input wire [2:0] button_n,
    input wire step_valid,
    input wire signed [1:0] step,
    input wire fault,
    output reg [1:0] timbre,
    output reg sustain,
    output wire release_mode,
    output reg [1:0] control_mode, output reg [6:0] left_base,right_base,
    output reg panic,
    output reg [4:0] volume_index,
    output reg [2:0] reference_release_index,
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
            control_mode<=0;left_base<=48;right_base<=60;
            panic<=0;
            volume_index<=18; // Start below the reported three-note artifact threshold.
            reference_release_index<=5;
            held<=0;
            long_fired<=0;
        end else begin
            panic<=0;
            if(press[2]) timbre<=timbre==1 ? 0 : 1;
            if(press[1]) sustain<=!sustain;
            if(down[0] && !long_fired) begin
                if(held==LONG_CYCLES-1) begin
                    long_fired<=1;
                    panic<=1;
                    sustain<=0;
                end else held<=held+1'b1;
            end
            if(up[0]) begin
                if(!long_fired) control_mode<=control_mode+1'b1;
                held<=0;
                long_fired<=0;
            end
            if(control_mode==0) begin
                if(rotate_up && volume_index<24) volume_index<=volume_index+1'b1;
                if(rotate_down && volume_index>0) volume_index<=volume_index-1'b1;
            end else if(control_mode==1) begin
                if(rotate_up && left_base<72) left_base<=left_base+12;
                if(rotate_down && left_base>36) left_base<=left_base-12;
            end else if(control_mode==2) begin
                if(rotate_up && right_base<72) right_base<=right_base+12;
                if(rotate_down && right_base>36) right_base<=right_base-12;
            end else begin
                if(rotate_up && reference_release_index<7)
                    reference_release_index<=reference_release_index+1'b1;
                if(rotate_down && reference_release_index>0)
                    reference_release_index<=reference_release_index-1'b1;
            end
            if(fault) sustain<=0;
        end
    end
endmodule

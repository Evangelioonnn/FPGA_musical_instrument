module poly_controls #(parameter BUTTON_CYCLES=150000,parameter LONG_CYCLES=50000000,
    parameter LW=(LONG_CYCLES>1?$clog2(LONG_CYCLES):1))(
    input wire clk,rst,input wire [2:0] button_n,
    input wire step_valid,input wire signed [1:0] step,input wire fault,
    output reg sustain,sostenuto,panic,
    output reg [1:0] control_mode,output reg [6:0] left_base,right_base,
    output reg [4:0] volume_index,output reg [2:0] release_index,
    output wire [16:0] volume_target,output reg [15:0] release_step
);
    wire [2:0] down,press,up;
    genvar g;generate for(g=0;g<3;g=g+1) begin: buttons
        playable_button #(.DEBOUNCE_CYCLES(BUTTON_CYCLES)) button(
            clk,rst,button_n[g],down[g],press[g],up[g]);
    end endgenerate
    reg [LW-1:0] duration;
    reg long_fired;
    knob_volume_table volume(volume_index,volume_target);
    always @* case(release_index)
        0:release_step=96;1:release_step=48;2:release_step=24;3:release_step=12;
        4:release_step=6;5:release_step=3;6:release_step=2;default:release_step=1;
    endcase
    always @(posedge clk) begin
        if(rst) begin
            sustain<=0;sostenuto<=0;panic<=0;control_mode<=0;
            left_base<=48;right_base<=60;volume_index<=18;release_index<=5;
            duration<=0;long_fired<=0;
        end else begin
            panic<=0;
            if(press[2]) begin panic<=1;sustain<=0;sostenuto<=0;end
            if(press[0]) control_mode<=control_mode+1'b1;
            if(down[1] && !long_fired) begin
                if(duration==LONG_CYCLES-1) begin long_fired<=1;sostenuto<=!sostenuto;end
                else duration<=duration+1'b1;
            end
            if(up[1]) begin
                if(!long_fired) sustain<=!sustain;
                duration<=0;long_fired<=0;
            end
            if(step_valid) case(control_mode)
                0:begin
                    if(step==1 && volume_index<24) volume_index<=volume_index+1'b1;
                    if(step==-1 && volume_index>0) volume_index<=volume_index-1'b1;
                end
                1:begin
                    if(step==1 && left_base<72) left_base<=left_base+12;
                    if(step==-1 && left_base>36) left_base<=left_base-12;
                end
                2:begin
                    if(step==1 && right_base<72) right_base<=right_base+12;
                    if(step==-1 && right_base>36) right_base<=right_base-12;
                end
                3:begin
                    if(step==1 && release_index<7) release_index<=release_index+1'b1;
                    if(step==-1 && release_index>0) release_index<=release_index-1'b1;
                end
            endcase
            if(fault) begin sustain<=0;sostenuto<=0;end
        end
    end
endmodule

// MODE: 0=strikes, 1=volume, 2=timbre, 3=release, 4=echo amount.
// All demo sources emit note events; they never contain prerecorded samples.
module knob_controls #(parameter MODE=0)(
    input wire clk,rst,sample_ce,step_valid,input wire signed [1:0] step,
    output wire strike_valid,input wire strike_ready,
    output wire [6:0] strike_note,output wire [1:0] strike_timbre,
    output wire [23:0] strike_gate,output wire [15:0] strike_release,
    output wire [16:0] volume_target,output wire [15:0] wet_target,
    output reg [6:0] selected_note,output reg [1:0] selected_timbre,
    output reg [4:0] volume_index,output reg [2:0] release_index,
    output reg [4:0] effect_index,output reg [31:0] queue_overflows
);
    wire up=step_valid && step==1;
    wire down=step_valid && step==-1;
    wire [6:0] next_note=up ? (selected_note<84 ? selected_note+7'd1 : 7'd84) :
        down ? (selected_note>48 ? selected_note-7'd1 : 7'd48) : selected_note;
    reg [15:0] release_value;
    always @* case(release_index)
        0:release_value=96;1:release_value=48;2:release_value=24;3:release_value=12;
        4:release_value=6;5:release_value=3;6:release_value=2;default:release_value=1;
    endcase
    knob_volume_table volume_lut(volume_index,volume_target);
    assign wet_target={effect_index,10'd0};
    localparam PERIOD=(MODE==3 ? 57692 : MODE==2 ? 24038 : 48077);
    reg [15:0] auto_count;
    reg [1:0] phrase;
    reg [6:0] auto_note;
    always @* begin
        case(phrase)
            0:auto_note=60;1:auto_note=64;2:auto_note=67;default:auto_note=72;
        endcase
        if(MODE==3 || MODE==4) auto_note=60;
        if(MODE==1 && phrase==0) begin
            case(auto_count)
                1:auto_note=64;2:auto_note=67;3:auto_note=72;default:auto_note=60;
            endcase
        end
    end
    wire demo_event=sample_ce && (auto_count==0 ||
        (MODE==1 && phrase==0 && auto_count<=3));
    wire push=MODE==0 ? (up||down) : demo_event;
    wire [6:0] input_note=MODE==0 ? next_note : auto_note;
    wire [1:0] input_timbre=MODE==2 ? selected_timbre : 2'd0;
    wire [23:0] input_gate=(MODE==3 || MODE==4) ? 24'd9615 : 24'd31250;
    wire [15:0] input_release=MODE==3 ? release_value : 16'd3;
    wire in_ready;
    wire [4:0] queue_level;
    stream_fifo #(.WIDTH(49),.DEPTH(16)) events(clk,rst,1'b0,push,
        {input_note,input_timbre,input_gate,input_release},in_ready,strike_valid,
        {strike_note,strike_timbre,strike_gate,strike_release},strike_ready,queue_level);
    always @(posedge clk) begin
        if(rst) begin
            selected_note<=60;selected_timbre<=0;volume_index<=24;
            release_index<=5;effect_index<=0;queue_overflows<=0;auto_count<=0;phrase<=0;
        end else begin
            if(push && !in_ready) queue_overflows<=queue_overflows+1'b1;
            if(sample_ce) begin
                if(auto_count==PERIOD-1) begin auto_count<=0;phrase<=phrase+1'b1;end
                else auto_count<=auto_count+1'b1;
            end
            if(MODE==0 && (up||down)) selected_note<=next_note;
            if(MODE==1) begin
                if(up && volume_index<24) volume_index<=volume_index+1'b1;
                if(down && volume_index>0) volume_index<=volume_index-1'b1;
            end
            if(MODE==2) begin
                if(up) selected_timbre<=selected_timbre==2 ? 2'd0 : selected_timbre+1'b1;
                if(down) selected_timbre<=selected_timbre==0 ? 2'd2 : selected_timbre-1'b1;
            end
            if(MODE==3) begin
                if(up && release_index<7) release_index<=release_index+1'b1;
                if(down && release_index>0) release_index<=release_index-1'b1;
            end
            if(MODE==4) begin
                if(up && effect_index<16) effect_index<=effect_index+1'b1;
                if(down && effect_index>0) effect_index<=effect_index-1'b1;
            end
        end
    end
endmodule

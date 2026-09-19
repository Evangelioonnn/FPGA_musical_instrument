// Five verified physical pins only. Separate mono experiments; no system change.
module timbre_probe #(parameter PLUCK=0)(
    input wire sys_clk,
    output wire hp_bck, hp_ws, hp_din, pa_en
);
    reg [4:0] startup=0;
    wire rst=!startup[4];
    always @(posedge sys_clk) if(rst) startup<=startup+1'b1;
    wire sample_ce, cmd_ready, cmd_valid, cmd_rejected, active, sample_valid;
    wire [1:0] cmd_kind;
    wire [6:0] note;
    wire [8:0] velocity;
    wire [31:0] seed;
    wire signed [15:0] raw_sample;
    wire signed [15:0] attenuated = raw_sample >>> 5;
    reg signed [15:0] monitor_sample;
    timbre_demo demo(sys_clk,rst,sample_ce,cmd_ready,cmd_valid,cmd_kind,note,velocity,seed);
    generate if(PLUCK) begin: pluck_path
        pluck_voice voice(.clk(sys_clk),.rst(rst),.sample_ce(sample_ce),
            .cmd_valid(cmd_valid),.cmd_kind(cmd_kind),.note(note),
            .velocity(velocity),.seed(seed),.cmd_ready(cmd_ready),
            .cmd_rejected(cmd_rejected),.active(active),
            .sample(raw_sample),.sample_valid(sample_valid));
    end else begin: fm_path
        fm_voice voice(.clk(sys_clk),.rst(rst),.sample_ce(sample_ce),
            .cmd_valid(cmd_valid),.cmd_kind(cmd_kind),.note(note),
            .velocity(velocity),.seed(seed),.cmd_ready(cmd_ready),
            .cmd_rejected(cmd_rejected),.active(active),
            .sample(raw_sample),.sample_valid(sample_valid));
    end endgenerate
    // Fixed gain, never per-note normalization. Protect the original monitor
    // range even if a future experimental voice changes its amplitude scale.
    always @(posedge sys_clk) begin
        if(rst) monitor_sample<=0;
        else if(sample_valid) begin
            if(attenuated>511) monitor_sample<=511;
            else if(attenuated< -512) monitor_sample<= -512;
            else monitor_sample<=attenuated;
        end
    end
    pt8211_tx tx(sys_clk,rst,monitor_sample,monitor_sample,
        sample_ce,hp_bck,hp_ws,hp_din);
    assign pa_en=1'b0;
endmodule

module fm_probe_top(input wire sys_clk,output wire hp_bck,hp_ws,hp_din,pa_en);
    timbre_probe #(.PLUCK(0)) probe(sys_clk,hp_bck,hp_ws,hp_din,pa_en);
endmodule
module pluck_probe_top(input wire sys_clk,output wire hp_bck,hp_ws,hp_din,pa_en);
    timbre_probe #(.PLUCK(1)) probe(sys_clk,hp_bck,hp_ws,hp_din,pa_en);
endmodule

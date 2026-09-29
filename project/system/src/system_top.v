// Safe five-pin demonstration: original accepted event score, new integration engine.
// Physical controls are exercised in system_input_tb until their wiring is verified.
module system_top #(parameter N=8,SLOT=48077)(
    input wire sys_clk,output wire hp_bck,hp_ws,hp_din,pa_en
);
    reg [4:0] startup=0;
    wire rst=!startup[4];
    always @(posedge sys_clk) if(rst) startup<=startup+1'b1;
    wire ce,ev,cv,er,cr;
    wire [1:0] kind;wire [6:0] note,value;wire [8:0] velocity;
    wire [3:0] addr;wire [31:0] data;
    wire signed [15:0] sample;
    wire valid,clip;
    assign pa_en=0;
    system_demo #(.SLOT(SLOT)) demo(sys_clk,rst,ce,ev,kind,note,value,velocity,cv,addr,data);
    system_engine #(.N(N)) engine(.clk(sys_clk),.rst(rst),.sample_ce(ce),.emergency(1'b0),
        .event_valid(ev),.event_kind(kind),.event_note(note),.event_value(value),.event_velocity(velocity),.event_ready(er),
        .local_cfg_valid(cv),.local_cfg_addr(addr),.local_cfg_data(data),.local_cfg_ready(cr),
        .host_cfg_valid(1'b0),.host_cfg_addr(4'd0),.host_cfg_data(32'd0),.host_cfg_ready(),.pressure_gain(17'd65536),
        .cfg_ack(),.cfg_accepted(),.cfg_applied(),.cfg_source_host(),.sample(sample),.sample_valid(valid),.clipped(clip),
        .panic(),.snapshot_valid(),.snapshot_data(),.wave_valid(),.wave_sample(),.wave_index(),.occupied(),.held(),.gated(),.gain());
    pt8211_tx tx(sys_clk,rst,sample,sample,ce,hp_bck,hp_ws,hp_din);
endmodule

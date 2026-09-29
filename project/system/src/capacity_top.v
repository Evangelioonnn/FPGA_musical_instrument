// Throughput probe, not the default musical demonstration. All N voices are used.
module capacity_top #(parameter N=32)(
    input wire sys_clk,output wire hp_bck,hp_ws,hp_din,pa_en
);
    reg [4:0] startup=0;
    wire rst=!startup[4];
    always @(posedge sys_clk) if(rst) startup<=startup+1'b1;
    wire ce,ready;wire signed [15:0] sample;
    reg [16:0] position;
    reg ev;reg [1:0] kind;reg [6:0] note;
    assign pa_en=0;
    always @(posedge sys_clk) begin
        if(rst)begin position<=0;ev<=0;kind<=0;note<=48;end
        else begin
            ev<=0;
            if(ce)begin
                position<=position==96153 ? 0 : position+1'b1;
                if(position<N)begin ev<=1;kind<=0;note<=48+position;end
                if(position>=48077 && position<48077+N)begin ev<=1;kind<=1;note<=48+position-48077;end
            end
        end
    end
    system_engine #(.N(N)) engine(.clk(sys_clk),.rst(rst),.sample_ce(ce),.emergency(1'b0),
        .event_valid(ev),.event_kind(kind),.event_note(note),.event_value(7'd0),.event_velocity(9'd256),.event_ready(ready),
        .local_cfg_valid(1'b0),.local_cfg_addr(4'd0),.local_cfg_data(32'd0),.local_cfg_ready(),
        .host_cfg_valid(1'b0),.host_cfg_addr(4'd0),.host_cfg_data(32'd0),.host_cfg_ready(),.pressure_gain(17'd65536),
        .cfg_ack(),.cfg_accepted(),.cfg_applied(),.cfg_source_host(),.sample(sample),.sample_valid(),.clipped(),
        .panic(),.snapshot_valid(),.snapshot_data(),.wave_valid(),.wave_sample(),.wave_index(),.occupied(),.held(),.gated(),.gain());
    pt8211_tx tx(sys_clk,rst,sample,sample,ce,hp_bck,hp_ws,hp_din);
endmodule
module capacity16_top(input wire sys_clk,output wire hp_bck,hp_ws,hp_din,pa_en);
    capacity_top #(.N(16)) dut(sys_clk,hp_bck,hp_ws,hp_din,pa_en);
endmodule
module capacity32_top(input wire sys_clk,output wire hp_bck,hp_ws,hp_din,pa_en);
    capacity_top #(.N(32)) dut(sys_clk,hp_bck,hp_ws,hp_din,pa_en);
endmodule

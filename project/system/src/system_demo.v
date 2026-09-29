// Reuse the accepted score, omitting legacy writes to parameters fixed in v0.
module system_demo #(parameter SLOT=48077)(
    input wire clk,rst,ce,output wire event_valid,output wire [1:0] event_kind,
    output wire [6:0] event_note,event_value,output wire [8:0] event_velocity,
    output wire cfg_valid,output wire [3:0] cfg_addr,output wire [31:0] cfg_data
);
    wire legacy_cfg;
    baseline_demo #(.SLOT(SLOT)) score(clk,rst,ce,event_valid,event_kind,event_note,event_value,
        event_velocity,legacy_cfg,cfg_addr,cfg_data);
    assign cfg_valid=legacy_cfg && (cfg_addr==0 || cfg_addr==4 || cfg_addr==5 || cfg_addr==6);
endmodule

// Synthesis-only resource probe. No package pinout is implied by this port list.
module input_audit_top(
    input wire clk,rst,external_panic,input wire [3:0] col_n,
    output wire [3:0] row_low,input wire enc_a,enc_b,enc_button_n,
    input wire [111:0] note_map,input wire [8:0] velocity,
    input wire adc_valid,input wire [11:0] adc_raw,cal_low,cal_high,dead_zone,
    input wire pressure_enable,output wire adc_ready,output wire [16:0] pressure_gain,
    output wire event_valid,output wire [1:0] event_kind,output wire [6:0] event_note,
    output wire [8:0] event_velocity,input wire event_ready,
    output wire cfg_valid,output wire [3:0] cfg_addr,output wire [31:0] cfg_data,
    input wire cfg_ready,output wire fault_pulse,blocked,ghost,pressure_error,pressure_stale,
    output wire encoder_button,encoder_error,output wire [15:0] keys,output wire [31:0] fault_count
);
    control_surface surface(clk,rst,external_panic,col_n,row_low,enc_a,enc_b,enc_button_n,
        note_map,velocity,adc_valid,adc_raw,cal_low,cal_high,dead_zone,pressure_enable,
        adc_ready,pressure_gain,event_valid,event_kind,event_note,event_velocity,event_ready,
        cfg_valid,cfg_addr,cfg_data,cfg_ready,fault_pulse,blocked,ghost,pressure_error,
        pressure_stale,encoder_button,encoder_error,keys,fault_count);
endmodule

// Logical surface only: no unverified GPIO/ADC pin assignments are embedded here.
module control_surface #(parameter ROWS=4,COLS=4,ROW_CYCLES=2500,DB_FRAMES=8,
    parameter ENCODER_CYCLES=2500,ENCODER_AB=2,ENCODER_BUTTON=60,HAS_DIODES=0)(
    input wire clk,rst,external_panic,
    input wire [COLS-1:0] col_n,output wire [ROWS-1:0] row_low,
    input wire enc_a,enc_b,enc_button_n,
    input wire [ROWS*COLS*7-1:0] note_map,
    input wire [8:0] velocity,
    input wire adc_valid,input wire [11:0] adc_raw,cal_low,cal_high,dead_zone,
    input wire pressure_enable,output wire adc_ready,
    output wire [16:0] pressure_gain,
    output wire event_valid,output wire [1:0] event_kind,
    output wire [6:0] event_note,output wire [8:0] event_velocity,input wire event_ready,
    output reg cfg_valid,output wire [3:0] cfg_addr,output wire [31:0] cfg_data,input wire cfg_ready,
    output wire fault_pulse,blocked,ghost,pressure_error,pressure_stale,
    output wire encoder_button,encoder_error,
    output wire [ROWS*COLS-1:0] keys,output wire [31:0] fault_count
);
    wire changed,frame_valid,all_released,button_change,step_valid;
    wire signed [1:0] step;
    wire [16:0] filtered;
    wire [16:0] unused_normalized;
    wire unused_updated,unused_overflow;
    reg [16:0] knob_volume,sent_volume;
    reg [16:0] pending_volume;
    wire [16:0] stepped=step>0 ? (knob_volume>=61440 ? 17'd65536 : knob_volume+17'd4096) :
        (knob_volume<=4096 ? 17'd0 : knob_volume-17'd4096);
    matrix_scanner #(.ROWS(ROWS),.COLS(COLS),.ROW_CYCLES(ROW_CYCLES),
        .DEBOUNCE_FRAMES(DB_FRAMES),.HAS_DIODES(HAS_DIODES)) scanner(
        clk,rst,col_n,row_low,keys,changed,frame_valid,ghost,all_released);
    key_pipeline #(.KEYS(ROWS*COLS)) pipeline(clk,rst,external_panic,changed,ghost,all_released,
        keys,note_map,velocity,event_valid,event_kind,event_note,event_velocity,event_ready,
        fault_pulse,blocked,unused_overflow,fault_count);
    ec11_input #(.SAMPLE_CYCLES(ENCODER_CYCLES),.AB_SAMPLES(ENCODER_AB),.BUTTON_SAMPLES(ENCODER_BUTTON)) encoder(
        clk,rst,enc_a,enc_b,enc_button_n,step_valid,step,encoder_button,button_change,encoder_error);
    pressure_expression pressure(clk,rst,adc_valid,adc_raw,cal_low,cal_high,dead_zone,adc_ready,
        filtered,unused_normalized,unused_updated,pressure_error,pressure_stale);
    assign pressure_gain=pressure_enable ? filtered : 17'd65536;
    assign cfg_addr=0;
    assign cfg_data={15'd0,pending_volume};
    // Keep a queued cfg payload stable; later encoder steps coalesce into the next target.
    always @(posedge clk) begin
        if(rst) begin knob_volume<=65536;sent_volume<=65536;pending_volume<=65536;cfg_valid<=0;end
        else begin
            if(step_valid) knob_volume<=stepped;
            if(cfg_valid && cfg_ready) begin cfg_valid<=0;sent_volume<=pending_volume;end
            if(!cfg_valid && knob_volume!=sent_volume) begin cfg_valid<=1;pending_volume<=knob_volume;end
        end
    end
endmodule

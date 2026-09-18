// Integration boundary: lossless event FIFO, two config sources, real telemetry.
module system_engine #(parameter N=8,EVENT_DEPTH=16,SNAPSHOT_W=85+18*N)(
    input wire clk,rst,sample_ce,emergency,
    input wire event_valid,input wire [1:0] event_kind,input wire [6:0] event_note,event_value,
    input wire [8:0] event_velocity,output wire event_ready,
    input wire local_cfg_valid,input wire [3:0] local_cfg_addr,input wire [31:0] local_cfg_data,output wire local_cfg_ready,
    input wire host_cfg_valid,input wire [3:0] host_cfg_addr,input wire [31:0] host_cfg_data,output wire host_cfg_ready,
    input wire [16:0] pressure_gain,
    output wire cfg_ack,cfg_accepted,output wire [31:0] cfg_applied,output reg cfg_source_host,
    output wire signed [15:0] sample,output wire sample_valid,clipped,panic,
    output reg snapshot_valid,output reg [SNAPSHOT_W-1:0] snapshot_data,
    output wire wave_valid,output wire signed [15:0] wave_sample,output wire [31:0] wave_index,
    output wire [N-1:0] occupied,held,gated,output wire [16:0] gain
);
    wire queued_valid,core_ready,cv,cr,source_host,queue_ready,dispatch_valid;
    wire [24:0] queued_data;
    wire [24:0] dispatch_data;
    wire [35:0] config_data;
    wire [N-1:0] sost;
    wire [N*7-1:0] notes,pitches;
    wire [16:0] master_volume;
    wire sustain,sostenuto,meter_valid,meter_clip;
    wire [15:0] peak;
    wire [$clog2(EVENT_DEPTH+1)-1:0] unused_level;
    reg [31:0] sequence;
    stream_fifo #(.WIDTH(25),.DEPTH(EVENT_DEPTH)) queue(clk,rst,panic,event_valid,
        {event_kind,event_note,event_value,event_velocity},event_ready,queued_valid,queued_data,queue_ready,unused_level);
    // At 32 voices, register the asynchronous FIFO read before the allocator.
    // The 8/16 voice reference keeps its original event timing.
    generate if(N>=32)begin: event_stage
        reg full;reg [24:0] payload;
        assign queue_ready=!rst && !panic && (!full || core_ready);
        assign dispatch_valid=full && !rst && !panic;
        assign dispatch_data=payload;
        always @(posedge clk)begin
            if(rst || panic)begin full<=0;payload<=0;end
            else if(queue_ready)begin full<=queued_valid;if(queued_valid)payload<=queued_data;end
        end
    end else begin: direct_events
        assign queue_ready=core_ready;
        assign dispatch_valid=queued_valid;
        assign dispatch_data=queued_data;
    end endgenerate
    stream_arbiter2 #(.WIDTH(36)) configs(clk,rst,1'b0,
        local_cfg_valid,{local_cfg_addr,local_cfg_data},local_cfg_ready,
        host_cfg_valid,{host_cfg_addr,host_cfg_data},host_cfg_ready,
        cv,config_data,source_host,cr);
    system_core #(.N(N)) core(.clk(clk),.rst(rst),.sample_ce(sample_ce),.emergency(emergency),
        .event_valid(dispatch_valid),.event_kind(dispatch_data[24:23]),.event_note(dispatch_data[22:16]),
        .event_value(dispatch_data[15:9]),.event_velocity(dispatch_data[8:0]),.event_ready(core_ready),
        .cfg_valid(cv),.cfg_addr(config_data[35:32]),.cfg_data(config_data[31:0]),.pressure_gain(pressure_gain),
        .cfg_ready(cr),.cfg_ack(cfg_ack),.cfg_accepted(cfg_accepted),.cfg_applied(cfg_applied),
        .sample(sample),.sample_valid(sample_valid),.clipped(clipped),.panic(panic),
        .occupied(occupied),.held(held),.gated(gated),.sost_latched(sost),.notes(notes),.pitches(pitches),
        .voice_samples(),.envelopes(),.steps(),.gain(gain),.master_volume(master_volume),
        .sustain(sustain),.sostenuto(sostenuto),.stolen(),.ignored(),
        .meter_valid(meter_valid),.meter_peak(peak),.meter_sample(),.meter_clip(meter_clip));
    waveform_tap tap(clk,rst,sample_valid,sample,wave_valid,wave_sample,wave_index);
    always @(posedge clk) begin
        if(rst) begin cfg_source_host<=0;snapshot_valid<=0;snapshot_data<=0;sequence<=0;end
        else begin
            if(cv && cr) cfg_source_host<=source_host;
            snapshot_valid<=meter_valid;
            if(meter_valid) begin
                sequence<=sequence+1'b1;
                snapshot_data<={sequence,master_volume,gain,peak,meter_clip,sustain,sostenuto,
                    occupied,held,gated,sost,notes,pitches};
            end
        end
    end
endmodule

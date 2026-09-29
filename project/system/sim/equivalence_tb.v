`timescale 1ns/1ps
// Original full score and envelope durations; omit only idle sample clocks.
module equivalence_tb;
    localparam TOTAL=16*48077;
    reg clk=0,rst=1;reg [3:0] tick=0;
    wire ce=!rst && tick==0;
    wire ev,cv;wire [1:0] kind;wire [6:0] note,value;wire [8:0] velocity;wire [3:0] addr;wire [31:0] data;
    wire er,cr,ack,accepted,valid,old_valid,clip,old_clip;
    wire supported_cv=cv && (addr==0 || addr==4 || addr==5 || addr==6);
    wire signed [15:0] sample,old_sample;
    wire [7:0] occupied,held,gated;wire [16:0] gain;
    wire snap;wire [228:0] snapshot;wire wave_valid;wire signed [15:0] wave_sample;wire [31:0] wave_index;
    integer count=0,f,snaps=0,waves=0;
    always #10 clk=~clk;
    always @(posedge clk) if(rst) tick<=0;else tick<=tick+1'b1;
    baseline_demo demo(clk,rst,ce,ev,kind,note,value,velocity,cv,addr,data);
    baseline_core reference(.clk(clk),.rst(rst),.sample_ce(ce),.event_valid(ev),.event_kind(kind),.event_note(note),
        .event_value(value),.event_velocity(velocity),.cfg_valid(cv),.cfg_addr(addr),.cfg_data(data),
        .sample(old_sample),.sample_valid(old_valid),.clipped(old_clip),.event_ready(),.cfg_ready(),.cfg_ack(),.cfg_accepted(),.cfg_applied(),
        .occupied(),.held(),.gated(),.sost_latched(),.notes(),.pitches(),.voice_samples(),.envelopes(),.steps(),
        .stolen(),.ignored(),.gain(),.weight2(),.weight3(),.meter_valid(),.meter_peak(),.meter_sample(),.meter_clip());
    system_engine engine(.clk(clk),.rst(rst),.sample_ce(ce),.emergency(1'b0),.event_valid(ev),.event_kind(kind),.event_note(note),
        .event_value(value),.event_velocity(velocity),.event_ready(er),.local_cfg_valid(supported_cv),.local_cfg_addr(addr),.local_cfg_data(data),.local_cfg_ready(cr),
        .host_cfg_valid(1'b0),.host_cfg_addr(4'd0),.host_cfg_data(32'd0),.pressure_gain(17'd65536),.cfg_ack(ack),.cfg_accepted(accepted),
        .sample(sample),.sample_valid(valid),.clipped(clip),.occupied(occupied),.held(held),.gated(gated),.gain(gain),
        .snapshot_valid(snap),.snapshot_data(snapshot),.wave_valid(wave_valid),.wave_sample(wave_sample),.wave_index(wave_index),
        .host_cfg_ready(),.cfg_applied(),.cfg_source_host(),.panic());
    always @(posedge clk) if(!rst) begin
        if(ev && !er || supported_cv && !cr || ack && !accepted) $fatal(1,"Integration handshake");
        #1;
        if(valid!==old_valid) $fatal(1,"Baseline valid cadence changed");
        if(snap) begin
            if(snapshot[228:197]!==snaps) $fatal(1,"Snapshot sequence");snaps=snaps+1;
        end
        if(wave_valid) begin if(wave_index!==waves*48) $fatal(1,"Wave index");waves=waves+1;end
        if(valid) begin
            if(sample!==old_sample || clip!==old_clip) $fatal(1,"Reference mismatch sample=%0d new=%0d old=%0d",count,sample,old_sample);
            $fwrite(f,"%0d\n",sample);count=count+1;
            if(count==TOTAL) begin
                if(occupied || sample!=0 || snaps<700 || waves<15000) $fatal(1,"Render final state/telemetry");
                $fclose(f);$display("EQUIVALENCE_TB_PASS samples=%0d snapshots=%0d wave_samples=%0d",count,snaps,waves);$finish;
            end
        end
    end
    initial begin f=$fopen("system_samples.txt","w");repeat(5) @(negedge clk);rst=0;end
    initial begin #250000000;$fatal(1,"Equivalence timeout");end
endmodule

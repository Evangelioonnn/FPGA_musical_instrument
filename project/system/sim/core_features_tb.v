`timescale 1ns/1ps
module core_features_tb #(parameter N=32);
    reg clk=0,rst=1;reg [3:0] tick=0;wire ce=!rst && tick==0;
    reg ev=0,cv=0,emergency=0;reg [1:0] kind=0;reg [6:0] note=0,value=0;reg [3:0] addr=0;reg [31:0] data=0;
    wire ready,cr,ack,accepted,valid,clip,panic,stolen,ignored;
    wire [N-1:0] occupied,held,gated,sost;wire [N*7-1:0] notes,pitches;
    wire [N*16-1:0] samples,envs;wire [N*32-1:0] steps;
    wire signed [15:0] sample;wire [31:0] a4_step;
    integer i,count=0,steals=0,render;
    reg [31:0] before_phase;
    always #10 clk=~clk;
    always @(posedge clk)if(rst)tick<=0;else tick<=tick+1'b1;
    note_table reference_step(7'd69,a4_step);
    system_core #(.N(N)) dut(.clk(clk),.rst(rst),.sample_ce(ce),.emergency(emergency),.event_valid(ev),.event_kind(kind),
        .event_note(note),.event_value(value),.event_velocity(9'd256),.event_ready(ready),.cfg_valid(cv),.cfg_addr(addr),.cfg_data(data),
        .pressure_gain(17'd65536),.cfg_ready(cr),.cfg_ack(ack),.cfg_accepted(accepted),.cfg_applied(),.sample(sample),.sample_valid(valid),
        .clipped(clip),.panic(panic),.occupied(occupied),.held(held),.gated(gated),.sost_latched(sost),.notes(notes),.pitches(pitches),
        .voice_samples(samples),.envelopes(envs),.steps(steps),.gain(),.master_volume(),.sustain(),.sostenuto(),.stolen(stolen),.ignored(ignored),
        .meter_valid(),.meter_peak(),.meter_sample(),.meter_clip());
    always @(posedge clk) if(!rst) begin
        if(stolen) steals=steals+1;
        if(valid)begin
            if(clip || ^sample===1'bx)$fatal(1,"Capacity sample invalid");
            $fwrite(render,"%0d\n",sample);count=count+1;
        end
    end
    task event_send;input [1:0] k;input [6:0] id,target;begin
        @(negedge clk);ev=1;kind=k;note=id;value=target;
        @(negedge clk);while(!ready)@(negedge clk);ev=0;
        repeat(3)@(negedge clk);
    end endtask
    task send_config;input [3:0] a;input [31:0] d;begin
        @(negedge clk);cv=1;addr=a;data=d;@(negedge clk);cv=0;
        if(!ack || !accepted)$fatal(1,"Feature config rejected");repeat(3)@(negedge clk);
    end endtask
    task samples_wait;input integer amount;integer end_at;begin
        end_at=count+amount;wait(count>=end_at);@(negedge clk);
    end endtask
    initial begin
        if(N==16) render=$fopen("capacity16_samples.txt","w");else render=$fopen("capacity32_samples.txt","w");
        repeat(5)@(negedge clk);rst=0;
        for(i=0;i<N;i=i+1)event_send(0,48+i,0);
        samples_wait(22000);
        if(occupied!=={N{1'b1}} || held!=={N{1'b1}} || steals)$fatal(1,"Not all independent voices active");
        for(i=0;i<N;i=i+1)if(notes[i*7 +: 7]!==48+i || envs[i*16 +:16]!=32768)$fatal(1,"Capacity pitch/envelope");
        // Retune must reach the real phase accumulator, preserving identity/envelope.
        event_send(2,48,69);
        if(notes[6:0]!=48 || pitches[6:0]!=69 || envs[15:0]!=32768 || dut.voices[0].voice.original.step_hold!==a4_step)
            $fatal(1,"Retune did not reach oscillator");
        @(negedge clk);wait(ce);before_phase=dut.voices[0].voice.original.phase;@(posedge clk);#1;
        if(dut.voices[0].voice.original.phase-before_phase!==a4_step)$fatal(1,"Real phase increment unchanged");
        event_send(0,90,0);if(steals!=1)$fatal(1,"Capacity stealing");
        send_config(4,1);
        for(i=1;i<N;i=i+1)event_send(1,48+i,0);
        event_send(1,90,0);samples_wait(4);
        if(held!=0 || gated!=={N{1'b1}})$fatal(1,"Capacity sustain");
        send_config(6,1);samples_wait(12000);
        if(occupied || held || gated || sample || envs)$fatal(1,"Panic left stuck voices");
        $fclose(render);$display("CORE_FEATURES_TB_PASS N=%0d samples=%0d retune=1 steal=1 sustain=1 panic_silent=1",N,count);$finish;
    end
    initial begin #20000000;$fatal(1,"Capacity test timeout");end
endmodule

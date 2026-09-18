`timescale 1ns/1ps
module core_tb;
    parameter N=8;
    reg clk=0,rst=1,ev=0,cv=0;
    reg [3:0] tick=0,addr=0;
    wire ce=!rst && tick==0;
    reg [1:0] kind=0;
    reg [6:0] note=0,value=0;
    reg [8:0] velocity=256;
    reg [31:0] data=0;
    wire ready,cr,ack,accepted,valid,clip,stolen,ignored;
    wire [31:0] applied;
    wire signed [15:0] sample;
    wire [N-1:0] occ,held,gate,sost;
    wire [N*7-1:0] notes,pitches;
    wire [N*16-1:0] samples,envs;
    wire [N*32-1:0] steps;
    integer i,accepted_events=0,produced=0;
    always #10 clk=~clk;
    always @(posedge clk) if(rst) tick<=0;else tick<=tick+1'b1;
    expression_core #(.N(N)) core(.clk(clk),.rst(rst),.sample_ce(ce),.event_valid(ev),.event_kind(kind),
        .event_note(note),.event_value(value),.event_velocity(velocity),.event_ready(ready),
        .cfg_valid(cv),.cfg_addr(addr),.cfg_data(data),.cfg_ready(cr),.cfg_ack(ack),.cfg_accepted(accepted),.cfg_applied(applied),
        .sample(sample),.sample_valid(valid),.clipped(clip),.occupied(occ),.held(held),.gated(gate),.sost_latched(sost),
        .notes(notes),.pitches(pitches),.voice_samples(samples),.envelopes(envs),.steps(steps),.stolen(stolen),.ignored(ignored),
        .gain(),.weight2(),.weight3(),.meter_valid(),.meter_peak(),.meter_sample(),.meter_clip());
    always @(posedge clk) if(!rst) begin
        if(ev && ready) accepted_events=accepted_events+1;
        if(valid) begin
            produced=produced+1;
            if(sample>511 || sample < -512 || clip || ^sample===1'bx) $fatal(1,"Core sample range");
        end
    end
    task push;
        input [1:0] k;input [6:0] n,t;input [8:0] vel;
        begin
            @(negedge clk);if(!ready) $fatal(1,"Unexpected busy");ev=1;kind=k;note=n;value=t;velocity=vel;
        end
    endtask
    task settle;
        begin @(negedge clk);ev=0;repeat(160) @(negedge clk);end
    endtask
    task write_cfg;
        input [3:0] ad;input [31:0] val;
        begin
            @(negedge clk);cv=1;addr=ad;data=val;
            @(negedge clk);if(!ack || !accepted || applied!=val) $fatal(1,"Config rejected");cv=0;
            @(negedge clk);
        end
    endtask
    initial begin
        repeat(5) @(negedge clk);rst=0;
        write_cfg(7,65535);write_cfg(8,65535);write_cfg(10,65535);
        for(i=55;i<55+N;i=i+1) push(0,i,0,256);
        settle;if(held!={N{1'b1}} || gate!={N{1'b1}} || occ!={N{1'b1}}) $fatal(1,"Eight voices");
        push(0,90,0,128);push(1,55,0,0);settle;
        if(notes[6:0]!=90 || held!={N{1'b1}}) $fatal(1,"Ninth note stale off");
        write_cfg(4,1);
        for(i=56;i<55+N;i=i+1) push(1,i,0,0);
        push(1,90,0,0);settle;
        if(held || gate!={N{1'b1}} || occ!={N{1'b1}}) $fatal(1,"Sustain failed");
        write_cfg(4,0);settle;if(occ || sample || envs) $fatal(1,"Pedal up hung notes");
        push(0,60,0,256);settle;write_cfg(5,1);
        push(0,67,0,256);settle;push(1,60,0,0);push(1,67,0,0);settle;
        if(held || occ!=1 || gate!=1 || sost!=1) $fatal(1,"Selective sustain");
        push(2,60,72,0);settle;
        if(notes[6:0]!=60 || pitches[6:0]!=72) $fatal(1,"Retune changed identity");
        write_cfg(5,0);settle;if(occ || sample) $fatal(1,"Selective pedal release");
        write_cfg(4,1);write_cfg(5,1);
        push(0,60,0,256);push(0,64,0,256);settle;
        write_cfg(6,1);settle;if(occ || gate || held || sample) $fatal(1,"Panic with pedals held");
        write_cfg(4,0);write_cfg(5,0);
        push(0,69,0,256);push(0,69,0,0);settle;if(occ || sample) $fatal(1,"Velocity zero off");
        // Pending events must stall during the registered panic interval.
        write_cfg(6,1);settle;
        rst=1;@(negedge clk);rst=0;settle;
        if(occ || sample) $fatal(1,"Reset state");
        $display("CORE_TB_PASS N=%0d accepted_events=%0d output_samples=%0d",N,accepted_events,produced);$finish;
    end
endmodule

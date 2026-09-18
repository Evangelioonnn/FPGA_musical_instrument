`timescale 1ns/1ps
// Keep real audio sample counts and ADSR. Only idle system clocks are omitted.
module baseline_render_tb;
    localparam SLOT=48077,TOTAL=16*SLOT;
    reg clk=0,rst=1;
    reg [3:0] tick=0;
    wire ce=!rst && tick==0;
    wire ev,cv,er,cr,ack,accepted,valid,clip,stolen,ignored;
    wire [1:0] kind;
    wire [6:0] note,value;
    wire [8:0] velocity;
    wire [3:0] addr;
    wire [31:0] data,applied;
    wire signed [15:0] sample;
    wire [7:0] occ,held,gate,sost;
    wire [55:0] notes;
    wire [127:0] samples,envs;
    wire [16:0] gain;
    integer f,count=0,events=0,commands=0,age=-1,i,pop,max_pop=0,total;
    integer expected,ordinary_checks=0,selective_checks=0,independent_checks=0;
    reg signed [63:0] product;
    always #10 clk=~clk;
    always @(posedge clk) if(rst) tick<=0;else tick<=tick+1'b1;
    baseline_demo demo(clk,rst,ce,ev,kind,note,value,velocity,cv,addr,data);
    baseline_core core(.clk(clk),.rst(rst),.sample_ce(ce),.event_valid(ev),.event_kind(kind),
        .event_note(note),.event_value(value),.event_velocity(velocity),.event_ready(er),
        .cfg_valid(cv),.cfg_addr(addr),.cfg_data(data),.cfg_ready(cr),.cfg_ack(ack),
        .cfg_accepted(accepted),.cfg_applied(applied),.sample(sample),.sample_valid(valid),
        .clipped(clip),.occupied(occ),.held(held),.gated(gate),.sost_latched(sost),
        .notes(notes),.pitches(),.voice_samples(samples),.envelopes(envs),.steps(),
        .stolen(stolen),.ignored(ignored),.gain(gain),.weight2(),.weight3(),
        .meter_valid(),.meter_peak(),.meter_sample(),.meter_clip());
    always @(posedge clk) if(!rst) begin
        if(ce) age=0;else if(age>=0) age=age+1;
        if(ev) begin
            if(!er) $fatal(1,"Dropped event");events=events+1;
            if(kind==0 && demo.slot>=5 && demo.slot<=7 && (occ || envs))
                $fatal(1,"Velocity comparison began before prior release finished");
        end
        if(cv) begin if(!cr) $fatal(1,"Dropped config");commands=commands+1;end
        if(core.valids!=={8{core.valids[0]}}) $fatal(1,"Voice valid alignment");
        if(core.valids[0]) begin
            total=0;
            for(i=0;i<8;i=i+1) total=total+$signed(samples[i*16 +: 16]);
            product=total;product=product*gain;
            expected=product>=0 ? product/65536 : -((-product+65535)/65536);
        end
        #1;
        if(ack && !accepted) $fatal(1,"Rejected config");
        if(stolen || ignored) $fatal(1,"Demo stole a tail or lost a note-off at sample=%0d",count);
        if(valid) begin
            if(age!=7 || clip || ^sample===1'bx || sample>4096 || sample < -4096)
                $fatal(1,"Render pipeline/range age=%0d sample=%0d",age,sample);
            if($signed(sample)!==expected) $fatal(1,"Full core mix mismatch");
            pop=0;for(i=0;i<8;i=i+1) pop=pop+occ[i];
            if(pop>max_pop) max_pop=pop;
            // Keys are up, but ordinary sustain must keep the chord gated.
            if(count>8*SLOT+SLOT*7/10 && count<8*SLOT+SLOT*8/10) begin
                if(held!=0 || gate!=8'h07) $fatal(1,"Ordinary sustain failed");
                ordinary_checks=ordinary_checks+1;
            end
            // Only the original triad is captured by sostenuto.
            if(count>10*SLOT+SLOT*3/10 && count<10*SLOT+SLOT*39/100) begin
                if(held!=0 || gate!=8'h07 || sost!=8'h07) $fatal(1,"Selective sustain capture failed");
                selective_checks=selective_checks+1;
            end
            // A4 has been released while the captured triad is still gated.
            if(count>10*SLOT+SLOT*72/100 && count<10*SLOT+SLOT*8/10) begin
                if(held!=0 || gate!=8'h07 || sost!=8'h07) $fatal(1,"New note incorrectly sustained");
                independent_checks=independent_checks+1;
            end
            $fwrite(f,"%0d\n",sample);count=count+1;
            if(count==TOTAL) begin
                if(occ || held || gate || sost || sample || envs) $fatal(1,"Final release not silent");
                if(events!=48 || commands!=17 || max_pop!=8 || ordinary_checks<4000 ||
                    selective_checks<4000 || independent_checks<3000) $fatal(1,"Render coverage");
                $fclose(f);
                $display("BASELINE_RENDER_TB_PASS samples=%0d events=%0d commands=%0d voices=%0d sustain_checks=%0d sostenuto_checks=%0d new_note_checks=%0d",
                    count,events,commands,max_pop,ordinary_checks,selective_checks,independent_checks);$finish;
            end
        end
    end
    initial begin
        f=$fopen("baseline_samples.txt","w");if(!f) $fatal(1,"Render file open");
        repeat(5) @(negedge clk);rst=0;
    end
    initial begin #250000000; $fatal(1,"Render timeout");end
endmodule

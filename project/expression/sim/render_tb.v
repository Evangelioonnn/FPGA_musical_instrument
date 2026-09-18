`timescale 1ns/1ps
module render_tb;
    localparam SLOT=48077,TOTAL=24*SLOT;
    reg clk=0,rst=1;
    reg [3:0] tick=0;
    wire ce=!rst && tick==0;
    wire ev,cv,er,cr,ack,accept,valid,clip;
    wire [1:0] kind;
    wire [6:0] note,value;
    wire [8:0] velocity;
    wire [3:0] addr;
    wire [31:0] data,applied;
    wire signed [15:0] sample;
    wire [7:0] occ,held,gate,sost;
    wire [127:0] samples,envs;
    wire [255:0] steps;
    wire [16:0] gain;
    wire [14:0] w2,w3;
    integer f,count=0,age=-1,commands=0,events=0,i;
    always #10 clk=~clk;
    always @(posedge clk) if(rst) tick<=0;else tick<=tick+1'b1;
    expression_demo demo(clk,rst,ce,ev,kind,note,value,velocity,cv,addr,data);
    expression_core core(.clk(clk),.rst(rst),.sample_ce(ce),.event_valid(ev),.event_kind(kind),
        .event_note(note),.event_value(value),.event_velocity(velocity),.event_ready(er),
        .cfg_valid(cv),.cfg_addr(addr),.cfg_data(data),.cfg_ready(cr),.cfg_ack(ack),.cfg_accepted(accept),.cfg_applied(applied),
        .sample(sample),.sample_valid(valid),.clipped(clip),.occupied(occ),.held(held),.gated(gate),.sost_latched(sost),
        .voice_samples(samples),.envelopes(envs),.steps(steps),.gain(gain),.weight2(w2),.weight3(w3),
        .notes(),.pitches(),.stolen(),.ignored(),.meter_valid(),.meter_peak(),.meter_sample(),.meter_clip());
    always @(posedge clk) begin
        if(!rst) begin
            if(ce) age=0;else if(age>=0) age=age+1;
            if(ev) begin if(!er) $fatal(1,"Demo lost note event");events=events+1;end
            if(cv) commands=commands+1;
            #1;
            if(ack && !accept) $fatal(1,"Demo rejected parameter");
            if(valid) begin
                if(age!=9 || clip || ^sample===1'bx || sample>511 || sample < -512) $fatal(1,"Pipeline/range");
                $fwrite(f,"%0d %0d %0d %0d %0d %0d %0d %0d %0d %0d",sample,gain,w2,w3,occ,held,gate,sost,steps[31:0],envs[15:0]);
                for(i=0;i<8;i=i+1) $fwrite(f," %0d",$signed(samples[i*16 +: 16]));
                $fwrite(f,"\n");count=count+1;
                if(count==TOTAL) begin
                    if(occ || held || sample || envs) $fatal(1,"Final silence");
                    $fclose(f);$display("RENDER_TB_PASS samples=%0d events=%0d commands=%0d",count,events,commands);$finish;
                end
            end
        end
    end
    initial begin f=$fopen("expression_samples.txt","w");repeat(5) @(negedge clk);rst=0;end
    initial begin #450000000; $fatal(1,"Render timeout");end
endmodule

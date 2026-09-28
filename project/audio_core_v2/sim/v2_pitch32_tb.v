`timescale 1ns/1ps
module v2_pitch32_tb;
    reg clk=0; always #10 clk=~clk;
    reg rst=1,ce=0,event_valid=0;
    reg [31:0] token=0;
    reg [6:0] note=36;
    reg [2:0] preset=0;
    wire ready,accepted,rejected,valid,clip,deadline;
    wire [31:0] occupied,held;
    wire [223:0] notes;
    wire [95:0] presets;
    wire [1023:0] tokens;
    audio_v2_bank #(.N(32),.PLUCK_N(12)) dut(
        .clk(clk),.rst(rst),.sample_ce(ce),.event_valid(event_valid),.event_ready(ready),
        .event_off(1'b0),.event_token(token),.event_note(note),.event_timbre(preset),
        .pedal(1'b0),.sostenuto(1'b0),.reference_release(16'd3),.glide_index(3'd0),
        .lead_attack_index(2'd2),.bend_factor(17'd65536),.lead_bend_factor(17'd65536),
        .envelope_override(1'b1),.custom_hold(1'b1),.adsr_attack(16'd65535),
        .adsr_decay(16'd0),.adsr_sustain(16'd65535),.adsr_release(16'd3),
        .coeff0(9'd256),.coeff1(9'd64),.coeff2(9'd32),.coeff3(9'd16),
        .accepted(accepted),.rejected(rejected),.occupied(occupied),.held(held),
        .notes_snapshot(notes),.presets_snapshot(presets),.tokens_snapshot(tokens),
        .out_valid(valid),.clipped(clip),.deadline_missed(deadline));
    integer tick=0,frames=0,i,j,index,comparisons=0;
    reg [31:0] model_mask=0;
    reg [31:0] model_phase[0:31],model_step[0:31];
    reg [2:0] model_preset[0:31];
    real frequency;
    always @(negedge clk) begin
        if(rst) begin tick=0;ce=0;end
        else begin ce=tick==1039;tick=(tick+1)%1040;end
    end
    always @(posedge clk) begin
        #1;
        if(!rst) begin
            if(clip || deadline || rejected) $fatal(1,"32-pitch fault");
            if(ce) for(j=0;j<32;j=j+1)
                if(model_mask[j]) model_phase[j]=model_phase[j]+model_step[j];
            if(accepted) begin
                index=token-100;
                if(index<0 || index>31 || model_mask[index]) $fatal(1,"strike identity");
                model_mask[index]=1;model_phase[index]=0;model_preset[index]=preset;
            end
            if(valid) begin
                frames=frames+1;
                if(occupied!==model_mask || held!==model_mask) $fatal(1,"32-pitch allocation");
                for(j=0;j<32;j=j+1) if(model_mask[j]) begin
                    if(notes[j*7+:7]!==36+j || tokens[j*32+:32]!==100+j ||
                       presets[j*3+:3]!==model_preset[j]) $fatal(1,"32-pitch metadata");
                    if(dut.phases[j*32+:32]!==model_phase[j]) begin
                        $display("slot=%0d frame=%0d expected=%h actual=%h",j,frames,
                            model_phase[j],dut.phases[j*32+:32]);
                        $fatal(1,"independent phase recurrence");
                    end
                    comparisons=comparisons+1;
                end
            end
        end
    end
    task strike;
        input integer voice;
        begin
            @(negedge clk);#2;
            while(!ready) begin @(negedge clk);#2;end
            token=100+voice;note=36+voice;
            case(voice%4) 0:preset=0;1:preset=3;2:preset=4;3:preset=5;endcase
            event_valid=1;@(negedge clk);#2;event_valid=0;
            while(!accepted) begin @(negedge clk);#2;end
        end
    endtask
    initial begin
        // Equal temperament and Fs independently derive all expected increments.
        for(i=0;i<32;i=i+1) begin
            frequency=440.0*(2.0 ** ((36+i-69)/12.0));
            model_step[i]=$rtoi(frequency*4294967296.0/(50000000.0/1040.0)+0.5);
            model_phase[i]=0;model_preset[i]=0;
        end
        repeat(10) @(negedge clk);#2;rst=0;
        for(i=0;i<32;i=i+1) strike(i);
        if(model_mask!==32'hffffffff) $fatal(1,"missing voices");
        repeat(1200) begin @(negedge clk);while(!valid) @(negedge clk);end
        $display("V2_PITCH32_TB_PASS MIDI36..67, four mixed harmonic presets, independent equal-temperament phase model, comparisons=%0d frames=%0d",comparisons,frames);
        $finish;
    end
    initial begin #50000000;$fatal(1,"32-pitch timeout");end
endmodule

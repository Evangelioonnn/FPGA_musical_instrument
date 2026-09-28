`timescale 1ns/1ps
module poly_spectrum_tb;
    reg clk=0;always #10 clk=~clk;
    reg rst=1,ce=0,ev=0;
    reg [31:0] token=0;
    reg [6:0] note=48;
    wire ready,valid,clip,deadline;
    wire signed [15:0] sample;
    wire [31:0] occupied,held,gated;
    piano_poly_core #(.N(32),.OUTPUT_SHIFT(2)) dut(
        .clk(clk),.rst(rst),.sample_ce(ce),.event_valid(ev),.event_ready(ready),
        .event_off(1'b0),.event_token(token),.event_note(note),
        .attack_step(16'd68),.decay_step(16'd6),.sustain_level(16'd32768),
        .release_step(16'd3),.sustain(1'b0),.sostenuto(1'b0),
        .occupied(occupied),.held(held),.gated(gated),
        .out_valid(valid),.out_sample(sample),.clipped(clip),.deadline_missed(deadline));
    integer i,j,k,fd,voices_fd;
    integer frames_written=0,peak=0,latency,max_latency=0;
    task frame;
        input write_pcm;
        begin
            ce=1;@(negedge clk);ce=0;latency=1;
            while(!valid && latency<520) begin @(negedge clk);latency=latency+1;end
            if(!valid || clip || deadline || (^sample)===1'bx)$fatal;
            if(latency>max_latency)max_latency=latency;
            if(write_pcm) begin
                $fwrite(fd,"%0d\n",sample);frames_written=frames_written+1;
                if(sample<0 && -sample>peak)peak=-sample;
                if(sample>=0 && sample>peak)peak=sample;
            end
            repeat(520-latency) @(negedge clk);
        end
    endtask
    initial begin
        fd=$fopen("poly_spectrum32_pcm.txt","w");
        voices_fd=$fopen("poly_spectrum32_voices.txt","w");
        repeat(5) @(negedge clk);rst=0;
        for(i=0;i<32;i=i+1) begin
            while(!ready)@(negedge clk);
            ev=1;token=i+1;note=48+i;@(negedge clk);ev=0;
            repeat(35) @(negedge clk);
            if(dut.rejected_count!=0 || dut.unmatched_off_count!=0)$fatal;
        end
        for(k=0;k<7000;k=k+1)frame(0);
        if(occupied!==32'hffffffff || held!==32'hffffffff || gated!==32'hffffffff)$fatal;
        for(i=0;i<32;i=i+1) begin
            if(dut.tokens[i]!=i+1 || dut.notes[i]!=48+i || dut.steps[i]==0 ||
                dut.levels[i]==0 || dut.env_states[i]!=3)$fatal;
            for(j=0;j<i;j=j+1)
                if(dut.tokens[i]==dut.tokens[j] || dut.steps[i]==dut.steps[j])$fatal;
            $fwrite(voices_fd,"%0d %0d %0d %0d %0d %h\n",i,dut.notes[i],
                dut.tokens[i],dut.steps[i],dut.levels[i],dut.phases[i]);
        end
        for(k=0;k<32768;k=k+1)frame(1);
        if(occupied!==32'hffffffff || held!==32'hffffffff || gated!==32'hffffffff)$fatal;
        $fclose(fd);$fclose(voices_fd);
        $display("POLY_SPECTRUM_TB_PASS independent=32 MIDI48..79 frames=%0d warmup=7000 gain=1/4 cadence=520 latency=%0d peak=%0d",frames_written,max_latency,peak);$finish;
    end
endmodule

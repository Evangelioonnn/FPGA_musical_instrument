`timescale 1ns/1ps
module transport_checker #(parameter MODE=0)(
    input wire clk,a,b,output reg [31:0] frames=0,events=0
);
    wire bck,ws,din,pa;
    knob_audio_top #(.MODE(MODE)) dut(clk,a,b,bck,ws,din,pa);
    reg [15:0] bits=0;
    reg signed [15:0] expected=0,right=0;
    integer clocks=0,previous_publish=0,cycle=0,frame_start=0;
    time last_edge=0;
    always @(posedge clk)if(!dut.rst)begin
        cycle=cycle+1;
        if(dut.step_valid)events=events+1;
        if(dut.sample_ce)begin
            if(frame_start!=0 && cycle-frame_start!=1040)$fatal(1,"Audio cadence changed");
            frame_start=cycle;
        end
        if(dut.final_valid)begin
            if(cycle-frame_start>100)$fatal(1,"Audio sample missed internal deadline");
            if(previous_publish==frame_start)$fatal(1,"Two outputs per sample request");
            previous_publish=frame_start;
        end
        if(dut.engine.deadline_missed || dut.engine.bank_clip || dut.engine.rejected_count || dut.engine.queue_overflows)
            $fatal(1,"Transport source fault mode=%0d",MODE);
    end
    always @(bck)if($time>1000)begin
        if(last_edge && $time-last_edge!=260)$fatal(1,"BCK not 260 ns half period");
        last_edge=$time;
    end
    always @(din or ws)if($time>1000 && bck!==0)$fatal(1,"Serial setup transition at high BCK");
    always @(posedge bck)begin bits={bits[14:0],din};clocks=clocks+1;end
    always @(ws)if($time>1000)begin
        if(clocks!=20)$fatal(1,"Slot not 20 serial clocks");
        if(ws)right=bits;
        else begin
            if($signed(bits)!==expected || right!==expected)
                $fatal(1,"Serialized PCM mismatch mode=%0d frame=%0d got=%0d expected=%0d",MODE,frames,$signed(bits),expected);
            expected=dut.final_sample;frames=frames+1;
        end
        clocks=0;
    end
endmodule

module transport_tb;
    reg clk=0,a=1,b=1;
    wire [31:0] frames[0:4],events[0:4];integer i;
    always #10 clk=~clk;
    genvar g;
    generate for(g=0;g<5;g=g+1)begin: modes
        transport_checker #(.MODE(g)) check(clk,a,b,frames[g],events[g]);
    end endgenerate
    task hold;input [1:0] ab;begin @(negedge clk);{a,b}=ab;#300000;end endtask
    task up;begin hold(2'b10);hold(2'b00);hold(2'b01);hold(2'b11);end endtask
    task down;begin hold(2'b01);hold(2'b00);hold(2'b10);hold(2'b11);end endtask
    initial begin
        #1000000;
        up;up;up;down;down;down;
        // Sub-debounce glitch must not trigger any of the five clients.
        @(negedge clk);b=0;#20000;@(negedge clk);b=1;#1000000;
        for(i=0;i<5;i=i+1)if(events[i]!=6)$fatal(1,"Wrong real detent count mode=%0d count=%0d",i,events[i]);
        // Another selection event while the existing voice is sounding. This
        // short serial run does not reach the next 0.5 s timbre note; multi_tb
        // and render_tb cover new pluck/FM notes and retained old tails.
        up;
        #12000000;
        for(i=0;i<5;i=i+1)if(frames[i]<900 || events[i]!=7)$fatal(1,"Transport coverage short");
        $display("TRANSPORT_TB_PASS modes=5 frames_each=%0d detents=7 real_50MHz=1 serial_pcm_exact=1",frames[0]);$finish;
    end
    initial begin #50000000;$fatal(1,"Transport timeout");end
endmodule

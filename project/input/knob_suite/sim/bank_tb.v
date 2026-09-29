`timescale 1ns/1ps
module bank_tb;
    reg clk=0,rst=1;reg [6:0] tick=0;wire ce=!rst && tick==0;
    reg valid=0;wire ready;
    reg [6:0] note=60;reg [1:0] tone=0;reg [23:0] gate=31250;
    reg sustain=0,sostenuto=0,release_all=0;
    wire accepted,rejected,ov,clip,deadline;wire [3:0] slot;
    wire [31:0] rejects;wire [15:0] occupied,gated,captured;
    wire signed [15:0] sample,reference_sample;
    wire rv;wire [2:0] rs;wire [15:0] re;wire [31:0] phase_step;
    reg ref_on=0,ref_off=0,compare_sum=0;
    integer accepts=0,denials=0,frames=0,k,expected;
    always #10 clk=~clk;
    always @(posedge clk)if(rst)tick<=0;else tick<=tick+1'b1;
    knob_bank dut(clk,rst,ce,valid,ready,note,tone,gate,16'd68,16'd6,16'd32768,16'd3,
        sustain,sostenuto,release_all,accepted,rejected,slot,rejects,occupied,gated,captured,
        ov,sample,clip,deadline);
    note_table table1(7'd60,phase_step);
    synth_voice oracle(clk,rst,ce,ref_on,ref_off,1'b0,phase_step,reference_sample,rv,re,rs);
    always @(posedge clk) if(!rst) begin
        if(accepted)accepts=accepts+1;
        if(rejected)denials=denials+1;
        if(deadline || clip)$fatal(1,"Mixer deadline/clip");
        if(ov) begin
            frames=frames+1;
            if(^sample===1'bx)$fatal(1,"Unknown mixer output");
            // Independent full-width integer sum of 16 identical, aligned
            // isolated source notes. This catches dynamic 1/N gain as well.
            expected=$signed(reference_sample)*16;
            if(compare_sum && sample!==expected)
                $fatal(1,"16 coherent sources != 16*solo: frame=%0d actual=%0d expected=%0d",frames,sample,expected);
        end
    end
    task send;input [6:0] n;begin
        @(negedge clk);valid=1;note=n;
        @(negedge clk);while(!ready)@(negedge clk);valid=0;
    end endtask
    task wait_frames;input integer n;integer target;begin target=frames+n;wait(frames>=target);@(negedge clk);end endtask
    task panic;begin @(negedge clk);release_all=1;@(negedge clk);release_all=0;end endtask
    initial begin
        repeat(5)@(negedge clk);rst=0;
        wait(ce);@(negedge clk);ref_on=1;@(negedge clk);ref_on=0;
        for(k=0;k<16;k=k+1)send(60);
        repeat(10)@(negedge clk);
        if(occupied!=16'hffff || accepts!=16)$fatal(1,"Same-pitch instances were merged");
        // Enable after the first common audio sample, so pipeline reset values
        // do not become part of the equivalence claim.
        wait_frames(2);compare_sum=1;
        send(67);repeat(5)@(negedge clk);
        if(denials!=1 || rejects!=1 || occupied!=16'hffff)$fatal(1,"Full-bank rejection missing");
        wait_frames(100);
        // All 16 gate counters start in the same sample interval as oracle.
        wait(dut.gated==0);@(negedge clk);ref_off=1;@(negedge clk);ref_off=0;
        wait_frames(11000);
        if(occupied || sample || reference_sample)$fatal(1,"Full tails did not finish");
        compare_sum=0;
        // A previous instance must not release a newly allocated same pitch.
        gate=100;send(60);wait_frames(50);send(60);wait_frames(52);
        if(gated!=16'h0002 || occupied[1:0]!=2'b11)$fatal(1,"Independent same-note off failed");
        panic;wait_frames(4000);if(occupied)$fatal(1,"All-release failed");
        gate=40;sustain=1;send(64);wait_frames(100);
        if(gated!=0 || !occupied)$fatal(1,"Sustain did not hold released key");
        sustain=0;wait_frames(3000);if(occupied)$fatal(1,"Sustain release stuck");
        gate=100;send(60);wait_frames(10);sostenuto=1;wait_frames(2);send(67);
        wait_frames(150);
        if(captured!=1 || gated!=0)$fatal(1,"Sostenuto captured later note");
        wait_frames(3000);if(occupied!=1)$fatal(1,"Uncaptured voice held");
        sostenuto=0;wait_frames(22000);if(occupied)$fatal(1,"Sostenuto release stuck");
        sustain=1;sostenuto=1;send(60);wait_frames(20);panic;wait_frames(2000);
        if(occupied || sample)$fatal(1,"All-release did not override pedals");
        sustain=0;sostenuto=0;
        tone=3;send(60);tone=0;send(47);gate=0;send(60);repeat(10)@(negedge clk);
        if(denials!=4)$fatal(1,"Invalid input not rejected");
        $display("BANK_TB_PASS frames=%0d accepted=%0d rejected=%0d same_note_independent=1 coherent_sum16=1 pedals=1",frames,accepts,denials);
        $finish;
    end
    initial begin #300000000;$fatal(1,"Bank timeout");end
endmodule

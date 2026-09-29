`timescale 1ns/1ps
module multi_tb;
    reg clk=0,rst=1;reg [6:0] tick=0;wire ce=!rst && tick==0;
    reg main_valid=0;wire main_ready;
    reg [7:0] solo_valid=0;
    reg [6:0] note=60;reg [1:0] tone=0;
    wire accepted,rejected,ov,clip,deadline;wire [2:0] slot;
    wire [31:0] rejects;wire [7:0] occupied,gated,captured;
    wire signed [15:0] sample;
    wire [7:0] solo_ready,solo_output_valid;
    wire signed [15:0] solos[0:7];
    integer frames=0,i,j,sum,accepted_count=0,nonzero=0;
    always #10 clk=~clk;
    always @(posedge clk)if(rst)tick<=0;else tick<=tick+1'b1;
    knob_bank #(.N(8),.MULTI(1)) dut(clk,rst,ce,main_valid,main_ready,note,tone,24'd9000,
        16'd68,16'd6,16'd32768,16'd3,1'b0,1'b0,1'b0,accepted,rejected,slot,rejects,
        occupied,gated,captured,ov,sample,clip,deadline);
    genvar g;
    generate for(g=0;g<8;g=g+1)begin: reference
        knob_bank #(.N(1),.MULTI(1)) solo(.clk(clk),.rst(rst),.sample_ce(ce),
            .strike_valid(solo_valid[g]),.strike_ready(solo_ready[g]),.note(note),.timbre(tone),
            .gate_samples(24'd9000),.attack(16'd68),.decay(16'd6),.sustain_level(16'd32768),.release_step(16'd3),
            .pedal_sustain(1'b0),.pedal_sostenuto(1'b0),.all_release(1'b0),
            .accepted(),.rejected(),.accepted_slot(),.rejected_count(),
            .occupied(),.gated(),.sost_captured(),.clipped(),.deadline_missed(),
            .out_valid(solo_output_valid[g]),.out_sample(solos[g]));
    end endgenerate
    // Isolated sources are evaluated separately and summed as signed integers.
    // Same note, different algorithms and staggered starts exercise old tails
    // through multiple global selection changes and simultaneous initialization.
    always @(posedge clk) if(!rst)begin
        if(accepted)accepted_count=accepted_count+1;
        if(rejected || clip || deadline)$fatal(1,"Unexpected multitimbral fault");
        if(ov)begin
            sum=0;for(j=0;j<8;j=j+1)sum=sum+$signed(solos[j]);
            if(sample!==sum)$fatal(1,"Mixed source sum differs from isolated voices frame=%0d actual=%0d expected=%0d",frames,sample,sum);
            if(sample!=0)nonzero=nonzero+1;
            frames=frames+1;
        end
    end
    task send;input integer index,t;begin
        @(negedge clk);if(!main_ready || !solo_ready[index])$fatal(1,"Unexpected ready stall");
        tone=t;main_valid=1;solo_valid[index]=1;
        @(negedge clk);main_valid=0;solo_valid=0;
    end endtask
    task wait_frames;input integer n;integer end_at;begin end_at=frames+n;wait(frames>=end_at);@(negedge clk);end endtask
    initial begin
        repeat(5)@(negedge clk);rst=0;
        for(i=0;i<8;i=i+1)begin send(i,i%3);wait_frames(50);end
        if(accepted_count!=8 || occupied!=8'hff)$fatal(1,"Not eight independent timbre voices");
        if(dut.slots[0].slot.held_timbre!=0 || dut.slots[1].slot.held_timbre!=1 ||
           dut.slots[2].slot.held_timbre!=2)$fatal(1,"Old timbre changed");
        tone=0;wait_frames(33000);
        if(occupied || sample || nonzero<10000)$fatal(1,"Multi tail or output missing");
        $display("MULTI_TB_PASS frames=%0d voices=8 isolated_sum_exact=1 all_tails_zero=1",frames);$finish;
    end
    initial begin #200000000;$fatal(1,"Multi timeout");end
endmodule

`timescale 1ns/1ps
module demo_tb;
    reg clk=0,rst=1,ce=0,ready=0;
    wire valid;
    wire [1:0] kind;
    wire [6:0] note;
    wire [8:0] velocity;
    wire [31:0] seed;
    integer accepted=0,idx;
    reg [6:0] expected_note[0:9];
    reg [8:0] expected_velocity[0:9];
    reg [49:0] stalled_payload;
    always #10 clk=~clk;
    timbre_demo #(.SLOT_SAMPLES(8),.GATE_SAMPLES(5)) dut(
        clk,rst,ce,ready,valid,kind,note,velocity,seed);
    always @(posedge clk) if(!rst && valid && ready) begin
        idx=(accepted/2)%10;
        if(kind!==(accepted%2)) $fatal(1,"on/off event order");
        if(note!==expected_note[idx] || velocity!==expected_velocity[idx])
            $fatal(1,"Audition score changed");
        if(seed!==(32'd2000+expected_note[idx]+idx)) $fatal(1,"Non-reproducible excitation seed");
        accepted=accepted+1;
    end
    initial begin
        expected_note[0]=48;expected_note[1]=55;expected_note[2]=60;
        expected_note[3]=64;expected_note[4]=67;expected_note[5]=72;
        expected_note[6]=60;expected_note[7]=60;expected_note[8]=60;expected_note[9]=60;
        for(idx=0;idx<6;idx=idx+1) expected_velocity[idx]=205;
        expected_velocity[6]=154;expected_velocity[7]=64;
        expected_velocity[8]=128;expected_velocity[9]=230;
        repeat(3) @(negedge clk);rst=0;ce=1;
        @(negedge clk);
        if(!valid) $fatal(1,"First event missing");
        stalled_payload={kind,note,velocity,seed};
        repeat(40) begin
            @(negedge clk);
            if(!valid || {kind,note,velocity,seed}!==stalled_payload)
                $fatal(1,"Producer violated payload hold during backpressure");
        end
        ready=1;
        repeat(161) @(negedge clk);
        if(accepted<40) $fatal(1,"Incomplete two-score test %0d",accepted);
        $display("DEMO_TB_PASS accepted=%0d held_payload_cycles=40",accepted);
        $finish;
    end
endmodule

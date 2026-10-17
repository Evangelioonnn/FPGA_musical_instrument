`timescale 1ns/1ps
module fm_control_tb;
reg clk=0; always #10 clk=~clk;
reg rst=1, sample_ce=0, cmd_valid=0;
reg [1:0] cmd_kind=0;
reg [6:0] note=60;
reg [8:0] velocity=205;
wire cmd_ready, cmd_rejected, active, sample_valid;
wire signed [15:0] sample;
fm_voice dut(.clk(clk),.rst(rst),.sample_ce(sample_ce),.cmd_valid(cmd_valid),
    .cmd_kind(cmd_kind),.note(note),.velocity(velocity),.seed(32'd123),
    .cmd_ready(cmd_ready),.cmd_rejected(cmd_rejected),.active(active),
    .sample(sample),.sample_valid(sample_valid));
integer n, latency, outputs;
reg signed [15:0] first_run[0:127];
reg [31:0] saved_phase;
reg [28:0] saved_gain;
reg [13:0] saved_left;
task check;
    input condition;
    input [639:0] message;
    begin if(condition !== 1'b1) begin $display("FAIL %0s",message); $fatal(1,"FM simulation failure"); end end
endtask
task command;
    input [1:0] kind;
    input integer pitch_in, vel_in;
    input reject;
    begin
        @(negedge clk); cmd_kind=kind; note=pitch_in; velocity=vel_in; cmd_valid=1;
        while(!cmd_ready) @(negedge clk);
        @(posedge clk); #1; check(cmd_rejected==reject,"command reject indication");
        @(negedge clk); cmd_valid=0;
        @(posedge clk); #1; check(!cmd_rejected,"reject pulse must clear");
    end
endtask
task tick;
    begin
        @(negedge clk); sample_ce=1;
        @(posedge clk); #1; latency=0; outputs=sample_valid;
        @(negedge clk); sample_ce=0;
        while(outputs==0 && latency<64) begin
            @(posedge clk); #1; latency=latency+1;
            if(sample_valid) outputs=outputs+1;
        end
        check(outputs==1 && latency<=64,"one sample before deadline");
        @(posedge clk); #1; check(!sample_valid,"sample_valid one cycle");
        check((^sample)!==1'bx,"sample initialized, including partial X/Z");
    end
endtask
initial begin
    repeat(4) @(negedge clk); rst=0;
    tick; check(sample==0 && !active,"reset silence");
    command(0,60,205,0);
    for(n=0;n<128;n=n+1) begin tick; first_run[n]=sample; end
    saved_phase=dut.phase;
    command(0,35,205,1); check(dut.phase==saved_phase && active,"low illegal retains state");
    command(0,85,205,1); check(dut.phase==saved_phase && active,"high illegal retains state");
    command(3,60,205,1); check(dut.phase==saved_phase && active,"reserved retains state");
    command(0,60,205,0);
    for(n=0;n<128;n=n+1) begin tick; check(sample==first_run[n],"deterministic retrigger"); end
    command(1,0,0,0);
    for(n=0;n<100;n=n+1) tick;
    saved_gain=dut.release_gain; saved_left=dut.release_left;
    command(1,127,511,0);
    check(dut.release_gain==saved_gain && dut.release_left==saved_left,"repeat off does not restart");
    command(0,60,0,0);
    check(dut.release_gain==saved_gain && dut.release_left==saved_left,"velocity zero does not restart");
    for(n=100;n<7212;n=n+1) tick;
    check(!active && sample==0,"release reaches exact silence");
    repeat(8) begin tick; check(sample==0 && !active,"silence stable"); end
    command(0,60,511,0);
    check(dut.velocity_gain==22'd2181120,"velocity above 256 clamps");
    command(2,0,0,0); check(sample==0 && !active,"panic immediate idle silence");

    // Hold a new note throughout backpressure and accept only after current
    // sample completes; no note command may lose that output token.
    command(0,60,205,0);
    @(negedge clk); sample_ce=1;
    @(posedge clk); #1;
    @(negedge clk); sample_ce=0; cmd_valid=1; cmd_kind=0; note=72; velocity=128;
    check(!cmd_ready,"busy applies backpressure");
    outputs=0;
    while(!cmd_ready) begin @(posedge clk); #1; if(sample_valid) outputs=outputs+1; end
    check(outputs==1,"pending sample survives held note");
    @(posedge clk); #1; check(dut.phase==0 && active,"held note accepted after busy");
    @(negedge clk); cmd_valid=0;

    // Cancel every stage of an in-flight sample with panic.
    for(n=0;n<16;n=n+1) begin
        command(0,60,205,0);
        @(negedge clk); sample_ce=1;
        @(posedge clk); #1;
        @(negedge clk); sample_ce=0;
        repeat(n) @(negedge clk);
        cmd_kind=2;cmd_valid=1;
        @(posedge clk); #1;
        check(!active && sample==0 && sample_valid,"panic closes in-flight token with zero");
        @(negedge clk);cmd_valid=0;
        repeat(20) begin @(posedge clk);#1;check(!sample_valid && sample==0,"no late stale panic sample");end
    end
    command(0,60,205,0);
    @(negedge clk);cmd_kind=2;cmd_valid=1;sample_ce=1;
    @(posedge clk);#1;check(sample_valid && sample==0 && !active,"simultaneous panic/sample");
    @(negedge clk);cmd_valid=0;sample_ce=0;
    command(0,60,205,0);
    @(negedge clk);sample_ce=1;
    @(posedge clk);#1;
    @(negedge clk);sample_ce=0;rst=1;
    @(posedge clk);#1;check(!active && sample==0 && !sample_valid,"reset cancels computation");
    @(negedge clk);rst=0;tick;check(sample==0,"post-reset silence");
    $display("FM_CONTROL_TB_PASS range reserved retrigger clamp repeated_off backpressure panic reset release");
    $finish;
end
initial begin #100000000; $display("FAIL control timeout"); $fatal(1,"FM simulation failure"); end
endmodule

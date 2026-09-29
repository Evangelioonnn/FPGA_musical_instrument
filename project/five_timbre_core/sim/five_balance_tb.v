`timescale 1ns/1ps
module five_balance_tb;
    reg clk=0;always #10 clk=~clk;
    reg rst=1,ce=0;reg [6:0] note=48;reg [2:0] preset=0;
    wire signed [19:0] s0,s1,s2;
    wire [0:0] v0,v1,v2;
    gallery_shared_tone #(.N(1),.BALANCE_MODE(0)) original(
        clk,rst,ce,32'h2a32dcba,16'd65535,16'd65535,note,preset,s0,v0,);
    gallery_shared_tone #(.N(1),.BALANCE_MODE(1)) balanced(
        clk,rst,ce,32'h2a32dcba,16'd65535,16'd65535,note,preset,s1,v1,);
    gallery_shared_tone #(.N(1),.BALANCE_MODE(2)) spectral(
        clk,rst,ce,32'h2a32dcba,16'd65535,16'd65535,note,preset,s2,v2,);
    integer c3,c5,piano_balanced,piano_spectral,n0=0,n1=0,n2=0;
    reg signed [19:0] p0,p1,p2;
    always @(posedge clk) if(!rst) begin
        #1;
        if(v0) begin p0=s0;n0=n0+1;end
        if(v1) begin p1=s1;n1=n1+1;end
        if(v2) begin p2=s2;n2=n2+1;end
    end
    task frame;integer target;begin
        target=n0+1;
        ce=1;@(negedge clk);ce=0;
        wait(n0==target && n1==target && n2==target);@(negedge clk);
    end endtask
    initial begin
        repeat(8) @(negedge clk);rst=0;
        frame;
        if(p0!==p1 || p0==0) $fatal(1,"C3 baseline balance mismatch");
        c3=p0;
        note=72;frame;
        c5=p0;
        if(c3!=c5) $fatal(1,"same phase/level unbalanced difference");
        if(p1!==((c5<0 ? -(((-c5*208)+128)>>8) : ((c5*208+128)>>8))))
            $fatal(1,"C5 gain incorrect %0d %0d",p1,c5);
        if(p2==p1) $fatal(1,"spectral candidate unchanged");
        piano_balanced=p1;piano_spectral=p2;
        preset=3;frame;
        if(p0!==p1 || p0!==p2) $fatal(1,"approved bell altered");
        $display("FIVE_BALANCE_TB_PASS C3=%0d C5=%0d balanced=%0d spectral=%0d; bell fixed",
            c3,c5,piano_balanced,piano_spectral);
        $finish;
    end
endmodule

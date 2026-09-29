`timescale 1ns/1ps
module palette_equivalence_tb;
    reg clk=0;always #10 clk=~clk;
    reg rst=1,ce=0,ev=0,off=0,pedal=0;
    reg [31:0] token=0;reg [6:0] note=60;reg [1:0] timbre=0;
    wire r0,r1,v0,v1,d0,d1;wire signed [15:0] s0,s1;
    wire [7:0] o0,o1;wire a0,a1,re0,re1;
    wire [31:0] rc0,rc1,uc0,uc1;
    final_bank original(clk,rst,ce,ev,r0,off,token,note,timbre,pedal,16'd96,
        a0,re0,rc0,uc0,o0,,v0,s0,,d0);
    palette_bank #(.PROFILE(0)) shared(clk,rst,ce,ev,r1,off,token,note,timbre,pedal,16'd96,
        a1,re1,rc1,uc1,o1,,v1,s1,,d1);
    integer cycle=0,frame=0,compared=0;integer j;
    integer outputs0=0,outputs1=0;reg signed [15:0] pcm0,pcm1;
    always @(negedge clk) begin
        if(rst) begin cycle=0;ce=0;end
        else begin ce=(cycle==0);cycle=(cycle+1)%1040;end
    end
    always @(posedge clk) if(!rst) begin
        #1;
        if(v0) begin pcm0=s0;outputs0=outputs0+1;end
        if(v1) begin pcm1=s1;outputs1=outputs1+1;end
        if(cycle==180) begin
            if(outputs0!=1 || outputs1!=1 || pcm0!==pcm1 || o0!==o1 || d0 || d1) begin
                $display("FAIL frame %0d pcm %0d/%0d count %0d/%0d occupied %h/%h",frame,pcm0,pcm1,outputs0,outputs1,o0,o1);$fatal;
            end
            compared=compared+1;outputs0=0;outputs1=0;frame=frame+1;
        end
    end
    task command;
        input kind;input [31:0] id;input [6:0] pitch;input [1:0] tone;
        begin
            wait(cycle==220);@(negedge clk);
            while(!r0 || !r1) @(negedge clk);
            off=kind;token=id;note=pitch;timbre=tone;ev=1;
            @(negedge clk);ev=0;
        end
    endtask
    task frames;input integer n;integer target;begin target=frame+n;wait(frame>=target);end endtask
    initial begin
        repeat(8) @(negedge clk);rst=0;frames(2);
        // Distinct pitches, repeated equal pitch, all eight slots occupied.
        for(j=0;j<8;j=j+1) command(0,j+1,48+j*4,0);
        frames(1200);command(0,99,60,0);frames(2);
        if(rc0!=1 || rc1!=1) $fatal;
        pedal=1;for(j=0;j<8;j=j+1) command(1,j+1,0,0);
        frames(50);pedal=0;frames(900);
        if(o0!=0 || o1!=0) $fatal;
        for(j=0;j<8;j=j+1) command(0,20+j,48+j*4,j%2);
        frames(1500);
        for(j=0;j<8;j=j+1) command(1,20+j,127,0);
        frames(900);
        // Pluck sample/state are unaffected by externalized startup lookup.
        if(rc0!==rc1 || uc0!==uc1) $fatal;
        $display("PALETTE_EQUIVALENCE_TB_PASS %0d frames: eight voices, mixed timbres, sustain, release, full rejection",compared);
        $finish;
    end
    initial begin #150000000;$display("timeout");$fatal;end
endmodule

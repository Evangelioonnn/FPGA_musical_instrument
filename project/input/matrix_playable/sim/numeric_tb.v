`timescale 1ns/1ps
module numeric_tb;
    reg clk=0,rst=1;reg [4:0] tick=0;wire ce=!rst && tick==0;
    reg on=0,off=0;reg [2:0] release_index=3;reg [6:0] note=60;
    wire [31:0] phase_step;wire signed [15:0] x,y,fx,fy;
    wire xv,yv,fxv,fyv,frx,fry,ax,ay;wire [2:0] xs,ys;wire [15:0] env;
    reg compare_fm=1;integer frames=0,checks=0,release_samples=0,i,target,n;
    reg signed [15:0] fm_expected;integer old_outputs=0,new_outputs=0;
    integer lengths[0:7];
    always #10 clk=~clk;
    always @(posedge clk)if(rst)tick<=0;else tick<=tick+1'b1;
    note_table notes(note,phase_step);
    synth_voice original(clk,rst,ce,on,off,1'b0,phase_step,x,xv,env,xs);
    knob_reference_voice #(.DYNAMIC_ADSR(1)) reference(clk,rst,ce,on,off,phase_step,
        16'd68,16'd6,16'd32768,16'd3,y,yv,ys);
    fm_voice old_fm(clk,rst,ce,on||off,off?2'd1:2'd0,note,9'd256,32'h12345678,frx, ,ax,fx,fxv);
    playable_fm_voice new_fm(clk,rst,ce,on||off,off?2'd1:2'd0,note,9'd256,32'h12345678,release_index,fry, ,ay,fy,fyv);
    always @(posedge clk)begin
        #1;
        if(!rst)begin
            if(x!==y || xv!==yv || xs!==ys)$fatal(1,"Original DDS/ADSR changed");
            if(fxv)begin fm_expected=fx;old_outputs=old_outputs+1;end
            if(fyv)begin
                new_outputs=new_outputs+1;
                if(compare_fm && (fy!==fm_expected || old_outputs!=new_outputs))$fatal(1,"Default FM sample changed");
            end
            if(yv)begin frames=frames+1;checks=checks+1;end
        end
    end
    task wait_frames;input integer count;integer end_at;begin end_at=frames+count;wait(frames>=end_at);@(negedge clk);end endtask
    task command;input integer end_note;begin
        @(negedge clk);while(!frx || !fry || ce)@(negedge clk);
        on=!end_note;off=end_note;@(negedge clk);on=0;off=0;
    end endtask
    initial begin
        lengths[0]=1442;lengths[1]=2885;lengths[2]=4808;lengths[3]=7212;
        lengths[4]=14423;lengths[5]=28846;lengths[6]=48077;lengths[7]=96154;
        repeat(5)@(negedge clk);rst=0;
        command(0);wait_frames(31250);command(1);wait_frames(12000);
        if(ay || ys || y || fy)$fatal(1,"Default tail nonzero");
        compare_fm=0;
        for(i=0;i<8;i=i+1)begin
            release_index=i;command(0);wait_frames(100);command(1);
            // Independent sample count, table changes while released must not affect it.
            n=0;release_index=7-i;
            while(ay)begin @(posedge clk);if(ce)n=n+1;#1;end
            if(n!=lengths[i])$fatal(1,"FM release length index=%0d got=%0d expected=%0d",i,n,lengths[i]);
            @(negedge clk);
        end
        $display("NUMERIC_TB_PASS default_reference_exact=43250 default_fm_exact=43250 fm_lengths=8 samples=%0d",checks);$finish;
    end
    initial begin #300000000;$fatal(1,"numeric timeout");end
endmodule

`timescale 1ns/1ps
module reference_tb;
    reg clk=0,rst=1;reg [3:0] tick=0;
    wire ce=!rst && tick==0;
    reg on=0,off=0;
    reg [15:0] a=68,d=6,s=32768,r=3;
    reg [6:0] note=60;
    wire [31:0] step;
    wire signed [15:0] x,y;
    wire xv,yv;wire [2:0] xs,ys;wire [15:0] env;
    integer count=0,model_state=0,level=0,ap,dp,rp,checks=0;
    reg compare_default=1;
    always #10 clk=~clk;
    always @(posedge clk) if(rst) tick<=0;else tick<=tick+1'b1;
    note_table notes(note,step);
    synth_voice original(clk,rst,ce,on,off,1'b0,step,x,xv,env,xs);
    knob_reference_voice #(.DYNAMIC_ADSR(1)) dut(clk,rst,ce,on,off,step,a,d,s,r,y,yv,ys);
    // Independent integer recurrence, including zero-step normalization and
    // event precedence. Compares actual envelope every system clock.
    always @(posedge clk) begin
        ap=a==0?1:a;dp=d==0?1:d;rp=r==0?1:r;
        if(rst) begin model_state=0;level=0;end
        else if(on) model_state=1;
        else if(off) begin if(model_state!=0)model_state=4;end
        else if(ce) case(model_state)
            0:level=0;
            1:begin level=level+ap;if(level>=65535)begin level=65535;model_state=2;end end
            2:if(level<=s+dp)begin level=s;model_state=3;end else level=level-dp;
            3:level=s;
            4:if(level<=rp)begin level=0;model_state=0;end else level=level-rp;
        endcase
        #1;
        if(dut.envelope!==level || ys!==model_state) $fatal(1,"ADSR independent recurrence mismatch");
        if(compare_default && (x!==y || xv!==yv || xs!==ys)) $fatal(1,"Default reference changed");
        if(yv) begin count=count+1;checks=checks+1;end
    end
    task frames;input integer n;integer target;begin target=count+n;wait(count>=target);@(negedge clk);end endtask
    task note_start;begin @(negedge clk);on=1;@(negedge clk);on=0;end endtask
    task note_end;begin @(negedge clk);off=1;@(negedge clk);off=0;end endtask
    initial begin
        repeat(5)@(negedge clk);rst=0;note_start;
        frames(31250);note_end;frames(12000);
        if(ys!=0 || y!=0)$fatal(1,"Original release did not end");
        compare_default=0;a=65535;d=65535;s=12345;r=1;
        note_start;frames(4);
        if(level!=12345)$fatal(1,"Extreme A/D/sustain failed");
        note_end;frames(12350);if(level!=0)$fatal(1,"One-LSB release failed");
        a=0;d=0;s=0;r=0;note_start;frames(20);note_end;frames(30);
        if(level!=0)$fatal(1,"Zero-step normalization failed");
        a=1000;d=100;s=20000;r=65535;note_start;frames(80);note_end;frames(2);
        if(level!=0)$fatal(1,"Fast release failed");
        $display("REFERENCE_TB_PASS samples=%0d default_exact=1 independent_adsr=1",checks);$finish;
    end
    initial begin #100000000;$fatal(1,"Reference timeout");end
endmodule

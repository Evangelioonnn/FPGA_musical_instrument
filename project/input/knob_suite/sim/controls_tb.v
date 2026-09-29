`timescale 1ns/1ps
module controls_tb;
    reg clk=0,rst=1,ce=0,sv=0,ready=1;
    reg signed [1:0] step=0;
    wire [4:0] valid;
    wire [6:0] note[0:4],selected[0:4];
    wire [1:0] tone[0:4],selected_tone[0:4];
    wire [23:0] gate[0:4];wire [15:0] release_value[0:4],wet[0:4];
    wire [16:0] volume[0:4];wire [4:0] vi[0:4],ei[0:4];wire [2:0] ri[0:4];
    wire [31:0] overflow[0:4];
    integer i,j,events=0,expected_pitch=60;
    always #10 clk=~clk;
    genvar g;
    generate for(g=0;g<5;g=g+1)begin: cases
        knob_controls #(.MODE(g)) dut(clk,rst,ce,sv,step,valid[g],ready,
            note[g],tone[g],gate[g],release_value[g],volume[g],wet[g],selected[g],selected_tone[g],vi[g],ri[g],ei[g],overflow[g]);
    end endgenerate
    task turn;input integer direction;begin
        @(negedge clk);step=direction;sv=1;
        if(direction==1 && expected_pitch<84)expected_pitch=expected_pitch+1;
        if(direction==-1 && expected_pitch>48)expected_pitch=expected_pitch-1;
        @(negedge clk);sv=0;step=0;
        if(note[0]!==expected_pitch || !valid[0])$fatal(1,"Strike pitch or queue event wrong");
        events=events+1;
        repeat(2)@(negedge clk);
    end endtask
    initial begin
        repeat(5)@(negedge clk);rst=0;repeat(5)@(negedge clk);
        if(valid || selected[0]!=60 || volume[1]!=65536 || selected_tone[2]!=0 || ri[3]!=5)$fatal(1,"Initial modes");
        turn(1);if(selected_tone[2]!=1 || ri[3]!=6 || ei[4]!=1)$fatal(1,"Forward parameter modes");
        turn(-1);if(selected_tone[2]!=0 || ri[3]!=5 || ei[4]!=0 || vi[1]!=23)$fatal(1,"Reverse modes");
        for(i=0;i<45;i=i+1)turn(-1);
        if(selected[0]!=48 || vi[1]!=0 || volume[1]!=0 || ri[3]!=0 || ei[4]!=0)$fatal(1,"Lower clamps");
        for(i=0;i<50;i=i+1)turn(1);
        if(selected[0]!=84 || vi[1]!=24 || volume[1]!=65536 || ri[3]!=7 || ei[4]!=16 || wet[4]!=16384)$fatal(1,"Upper clamps");
        repeat(100)@(negedge clk);if(valid[0])$fatal(1,"Stationary source triggered");
        // Force queue backpressure; accepted event fields stay unchanged.
        ready=0;@(negedge clk);sv=1;step=-1;@(negedge clk);sv=0;
        repeat(20)begin @(negedge clk);if(!valid[0] || note[0]!=83)$fatal(1,"Backpressure changed event");end
        ready=1;repeat(4)@(negedge clk);
        for(j=0;j<5;j=j+1)if(overflow[j])$fatal(1,"Unexpected overflow");
        // Deliberate producer overload is visible rather than hidden.
        ready=0;
        for(i=0;i<18;i=i+1)begin @(negedge clk);sv=1;step=1;@(negedge clk);sv=0;end
        repeat(3)@(negedge clk);if(overflow[0]!=2)$fatal(1,"Queue overflow accounting");
        $display("CONTROLS_TB_PASS turns=%0d modes=5 clamps=1 stable_queue=1 explicit_overflow=2",events);$finish;
    end
endmodule

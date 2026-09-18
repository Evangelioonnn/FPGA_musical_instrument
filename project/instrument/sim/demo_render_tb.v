`timescale 1ns/1ps
// Accelerate system-clock spacing, retaining REAL sample counts and parameters.
// This runs the 6-second event loop without simulating 300 million clocks.
module demo_render_tb;
    reg clk=0,rst=1,ce=0;
    wire on,off;
    wire [6:0] note;
    wire [31:0] step;
    wire signed [15:0] sample;
    wire valid;
    wire [15:0] env;
    wire [2:0] state;
    integer i,fd,on_count=0,off_count=0;
    always #10 clk=~clk;
    demo_events demo(clk,rst,ce,on,off,note);
    note_table notes(note,step);
    synth_voice voice(clk,rst,ce,on,off,1'b0,step,sample,valid,env,state);
    always @(posedge clk) if(!rst) begin
        if(on) begin
            case(on_count)
                0: if(note!=60) $fatal(1,"C4 missing");
                1: if(note!=64) $fatal(1,"E4 missing");
                2: if(note!=67) $fatal(1,"G4 missing");
                3: if(note!=72) $fatal(1,"C5 missing");
                default: $fatal(1,"Unexpected trigger");
            endcase
            on_count=on_count+1;
        end
        if(off) off_count=off_count+1;
    end
    initial begin
        fd=$fopen("demo_samples.txt","w");
        if(!fd) $fatal(1,"Cannot write samples");
        repeat(4) @(negedge clk); rst=0;
        for(i=0;i<288462;i=i+1) begin
            @(negedge clk); ce=1;
            @(negedge clk); ce=0;
            repeat(3) @(negedge clk);
            if(!valid || ^sample===1'bx || sample < -512 || sample > 511)
                $fatal(1,"Render invalid sample");
            $fwrite(fd,"%0d\n",sample);
            repeat(3) @(negedge clk);
        end
        $fclose(fd);
        if(on_count!=4 || off_count!=4) $fatal(1,"Event count mismatch");
        $display("DEMO_RENDER_TB_PASS samples=%0d",i); $finish;
    end
    initial begin #60000000; $fatal(1,"Demo timeout"); end
endmodule

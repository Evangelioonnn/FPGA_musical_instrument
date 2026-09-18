`timescale 1ns/1ps
module quality_render_tb;
    reg clk=0,rst=1,ce=0;
    wire on,off;
    wire [6:0] note;
    wire [31:0] step;
    wire signed [15:0] a,b;
    wire va,vb;
    wire [15:0] ea,eb;
    wire [2:0] sa,sb;
    integer i,fd,on_count=0,off_count=0;
    always #10 clk=~clk;
    demo_events demo(clk,rst,ce,on,off,note);
    note_table notes(note,step);
    synth_voice original(clk,rst,ce,on,off,1'b0,step,a,va,ea,sa);
    quality_voice candidate(clk,rst,ce,on,off,1'b0,step,b,vb,eb,sb);
    always @(posedge clk) if(!rst) begin
        if(on) on_count=on_count+1;
        if(off) off_count=off_count+1;
    end
    initial begin
        fd=$fopen("ab_samples.txt","w");
        if(!fd) $fatal(1,"Cannot write samples");
        repeat(4) @(negedge clk); rst=0;
        for(i=0;i<288462;i=i+1) begin
            @(negedge clk); ce=1;
            @(negedge clk); ce=0;
            repeat(3) @(negedge clk);
            if(!va) $fatal(1,"Original sample missing");
            repeat(2) @(negedge clk);
            if(!vb || ^{a,b}===1'bx || a < -512 || a > 511 || b < -512 || b > 512)
                $fatal(1,"Invalid A/B sample");
            if(ea!==eb || sa!==sb) $fatal(1,"Envelope changed");
            if(eb==0 && (a!==0 || b!==0)) $fatal(1,"Nonzero during silence");
            $fwrite(fd,"%0d %0d\n",a,b);
            repeat(1) @(negedge clk);
        end
        $fclose(fd);
        if(on_count!=4 || off_count!=4) $fatal(1,"Event count mismatch");
        $display("QUALITY_RENDER_TB_PASS samples=%0d",i); $finish;
    end
    initial begin #60000000; $fatal(1,"Render timeout"); end
endmodule

`timescale 1ns/1ps
module poly_render_tb;
    reg clk=0,rst=1,ce=0;
    wire ev,on,ready,valid,clip,stolen,ignored;
    wire [6:0] note;
    wire signed [15:0] sample;
    wire [3:0] busy,held;
    wire [27:0] notes;
    wire [63:0] samples,envs;
    wire [11:0] states;
    integer i,k,fd,ons=0,offs=0;
    always #10 clk=~clk;
    poly_demo_events demo(clk,rst,ce,ev,on,note);
    poly_synth4 core(clk,rst,ce,ev,on,note,1'b0,ready,sample,valid,clip,busy,held,notes,samples,envs,states,stolen,ignored);
    always @(posedge clk) if(!rst) begin
        if(ev) begin
            if(!ready) $fatal(1,"Demo event not accepted");
            if(on) ons=ons+1; else offs=offs+1;
        end
        if(stolen || ignored) $fatal(1,"Unexpected demo allocation event");
    end
    initial begin
        fd=$fopen("poly_samples.txt","w");
        if(!fd) $fatal(1,"Cannot export samples");
        repeat(4) @(negedge clk); rst=0;
        for(i=0;i<384616;i=i+1) begin
            @(negedge clk);ce=1;
            @(posedge clk);#1;if(valid) $fatal(1,"Early E0 output");
            @(negedge clk);ce=0;
            repeat(3) begin @(posedge clk);#1;if(valid) $fatal(1,"Early E1..E3 output");end
            if(core.valid_mask!==4'b1111) $fatal(1,"Voice pipelines disagree");
            @(posedge clk);#1;
            if(!valid || clip || ^sample===1'bx || sample < -512 || sample > 511) $fatal(1,"E4 invalid sample");
            $fwrite(fd,"%0d %0d %0d %0d %0d\n",sample,$signed(samples[15:0]),$signed(samples[31:16]),$signed(samples[47:32]),$signed(samples[63:48]));
            @(posedge clk);#1;if(valid) $fatal(1,"Valid not a pulse");
            repeat(2) @(negedge clk);
        end
        $fclose(fd);
        if(ons!=4 || offs!=4 || busy!=0 || envs!==0) $fatal(1,"Demo event/end state");
        $display("POLY_RENDER_TB_PASS samples=%0d on=%0d off=%0d",i,ons,offs);$finish;
    end
    initial begin #100000000;$fatal(1,"Render timeout");end
endmodule

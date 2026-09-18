`timescale 1ns/1ps
module voice_numeric_tb;
    reg clk=0,rst=1,ce=0,on=0;
    reg [31:0] base=0;
    reg [17:0] ratio=65536;
    reg [8:0] velocity=256;
    reg [14:0] w2=0,w3=0;
    wire signed [15:0] sample;
    wire valid;
    wire [15:0] env;
    wire [2:0] state;
    wire [31:0] step,phase;
    reg [88:0] stimulus;
    reg [79:0] expected;
    integer f,rc,count=0;
    always #10 clk=~clk;
    expressive_voice dut(clk,rst,ce,on,1'b0,1'b0,base,ratio,31'd0,velocity,w2,w3,
        16'd65535,16'd65535,16'd65535,16'd65535,sample,valid,env,state,step,phase);
    task sample_tick;
        begin ce=1;@(negedge clk);ce=0;repeat(6) @(negedge clk);end
    endtask
    initial begin
        repeat(4) @(negedge clk);rst=0;on=1;
        @(negedge clk);on=0;repeat(3) @(negedge clk);
        sample_tick;repeat(9) @(negedge clk);sample_tick;repeat(9) @(negedge clk);
        if(env!=65535 || phase) $fatal(1,"Bootstrap");
        f=$fopen("voice_vectors.txt","r");if(!f) $fatal(1,"Cannot open vector file");
        while(!$feof(f)) begin
            rc=$fscanf(f,"%h %h\n",stimulus,expected);
            if(rc==2) begin
                {base,ratio,w2,w3,velocity}=stimulus;on=1;
                @(negedge clk);on=0;repeat(3) @(negedge clk);
                sample_tick;
                if(!valid || {sample,phase,step}!==expected) $fatal(1,"Numeric vector=%0d got=%h expected=%h",count,{sample,phase,step},expected);
                repeat(9) @(negedge clk);count=count+1;
            end
        end
        if(count!=6000) $fatal(1,"Missing vectors");
        $display("VOICE_NUMERIC_TB_PASS vectors=%0d",count);$finish;
    end
endmodule

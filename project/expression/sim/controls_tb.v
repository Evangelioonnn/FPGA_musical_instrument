`timescale 1ns/1ps
module controls_tb;
    reg clk=0,rst,ce,valid;
    reg [3:0] addr;
    reg [31:0] data;
    wire ready,ack,accepted,sus,sos,panic;
    wire [31:0] applied;
    wire [16:0] volume,gain;
    wire [1:0] timbre;
    wire [14:0] w2,w3;
    wire [17:0] ratio;
    wire [30:0] glide;
    wire [15:0] a,d,s,r;
    reg [38:0] stimulus;
    reg [215:0] expected;
    wire [215:0] observed={ack,accepted,applied,volume,gain,timbre,w2,w3,ratio,glide,sus,sos,panic,a,d,s,r};
    integer f,rc,count=0;
    always #10 clk=~clk;
    expression_controls dut(clk,rst,ce,valid,addr,data,ready,ack,accepted,applied,volume,gain,
        timbre,w2,w3,ratio,glide,sus,sos,panic,a,d,s,r);
    initial begin
        f=$fopen("controls_vectors.txt","r");if(!f) $fatal(1,"Cannot open vectors");
        while(!$feof(f)) begin
            rc=$fscanf(f,"%h %h\n",stimulus,expected);
            if(rc==2) begin
                @(negedge clk);{rst,ce,valid,addr,data}=stimulus;
                @(posedge clk);#1;
                if(observed!==expected) $fatal(1,"Controls vector=%0d got=%h expected=%h",count,observed,expected);
                if(ready!==!rst) $fatal(1,"Config ready");count=count+1;
            end
        end
        if(count!=9000) $fatal(1,"Missing vectors");
        $display("CONTROLS_TB_PASS vectors=%0d",count);$finish;
    end
endmodule

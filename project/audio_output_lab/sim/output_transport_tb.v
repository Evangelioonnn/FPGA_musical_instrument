`timescale 1ns/1ps
module output_transport_tb;
    reg clk=0;always #10 clk=~clk;
    reg rst=1;
    reg signed [15:0] left=0,right=0;
    wire [1:0] ce,bck,ws,din;
    output_tx #(.EDGE_SPACING(0)) a(clk,rst,left,right,ce[0],bck[0],ws[0],din[0]);
    output_tx #(.EDGE_SPACING(1)) b(clk,rst,left,right,ce[1],bck[1],ws[1],din[1]);
    wire signed [15:0] inverted;
    output_polarity #(.INVERT(1)) inv(left,inverted);
    reg [15:0] expected_l=0,expected_r=0;
    integer frame=0,cycle=0,last_ce=0,n;
    always @(posedge clk) if(!rst) begin
        cycle=cycle+1;
        if(ce[0]) begin
            if(ce!==2'b11 || (last_ce && cycle-last_ce!=1040)) $fatal;
            last_ce=cycle;expected_l=left;expected_r=right;frame=frame+1;
        end
    end
    genvar g;generate for(g=0;g<2;g=g+1) begin: decoders
        integer bit_index=0,words=0;
        reg [19:0] word=0;
        time last_data=0,last_ws=0,last_fall=0;
        always @(negedge bck[g]) last_fall=$time;
        always @(din[g]) begin
            if(!rst && $time>1000 && g==1 && $time-last_fall!=40) $fatal;
            last_data=$time;
        end
        always @(ws[g]) begin
            if(!rst && $time>1000 && g==1 && $time-last_fall!=80) $fatal;
            last_ws=$time;
        end
        always @(posedge bck[g]) if(!rst) begin
            if($time-last_data < (g==1 ? 220:260) || $time-last_ws < (g==1 ? 180:260)) $fatal;
            if(ws[g]!==(bit_index>=20)) $fatal;
            word={word[18:0],din[g]};
            if(bit_index==19 || bit_index==39) begin
                if(word[19:16]!=0 || word[15:0] !== (bit_index==19 ? expected_r:expected_l)) $fatal;
                words=words+1;
            end
            bit_index=(bit_index+1)%40;
        end
    end endgenerate
    initial begin
        repeat(8) @(negedge clk);rst=0;
        for(n=0;n<65536;n=n+1) begin
            left=n;right=(n*40503+1729); // Independent permutation of all 16-bit words.
            #1;
            if($signed(inverted)!==(n==32768 ? 32767 : -$signed(left))) $fatal;
            @(posedge ce[0]);@(negedge clk); // sample_ce precedes its latching edge
            @(negedge clk);
        end
        repeat(1040) @(negedge clk);
        if(decoders[0].words<131072 || decoders[1].words!=decoders[0].words) $fatal;
        $display("OUTPUT_TRANSPORT_TB_PASS full 65536 codes per channel, %0d words per transport, cadence and setup windows",decoders[0].words);$finish;
    end
    initial begin #1500000000;$fatal;end
endmodule

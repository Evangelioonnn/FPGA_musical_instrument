`timescale 1ns/1ps
module tx_format_checker(input wire rst,bck,ws,din,
    input wire signed [15:0] expected_left,expected_right);
    reg [15:0] shift=0;
    integer bits=0,words=0;
    always @(posedge rst) begin shift=0;bits=0;words=0;end
    always @(posedge bck) if(!rst) begin
        shift={shift[14:0],din};bits=bits+1;
    end
    always @(ws) if(!rst) begin
        #1;
        if(bits!=20) $fatal(1,"serial word length=%0d",bits);
        if(words>=2) begin
            if(ws && shift!==expected_right) $fatal(1,"right word=%h expected=%h",shift,expected_right);
            if(!ws && shift!==expected_left) $fatal(1,"left word=%h expected=%h",shift,expected_left);
        end
        words=words+1;bits=0;shift=0;
    end
endmodule

module tx_format_tb;
    reg clk=0,rst=1;
    wire ce1,bck1,ws1,din1,ce4,bck4,ws4,din4;
    integer checked1=0,checked4=0;
    always #10 clk=~clk;
    noise_pt8211_tx #(.OSR(1)) tx1(clk,rst,16'sd23456,-16'sd12345,ce1,bck1,ws1,din1);
    noise_pt8211_tx #(.OSR(4)) tx4(clk,rst,16'sd23456,-16'sd12345,ce4,bck4,ws4,din4);
    tx_format_checker check1(rst,bck1,ws1,din1,16'sd23456,-16'sd12345);
    tx_format_checker check4(rst,bck4,ws4,din4,16'sd23456,-16'sd12345);
    always @(posedge ws1) if(!rst && check1.words>=3) checked1=checked1+1;
    always @(posedge ws4) if(!rst && check4.words>=3) checked4=checked4+1;
    initial begin
        repeat(5) @(negedge clk);rst=0;
        repeat(60000) @(negedge clk);
        if(checked1<4 || checked4<16) $fatal(1,"serial checks missing");
        $display("TX_FORMAT_TB_PASS lsbj_16bit_payload_20bck_per_channel frames=%0d/%0d",checked1,checked4);
        $finish;
    end
    initial begin #1300000;$fatal(1,"tx format timeout");end
endmodule

`timescale 1ns/1ps
module tx_rate_tb;
    reg clk=0,rst=1;
    wire ce1,ce2,ce4;
    wire bck1,ws1,din1,bck2,ws2,din2,bck4,ws4,din4;
    integer cycle=0,last1=0,last2=0,last4=0;
    integer count1=0,count2=0,count4=0;
    integer last_bck4=0,min_half=100,max_half=0,half_width;
    reg previous_bck4=0;
    always #10 clk=~clk;
    noise_pt8211_tx #(.OSR(1)) tx1(clk,rst,16'sd1234,-16'sd2345,ce1,bck1,ws1,din1);
    noise_pt8211_tx #(.OSR(2)) tx2(clk,rst,16'sd1234,-16'sd2345,ce2,bck2,ws2,din2);
    noise_pt8211_tx #(.OSR(4)) tx4(clk,rst,16'sd1234,-16'sd2345,ce4,bck4,ws4,din4);

    always @(posedge clk) begin
        cycle=cycle+1;
        if(!rst) begin
            if(ce1) begin
                if(last1!=0 && cycle-last1!=1040) $fatal(1,"OSR1 frame interval");
                last1=cycle;count1=count1+1;
            end
            if(ce2) begin
                if(last2!=0 && cycle-last2!=520) $fatal(1,"OSR2 frame interval");
                last2=cycle;count2=count2+1;
            end
            if(ce4) begin
                if(last4!=0 && cycle-last4!=260) $fatal(1,"OSR4 frame interval");
                last4=cycle;count4=count4+1;
            end
            if(bck4!==previous_bck4) begin
                if(last_bck4!=0) begin
                    half_width=cycle-last_bck4;
                    if(half_width<3 || half_width>4) $fatal(1,"OSR4 BCK half-period=%0d",half_width);
                    if(half_width<min_half) min_half=half_width;
                    if(half_width>max_half) max_half=half_width;
                end
                last_bck4=cycle;previous_bck4=bck4;
            end
        end
    end

    initial begin
        repeat(5) @(negedge clk);rst=0;
        repeat(25000) @(negedge clk);
        if(count1<20 || count2<40 || count4<80) $fatal(1,"insufficient frames");
        if(min_half!=3 || max_half!=4) $fatal(1,"fractional divider pattern %0d..%0d",min_half,max_half);
        $display("TX_RATE_TB_PASS frames=%0d/%0d/%0d osr4_half_period=%0d..%0d clocks",count1,count2,count4,min_half,max_half);
        $finish;
    end
    initial begin #600000;$fatal(1,"tx rate timeout");end
endmodule

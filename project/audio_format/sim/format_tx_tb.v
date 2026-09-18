`timescale 1ns/1ps
module format_tx_tb;
    reg clk=0,rst=1,request16=0;
    reg [15:0] left=0,right=0;
    wire ce,bck,ws,din,active16,old_ce,old_bck,old_ws,old_din;
    integer count=0,changes=0;
    reg expected_mode=0;
    always #10 clk=~clk;
    pt8211_format_tx dut(clk,rst,left,right,request16,ce,bck,ws,din,active16);
    pt8211_tx original(clk,rst,left,right,old_ce,old_bck,old_ws,old_din);
    format_checker check(clk,rst,ce,bck,ws,din,active16,left,right);
    // This pattern changes during each word as well as on latch edges.
    always @(posedge clk) begin
        if(rst) begin count<=0; left<=0; right<=0; end
        else begin
            count<=count+1;
            case((count/1040)%6)
                0: begin left<=16'h0000; right<=16'hFFFF; end
                1: begin left<=16'h7FFF; right<=16'h8000; end
                2: begin left<=16'hA53D; right<=16'h36C7; end
                3: begin left<=16'h0001 << ((count/1040)%16); right<=~left; end
                4: begin left<=left+16'd17; right<=right-16'd31; end
                5: begin left<=16'hFFFF; right<=16'h0000; end
            endcase
        end
    end
    // Deliberately request changes away from frame boundaries.
    always begin #317830; request16=~request16; end
    always @(posedge clk) begin
        if(rst) expected_mode=0;
        else if(ce) expected_mode=request16;
        #1;
        if(active16!==expected_mode) $fatal(1,"Format request not frame-latched");
        if({ce,ws,din}!=={old_ce,old_ws,old_din}) $fatal(1,"Sample/data timing changed");
        if(!active16 && bck!==old_bck) $fatal(1,"A differs from original BCK");
        if(active16 && bck && !old_bck) $fatal(1,"B added a clock edge");
    end
    always @(active16) if(!rst && $time>0) begin
        #1;
        if(ws!==0 || bck!==0) $fatal(1,"Format changed inside a word");
        changes=changes+1;
    end
    initial begin
        repeat(16) @(negedge clk); rst=0;
        #7000100;
        if(check.words16<100 || check.words20<100 || changes<10) $fatal(1,"Insufficient pattern coverage");
        // Interrupt a word and verify reset/startup again with request16 high.
        @(negedge clk); rst=1; request16=1;
        repeat(4) @(negedge clk); rst=0;
        #2000100;
        if(check.frames<90 || check.words16==0 || check.words20==0) $fatal(1,"Reset recovery missing");
        $display("FORMAT_TX_TB_PASS final_frames=%0d words16=%0d words20=%0d switches_total=%0d",
            check.frames,check.words16,check.words20,changes);
        $finish;
    end
endmodule

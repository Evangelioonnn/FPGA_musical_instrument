`timescale 1ns/1ps
module palette_range_tb;
    reg clk=0;always #10 clk=~clk;
    reg rst=1,ce=0,ev=0,off=0;reg [31:0] token=0;reg [6:0] note=36;
    wire ready,accepted,rejected,valid,deadline,clip;wire [7:0] occupied;
    wire signed [15:0] sample;wire [31:0] rejected_count;
    reg [7:0] heard;
    palette_bank #(.PROFILE(6)) dut(clk,rst,ce,ev,ready,off,token,note,2'd1,1'b0,16'd24,
        accepted,rejected,rejected_count,,occupied,,valid,sample,clip,deadline);
    genvar g;generate for(g=0;g<8;g=g+1) begin: per_voice_audit
        always @(posedge clk) begin
            if(rst) heard[g]<=0;
            else if(valid && dut.slots[g].slot.sample!=0) heard[g]<=1;
        end
    end endgenerate
    integer cycle=0,frames=0,hits=0,accepted_total=0;
    always @(negedge clk) begin
        if(rst) begin cycle=0;ce=0;end
        else begin ce=(cycle==0);cycle=(cycle+1)%1040;end
    end
    always @(posedge clk) if(!rst) begin
        #1;
        if(accepted) accepted_total=accepted_total+1;
        if(valid) begin
            frames=frames+1;
            if((^sample)===1'bx || deadline || clip) $fatal;
            if(sample!=0) hits=hits+1;
        end
    end
    task command;input [6:0] pitch;begin
        @(negedge clk);token=token+1;note=pitch;ev=1;
        @(posedge clk);while(!ready) @(posedge clk);
        @(negedge clk);ev=0;
    end endtask
    integer base,k,target,old_hits;reg [7:0] expected_heard;
    initial begin
        for(base=36;base<=84;base=base+8) begin
            rst=1;repeat(8) @(negedge clk);rst=0;
            // As fast as ready permits: exercises shared lookup capture
            // with different notes arriving only a few fabric clocks apart.
            for(k=base;k<base+8 && k<=84;k=k+1) command(k);
            old_hits=hits;target=frames+30;wait(frames>=target);
            expected_heard=base<=76 ? 8'hff : (1<<(85-base))-1;
            if(heard!==expected_heard) begin $display("Missing voice output base=%0d heard=%h expected=%h",base,heard,expected_heard);$fatal;end
            if(hits<=old_hits || rejected_count!=0) begin $display("base=%0d hits=%0d old=%0d rej=%0d occupied=%h raw=%0d length=%0d",base,hits,old_hits,rejected_count,occupied,dut.slots[0].slot.pluck_sample,dut.slots[0].slot.length);$fatal;end
        end
        command(35);command(85);command(127);repeat(4) @(negedge clk);
        if(rejected_count!=3 || accepted_total!=49) $fatal;
        $display("PALETTE_RANGE_TB_PASS 49 notes C2-C6, back-to-back init, 35/85/127 rejected, frames=%0d",frames);$finish;
    end
    initial begin #20000000;$fatal;end
endmodule

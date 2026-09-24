`timescale 1ns/1ps
module final_engine_tb;
    reg clk=0,rst=1,sample_ce=0;
    reg [15:0] keys=0;
    reg changed=0,ghost=0,all_released=1;
    reg [2:0] button_n=3'b111;
    reg step_valid=0; reg signed [1:0] step=0;
    wire final_valid; wire signed [15:0] final_sample;
    wire [1:0] timbre; wire sustain,release_mode,blocked;
    wire [4:0] volume_index; wire [2:0] release_index;
    wire rejected,fault; wire [1:0] occupied; wire deadline,muting;
    always #10 clk=~clk;
    // The production frame cadence is 1040 clocks. A 150-clock test cadence
    // still leaves the bank's 64-clock guard and two-slot mix time to finish.
    always begin repeat(150) @(posedge clk); sample_ce<=1; @(posedge clk); sample_ce<=0; end
    final_engine #(.N(2),.BUTTON_CYCLES(2),.LONG_CYCLES(30)) dut(
        clk,rst,sample_ce,keys,changed,ghost,all_released,button_n,step_valid,step,
        final_valid,final_sample,timbre,sustain,release_mode,blocked,volume_index,
        release_index,rejected,fault,occupied,deadline,muting);
    integer i,valid_count,nonzero_count;
    task snapshot(input [15:0] value);
        begin keys<=value; changed<=1; @(posedge clk); changed<=0; end
    endtask
    task press_timbre;
        begin button_n[2]<=0; repeat(8) @(posedge clk); button_n[2]<=1; repeat(8) @(posedge clk); end
    endtask
    task press_sustain;
        begin button_n[1]<=0; repeat(8) @(posedge clk); button_n[1]<=1; repeat(8) @(posedge clk); end
    endtask
    task press_mode;
        begin button_n[0]<=0; repeat(8) @(posedge clk); button_n[0]<=1; repeat(8) @(posedge clk); end
    endtask
    task rotate_down;
        begin step<=-1; step_valid<=1; @(posedge clk); step_valid<=0; step<=0; repeat(2) @(posedge clk); end
    endtask
    task long_panic;
        begin button_n[0]<=0; repeat(36) @(posedge clk); if(!muting) $fatal(1,"long press did not mute"); button_n[0]<=1; repeat(5) @(posedge clk); end
    endtask
    always @(posedge clk) begin
        if(final_valid) begin valid_count=valid_count+1; if(final_sample!=0) nonzero_count=nonzero_count+1; end
    end
    initial begin
        valid_count=0;nonzero_count=0;
        repeat(8) @(posedge clk); rst<=0;
        repeat(5) @(posedge clk);
        snapshot(16'h0001); repeat(120) @(posedge clk);
        press_sustain(); if(!sustain) $fatal(1,"sustain button did not set");
        rotate_down(); if(volume_index!=23) $fatal(1,"encoder volume step failed: %0d",volume_index);
        press_mode(); if(!release_mode) $fatal(1,"mode button did not select release control");
        rotate_down();
        press_mode(); if(release_mode) $fatal(1,"mode button did not return to volume control");
        snapshot(16'h0000);
        repeat(80) @(posedge clk); press_timbre();
        snapshot(16'h0002); repeat(2200) @(posedge clk); snapshot(16'h0000);
        repeat(150) @(posedge clk);
        long_panic();
        if(valid_count<10 || nonzero_count<5) $fatal(1,"engine output missing valid=%0d nonzero=%0d",valid_count,nonzero_count);
        if(timbre!==1) $fatal(1,"timbre button did not select pluck: %0d",timbre);
        $display("FINAL_ENGINE_TB_PASS valid=%0d nonzero=%0d timbre=%0d",valid_count,nonzero_count,timbre);
        $finish;
    end
endmodule

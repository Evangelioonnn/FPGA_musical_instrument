`timescale 1ns/1ps
// Bit-exact comparison of the shared default-sine bank against the
// resource-pruned production reference. Events are sent only when both banks
// are ready, so the two implementations see identical transaction boundaries.
module resource_shared_sine_compare_tb;
    reg clk=0,rst=1,sample_ce=0,event_valid=0,event_off=0,pedal=0;
    reg [31:0] token=0; reg [6:0] note=60; reg [1:0] timbre=0;
    reg [15:0] reference_release=16'd3; reg [2:0] fm_release=3'd3;
    wire ref_ready,shared_ready;
    wire ref_acc,ref_rej,shared_acc,shared_rej;
    wire ref_valid,shared_valid; wire signed [15:0] ref_sample,shared_sample;
    wire ref_clip,shared_clip,ref_deadline,shared_deadline;
    wire [7:0] ref_occupied,ref_held,shared_occupied,shared_held;
    wire [31:0] ref_rejects,ref_unmatched,shared_rejects,shared_unmatched;
    integer cycles=0,ref_count=0,shared_count=0,compared=0,mismatches=0;
    integer accepted_ref=0,accepted_shared=0;
    reg signed [15:0] ref_frames[0:1023];
    reg signed [15:0] shared_frames[0:1023];

    always #5 clk=~clk;
    always @(posedge clk) begin
        cycles<=cycles+1;
        sample_ce<=(!rst && cycles>20 && cycles%80==0);
        if(ref_acc) accepted_ref<=accepted_ref+1;
        if(shared_acc) accepted_shared<=accepted_shared+1;
        if(ref_valid) begin ref_frames[ref_count]<=ref_sample; ref_count<=ref_count+1; end
        if(shared_valid) begin shared_frames[shared_count]<=shared_sample; shared_count<=shared_count+1; end
        if(compared<ref_count && compared<shared_count) begin
            if(ref_frames[compared]!==shared_frames[compared]) mismatches<=mismatches+1;
            compared<=compared+1;
        end
        if(cycles==5) rst<=0;
        if(cycles==50000) begin
            if(accepted_ref!=accepted_shared || accepted_ref<3 || ref_count<300 || shared_count<300 ||
                ref_deadline || shared_deadline || ref_clip || shared_clip ||
                ref_rejects!=0 || shared_rejects!=0 || ref_unmatched!=0 || shared_unmatched!=0 ||
                mismatches!=0) begin
                $display("SHARED_SINE_COMPARE_FAIL accepted=%0d/%0d frames=%0d/%0d compared=%0d mismatches=%0d",
                    accepted_ref,accepted_shared,ref_count,shared_count,compared,mismatches);
                $finish(1);
            end
            $display("SHARED_SINE_COMPARE_PASS accepted=%0d frames=%0d compared=%0d exact=1",
                accepted_ref,compared,compared);
            $finish;
        end
    end

    task send_event;
        input integer is_off;
        input integer id;
        input integer key;
        begin
            @(negedge clk);
            while(!(ref_ready && shared_ready)) @(negedge clk);
            event_off=is_off; token=id; note=key; timbre=0; event_valid=1;
            @(negedge clk); event_valid=0; event_off=0;
        end
    endtask

    initial begin
        repeat(5) @(negedge clk);
        send_event(0,1,60); repeat(30) @(negedge clk);
        send_event(0,2,64); repeat(50) @(negedge clk);
        send_event(1,1,60); repeat(25) @(negedge clk);
        send_event(0,3,67); repeat(50) @(negedge clk);
        send_event(1,2,64); repeat(50) @(negedge clk);
        send_event(1,3,67); repeat(500) @(negedge clk);
    end
    initial begin #1000000; $fatal(1,"compare timeout"); end

    resource_pruned_bank #(.N(8)) reference(
        clk,rst,sample_ce,event_valid,ref_ready,event_off,token,note,timbre,
        pedal,reference_release,fm_release,ref_acc,ref_rej,ref_rejects,ref_unmatched,
        ref_occupied,ref_held,ref_valid,ref_sample,ref_clip,ref_deadline);
    resource_shared_sine_bank #(.N(8)) shared(
        clk,rst,sample_ce,event_valid,shared_ready,event_off,token,note,timbre,
        pedal,reference_release,fm_release,shared_acc,shared_rej,shared_rejects,shared_unmatched,
        shared_occupied,shared_held,shared_valid,shared_sample,shared_clip,shared_deadline);
endmodule

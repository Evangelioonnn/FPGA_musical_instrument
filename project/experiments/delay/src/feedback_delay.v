// Sample-rate feedback delay.  The memory is deliberately not reset so that
// synthesis can infer BSRAM; fill_count masks unread history after reset.
// One accepted input sample produces one output sample on the following clock.
module feedback_delay #(parameter DEPTH=4096, parameter DELAY=4096,
    parameter FEEDBACK_Q15=24576, parameter WET_Q15=16384,
    parameter PTR_W=(DEPTH>1?$clog2(DEPTH):1))(
    input wire clk,rst,input wire in_valid,input wire bypass,
    input wire signed [15:0] in_sample,output wire in_ready,
    output reg out_valid,output reg signed [15:0] out_sample,output reg clipped
);
    reg signed [15:0] mem[0:DEPTH-1];
    reg [PTR_W-1:0] wr_ptr;
    reg [PTR_W:0] fill_count;
    reg pending,held_bypass;
    reg signed [15:0] held_sample,delayed_reg;
    reg [PTR_W-1:0] held_ptr;
    reg [15:0] wet,held_wet;
    wire [15:0] target=bypass ? 16'd0 : WET_Q15;
    wire [15:0] next_wet=wet<target ? (target-wet<=256 ? target : wet+16'd256) :
        (wet-target<=256 ? target : wet-16'd256);
    wire accept=in_valid && in_ready;
    wire history_valid=fill_count>=DELAY;
    // wr_ptr names the next write slot; the delayed sample is DELAY slots
    // behind it, not the slot about to be overwritten.
    wire [PTR_W-1:0] read_ptr=(wr_ptr>=DELAY) ? wr_ptr-DELAY : wr_ptr+(DEPTH-DELAY);
    wire signed [31:0] fb_product=delayed_reg*FEEDBACK_Q15;
    wire signed [32:0] wet_product=delayed_reg*$signed({1'b0,held_wet});
    wire signed [31:0] fb_term=fb_product<0 ? -((-fb_product)>>>15) : fb_product>>>15;
    wire signed [31:0] wet_term=wet_product<0 ? -((-wet_product)>>>15) : wet_product>>>15;
    wire signed [31:0] write_sum={{16{held_sample[15]}},held_sample}+fb_term;
    wire signed [31:0] dry_sum={{16{held_sample[15]}},held_sample}+wet_term;
    reg signed [15:0] write_value,output_value;
    reg write_clip,output_clip;
    function signed [15:0] sat16;
        input signed [31:0] x;
        begin
            if(x>32767) sat16=16'sh7fff;
            else if(x < -32768) sat16=-16'sh8000;
            else sat16=x[15:0];
        end
    endfunction
    assign in_ready=!rst && !pending;
    always @* begin
        write_value=sat16(write_sum); output_value=sat16(dry_sum);
        write_clip=(write_sum>32767)||(write_sum < -32768);
        output_clip=(dry_sum>32767)||(dry_sum < -32768);
    end
    always @(posedge clk) begin
        if(rst) begin
            wr_ptr<=0;fill_count<=0;pending<=0;held_bypass<=0;held_sample<=0;
            held_ptr<=0;delayed_reg<=0;wet<=0;held_wet<=0;out_valid<=0;out_sample<=0;clipped<=0;
        end else begin
            out_valid<=pending;clipped<=pending && output_clip;
            if(pending) begin
                mem[held_ptr]<=write_value;
                out_sample<=output_value;
            end
            pending<=0;
            if(accept) begin
                // Synchronous RAM read. The value is consumed on the next
                // clock together with this input sample.
                delayed_reg<=history_valid ? mem[read_ptr] : 16'sd0;
                held_sample<=in_sample;held_bypass<=bypass;held_ptr<=wr_ptr;
                wet<=next_wet;held_wet<=next_wet;
                pending<=1;
                if(fill_count<DEPTH) fill_count<=fill_count+1'b1;
                if(wr_ptr==DEPTH-1) wr_ptr<=0; else wr_ptr<=wr_ptr+1'b1;
            end
        end
    end
endmodule

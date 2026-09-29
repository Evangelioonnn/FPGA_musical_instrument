`timescale 1ns/1ps
module render_smoke_tb;
    render_tb #(.FRAME_COUNT(10000),.SECTION_COUNT(1),.CHECK_TAILS(0),.OUTPUT_PREFIX("smoke_")) smoke();
endmodule

`timescale 1ns/1ps
// Independent test tops allow concurrent rendering without sharing output files.
// Each still instantiates all eight physical slots and all three algorithms.
module render_reference_tb;
    render_tb #(.SECTION_FIRST(0),.SECTION_COUNT(1),
        .PASS_NAME("RENDER_REFERENCE_TB_PASS")) score();
endmodule
module render_pluck_tb;
    render_tb #(.SECTION_FIRST(1),.SECTION_COUNT(1),
        .PASS_NAME("RENDER_PLUCK_TB_PASS")) score();
endmodule
module render_fm_tb;
    render_tb #(.SECTION_FIRST(2),.SECTION_COUNT(1),
        .PASS_NAME("RENDER_FM_TB_PASS")) score();
endmodule

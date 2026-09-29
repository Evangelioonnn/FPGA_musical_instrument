`timescale 1ns/1ps
module sine_rom_equivalence_tb;
    reg clk=0;always #10 clk=~clk;
    reg [11:0] address=12'hxxx;
    wire signed [15:0] original,array_sample;
    reg signed [15:0] previous;
    reg [31:0] seed=32'h2891ac73;
    integer i,checks=0;
    palette_sine_reference reference(clk,address,original);
    palette_sine replacement(clk,address,array_sample);
    task compare_address;
        input [11:0] next_address;
        begin
            @(negedge clk);previous=original;address=next_address;
            @(posedge clk);#1;
            if(original!==array_sample) begin
                $display("ROM mismatch addr=%b reference=%h replacement=%h",address,original,array_sample);$fatal;
            end
            if((^address)===1'bx && (original!==previous || array_sample!==previous))
                $fatal(1,"Unknown ROM address did not retain previous output");
            checks=checks+1;
        end
    endtask
    initial begin
        #1;if(original!==16'd0 || array_sample!==16'd0)$fatal(1,"ROM initial output changed");
        for(i=0;i<4096;i=i+1)compare_address(i);
        compare_address(12'hxxx);compare_address(12'hzzz);
        compare_address(12'b0000x0000000);compare_address(12'b1000000z0011);
        compare_address(12'bx11111111111);compare_address(12'bz00000000000);
        compare_address(12'b1x0z01010101);compare_address(12'bzzxxzzxxzzxx);
        for(i=0;i<2048;i=i+1) begin
            seed=seed^(seed<<13);seed=seed^(seed>>17);seed=seed^(seed<<5);
            compare_address(seed[11:0]);
        end
        $display("SINE_ROM_ARRAY_EQUIVALENCE_PASS addresses=4096 unknown=8 jumps=2048 initial=0 checks=%0d",checks);$finish;
    end
    initial begin #200000;$fatal(1,"Short ROM equivalence test timed out");end
endmodule

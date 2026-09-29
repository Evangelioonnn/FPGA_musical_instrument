`timescale 1ns/1ps
module gain_tb;
    reg signed [15:0] value;
    wire signed [15:0] out0,out1,out2;
    wire clip0,clip1,clip2;
    integer input_value,expected0,expected1,expected2,clip_count1,clip_count2;
    noise_gain_stage #(.SHIFT(0)) g0(value,out0,clip0);
    noise_gain_stage #(.SHIFT(1)) g1(value,out1,clip1);
    noise_gain_stage #(.SHIFT(2)) g2(value,out2,clip2);

    function integer saturate;
        input integer x,shift;
        integer scaled;
        begin
            scaled=x*(1<<shift);
            if(scaled>32767) saturate=32767;
            else if(scaled< -32768) saturate=-32768;
            else saturate=scaled;
        end
    endfunction

    function clip_expected;
        input integer x,shift;
        integer scaled;
        begin
            scaled=x*(1<<shift);
            clip_expected=(scaled>32767)||(scaled< -32768);
        end
    endfunction

    initial begin
        clip_count1=0;clip_count2=0;
        for(input_value=-32768;input_value<=32767;input_value=input_value+1) begin
            value=input_value;#1;
            expected0=saturate(input_value,0);
            expected1=saturate(input_value,1);
            expected2=saturate(input_value,2);
            if($signed(out0)!==expected0 || $signed(out1)!==expected1 ||
                $signed(out2)!==expected2) $fatal(1,"gain mismatch input=%0d",input_value);
            if(clip0!==clip_expected(input_value,0) ||
                clip1!==clip_expected(input_value,1) ||
                clip2!==clip_expected(input_value,2)) $fatal(1,"clip mismatch input=%0d",input_value);
            if(clip1) clip_count1=clip_count1+1;
            if(clip2) clip_count2=clip_count2+1;
        end
        if(clip_count1==0 || clip_count2<=clip_count1) $fatal(1,"missing saturation coverage");
        $display("GAIN_TB_PASS all_signed_16bit_inputs=65536 x2_clipped=%0d x4_clipped=%0d",clip_count1,clip_count2);
        $finish;
    end
endmodule

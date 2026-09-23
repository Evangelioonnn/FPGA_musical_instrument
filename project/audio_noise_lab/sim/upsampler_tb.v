`timescale 1ns/1ps
module noise_upsampler_test #(parameter OSR=2)(output reg done=0);
    reg clk=0,rst=1,frame_ce=0,rendered_valid=0;
    reg signed [15:0] rendered_sample=0;
    wire render_ce,gain_clipped;
    wire signed [15:0] dac_sample;
    integer frame_index,segment,phase,expected,previous,current,numerator;
    reg trigger;
    always #10 clk=~clk;
    noise_audio_output #(.OSR(OSR),.GAIN_SHIFT(0)) dut(
        clk,rst,frame_ce,rendered_valid,rendered_sample,
        render_ce,dac_sample,gain_clipped);

    function integer base_sample;
        input integer index;
        begin
            case(index)
                0:base_sample=-1001;
                1:base_sample=32767;
                2:base_sample=-32768;
                3:base_sample=12345;
                default:base_sample=0;
            endcase
        end
    endfunction

    function integer floor_fraction;
        input integer value,divisor;
        integer magnitude;
        begin
            if(value>=0) floor_fraction=value/divisor;
            else begin
                magnitude=-value;
                floor_fraction=-((magnitude+divisor-1)/divisor);
            end
        end
    endfunction

    task send_frame;
        input integer index;
        begin
            segment=index/OSR;phase=index%OSR;
            if(phase==0) expected=(segment==0)?0:base_sample(segment-1);
            else begin
                previous=(segment==0)?0:base_sample(segment-1);
                current=base_sample(segment);
                numerator=(current-previous)*phase;
                expected=previous+floor_fraction(numerator,OSR);
            end
            @(negedge clk);frame_ce=1;
            #1;
            if(render_ce!==(phase==0)) $fatal(1,"OSR%0d render cadence frame=%0d",OSR,index);
            if($signed(dac_sample)!==expected)
                $fatal(1,"OSR%0d interpolation frame=%0d got=%0d expected=%0d",OSR,index,$signed(dac_sample),expected);
            trigger=render_ce;
            @(posedge clk);
            @(negedge clk);frame_ce=0;
            if(trigger) begin
                rendered_sample=base_sample(segment);rendered_valid=1;
                @(posedge clk);
                @(negedge clk);rendered_valid=0;
            end
            repeat(1) @(negedge clk);
        end
    endtask

    initial begin
        trigger=0;repeat(4) @(negedge clk);rst=0;
        for(frame_index=0;frame_index<=OSR*4;frame_index=frame_index+1)
            send_frame(frame_index);
        if(gain_clipped) $fatal(1,"Unexpected clipping");
        done=1;
    end
endmodule

module upsampler2_tb;
    wire done;
    noise_upsampler_test #(.OSR(2)) test(done);
    initial begin wait(done);$display("UPSAMPLER2_TB_PASS frames=9 values=independent_signed_oracle");$finish;end
    initial begin #100000;$fatal(1,"upsampler2 timeout");end
endmodule

module upsampler4_tb;
    wire done;
    noise_upsampler_test #(.OSR(4)) test(done);
    initial begin wait(done);$display("UPSAMPLER4_TB_PASS frames=17 values=independent_signed_oracle");$finish;end
    initial begin #100000;$fatal(1,"upsampler4 timeout");end
endmodule

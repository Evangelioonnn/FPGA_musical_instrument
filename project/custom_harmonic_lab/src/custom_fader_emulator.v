// Temporary EC11 adapter for exercising the five future ADC slider channels.
// It changes the same 12-bit channel snapshot contract used by the SPI ADC.
module custom_fader_emulator #(
    parameter [11:0] DEFAULT_CH0=12'hfff,
    parameter [11:0] DEFAULT_CH1=12'hfff,
    parameter [11:0] DEFAULT_CH2=12'd1024,
    parameter [11:0] DEFAULT_CH3=12'd512,
    parameter [11:0] DEFAULT_CH4=12'd256,
    parameter [11:0] STEP_SIZE=12'd64
) (
    input wire clk,rst,
    input wire active,
    input wire step_valid,
    input wire signed [1:0] step,
    input wire [2:0] channel,
    output reg adc_valid,
    output reg [11:0] adc_ch0,adc_ch1,adc_ch2,adc_ch3,adc_ch4
);
    function [11:0] increment;
        input [11:0] value;
        begin
            increment = value > (12'hfff-STEP_SIZE) ? 12'hfff : value+STEP_SIZE;
        end
    endfunction
    function [11:0] decrement;
        input [11:0] value;
        begin
            decrement = value < STEP_SIZE ? 12'd0 : value-STEP_SIZE;
        end
    endfunction
    always @(posedge clk) begin
        if(rst) begin
            adc_valid<=0;
            adc_ch0<=DEFAULT_CH0;adc_ch1<=DEFAULT_CH1;adc_ch2<=DEFAULT_CH2;
            adc_ch3<=DEFAULT_CH3;adc_ch4<=DEFAULT_CH4;
        end else begin
            adc_valid<=0;
            if(active && step_valid && step!=0) begin
                case(channel)
                    0: adc_ch0<=step>0 ? increment(adc_ch0) : decrement(adc_ch0);
                    1: adc_ch1<=step>0 ? increment(adc_ch1) : decrement(adc_ch1);
                    2: adc_ch2<=step>0 ? increment(adc_ch2) : decrement(adc_ch2);
                    3: adc_ch3<=step>0 ? increment(adc_ch3) : decrement(adc_ch3);
                    4: adc_ch4<=step>0 ? increment(adc_ch4) : decrement(adc_ch4);
                    default: adc_valid<=0;
                endcase
                if(channel<=4) adc_valid<=1;
            end
        end
    end
endmodule

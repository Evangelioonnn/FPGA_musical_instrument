// Both stereo channels use the same transform, never an L/R phase split.
module output_polarity #(parameter INVERT=0)(
    input wire signed [15:0] sample_in,output wire signed [15:0] sample_out
);
    assign sample_out=!INVERT ? sample_in :
        sample_in==16'sh8000 ? 16'sh7fff : -sample_in;
endmodule

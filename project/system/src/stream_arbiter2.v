// Fair arbitration with locked selection while backpressured.
module stream_arbiter2 #(parameter WIDTH=36)(
    input wire clk,rst,flush,
    input wire a_valid,input wire [WIDTH-1:0] a_data,output wire a_ready,
    input wire b_valid,input wire [WIDTH-1:0] b_data,output wire b_ready,
    output wire out_valid,output wire [WIDTH-1:0] out_data,
    output wire selected_b,input wire out_ready
);
    reg prefer_b,locked,grant_b;
    wire choice=locked ? grant_b : (a_valid && b_valid ? prefer_b : b_valid);
    assign selected_b=choice;
    assign out_valid=!rst && !flush && (choice ? b_valid : a_valid);
    assign out_data=choice ? b_data : a_data;
    assign a_ready=!rst && !flush && !choice && out_ready;
    assign b_ready=!rst && !flush && choice && out_ready;
    always @(posedge clk) begin
        if(rst || flush) begin prefer_b<=0;locked<=0;grant_b<=0;end
        else if(out_valid) begin
            if(out_ready) begin locked<=0;prefer_b<=!choice;end
            else begin locked<=1;grant_b<=choice;end
        end
    end
endmodule

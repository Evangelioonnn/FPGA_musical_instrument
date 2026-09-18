// Bundled-data toggle handshake: payload stays stable from request through ack.
// Both resets must describe the SAME link-reset epoch; independent reset is unsupported.
module snapshot_cdc #(parameter WIDTH=128)(
    input wire src_clk,src_rst,src_valid,input wire [WIDTH-1:0] src_data,
    output wire src_ready,output reg [31:0] dropped,
    input wire dst_clk,dst_rst,output reg dst_valid,output reg [WIDTH-1:0] dst_data
);
    reg [WIDTH-1:0] holding;
    reg request,ack,ack1,ack2,req1,req2;
    assign src_ready=!src_rst && request==ack2;
    always @(posedge src_clk) begin
        if(src_rst) begin holding<=0;request<=0;ack1<=0;ack2<=0;dropped<=0;end
        else begin
            ack1<=ack;ack2<=ack1;
            if(src_valid) begin
                if(src_ready) begin holding<=src_data;request<=!request;end
                else dropped<=dropped+1'b1;
            end
        end
    end
    always @(posedge dst_clk) begin
        if(dst_rst) begin req1<=0;req2<=0;ack<=0;dst_valid<=0;dst_data<=0;end
        else begin
            req1<=request;req2<=req1;dst_valid<=0;
            if(req2!=ack) begin dst_data<=holding;dst_valid<=1;ack<=req2;end
        end
    end
endmodule

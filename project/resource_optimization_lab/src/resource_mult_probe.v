// Exact arithmetic probe for sharing one signed 32x32 multiplier across eight
// voice contexts. It models the primitive needed by FM/envelope scheduling;
// it is not yet a drop-in FM voice because FM has several dependent products.
module shared_mult8_probe(
    input wire clk,rst,sample_ce,
    input wire [255:0] a_bus,input wire [255:0] b_bus,
    output reg out_valid,output reg [511:0] product_bus
);
    reg [255:0] a_hold,b_hold;
    reg running,drain;
    reg [3:0] index;
    reg signed [63:0] product;
    reg [2:0] product_index;
    wire signed [31:0] current_a=$signed(a_hold[index*32 +: 32]);
    wire signed [31:0] current_b=$signed(b_hold[index*32 +: 32]);
    always @(posedge clk) begin
        if(rst) begin
            a_hold<=0;b_hold<=0;running<=0;drain<=0;index<=0;product<=0;
            product_index<=0;product_bus<=0;out_valid<=0;
        end else begin
            out_valid<=0;
            if(sample_ce && !running && !drain) begin
                a_hold<=a_bus;b_hold<=b_bus;running<=1;index<=0;
            end else if(running) begin
                product<=current_a*current_b;
                product_index<=index[2:0];
                if(index==7) begin running<=0;drain<=1;end
                else index<=index+1'b1;
                // The product register is consumed one cycle later by the
                // same tagged index, so this scheduler has one extra drain.
                if(index!=0) product_bus[product_index*64 +: 64]<=product;
            end else if(drain) begin
                product_bus[product_index*64 +: 64]<=product;
                out_valid<=1;drain<=0;
            end
        end
    end
endmodule

module duplicated_mult8_probe(
    input wire clk,rst,sample_ce,
    input wire [255:0] a_bus,input wire [255:0] b_bus,
    output reg out_valid,output reg [511:0] product_bus
);
    wire signed [63:0] products[0:7];
    genvar g;
    generate for(g=0;g<8;g=g+1) begin: mults
        assign products[g]=$signed(a_bus[g*32 +: 32])*$signed(b_bus[g*32 +: 32]);
    end endgenerate
    integer i;
    always @(posedge clk) begin
        if(rst) begin out_valid<=0;product_bus<=0;end
        else begin
            out_valid<=sample_ce;
            if(sample_ce) for(i=0;i<8;i=i+1) product_bus[i*64 +: 64]<=products[i];
        end
    end
endmodule

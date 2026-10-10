`timescale 1ns/1ps
// Oracle uses signed division, independent of the shift/correction circuit.
module pluck_truncation_tb;
    reg clk=0;always #10 clk=~clk;
    reg signed [59:0] product=0;
    audio_v2_pluck dut(.clk(clk),.rst(1'b1),.sample_ce(1'b0),
        .cmd_valid(1'b0),.cmd_kind(2'd0),.note(7'd60),.velocity(9'd256),
        .seed(32'd1),.table_length(10'd184),.table_fraction(16'd0),
        .table_reciprocal(25'd1),.math_grant(1'b0),.shared_math_product(product));
    reg signed [63:0] x,expected;
    reg [63:0] rng=64'hf8a294515df80373;
    integer count=0,i,j;
    task check_feedback;
        input signed [63:0] value;
        begin
            @(negedge clk);product=value;@(posedge clk);#1;
            x={{23{product[40]}},product[40:0]};expected=x/64'sd65536;
            if($signed(dut.feedback_shift)!==expected)
                $fatal(1,"feedback x=%0d actual=%0d expected=%0d",x,dut.feedback_shift,expected);
            count=count+1;
        end
    endtask
    task check_release;
        input signed [63:0] value;
        begin
            @(negedge clk);product=value;@(posedge clk);#1;
            x={{30{product[33]}},product[33:0]};expected=x/64'sd65536;
            if($signed(dut.output_shift)!==expected)
                $fatal(1,"release x=%0d actual=%0d expected=%0d",x,dut.output_shift,expected);
            count=count+1;
        end
    endtask
    initial begin
        // Every low-16-bit residue around both sides of zero and PCM minimum.
        for(i=0;i<65536;i=i+1) begin
            check_feedback(-64'sd65536-i);check_feedback(i);
            check_release(-64'sd2147483648-i);check_release(i);
        end
        check_feedback(-64'sd1099511627776);check_feedback(64'sd1099511627775);
        check_release(-64'sd8589934592);check_release(64'sd8589934591);
        check_feedback(-1);check_release(-1);check_feedback(0);check_release(0);
        for(j=0;j<20000;j=j+1) begin
            rng=rng^(rng<<13);rng=rng^(rng>>7);rng=rng^(rng<<17);
            check_feedback(rng);check_release(rng);
        end
        $display("PLUCK_TRUNCATION_TB_PASS division_oracle cases=%0d signed_min_and_all_residues",count);
        $finish;
    end
endmodule

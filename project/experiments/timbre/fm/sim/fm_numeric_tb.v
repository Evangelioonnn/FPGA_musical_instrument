`timescale 1ns/1ps
module fm_numeric_tb;
reg clk=0; always #10 clk=~clk;
reg rst=1, sample_ce=0, cmd_valid=0;
reg [1:0] cmd_kind=0;
reg [6:0] note=60;
reg [8:0] velocity=205;
wire cmd_ready, cmd_rejected, active, sample_valid;
wire signed [15:0] sample;
fm_voice dut(.clk(clk),.rst(rst),.sample_ce(sample_ce),.cmd_valid(cmd_valid),
    .cmd_kind(cmd_kind),.note(note),.velocity(velocity),.seed(32'd1),
    .cmd_ready(cmd_ready),.cmd_rejected(cmd_rejected),.active(active),
    .sample(sample),.sample_valid(sample_valid));
integer vectors, output_file, result, id, pitch, vel, count, gate, n;
integer latency, max_latency=0, samples=0;
task command;
    input [1:0] kind;
    input integer pitch_in, vel_in;
    begin
        @(negedge clk); cmd_kind=kind; note=pitch_in; velocity=vel_in; cmd_valid=1;
        while (!cmd_ready) @(negedge clk);
        @(posedge clk); #1;
        if(cmd_rejected) begin $display("FAIL numeric command rejected"); $fatal(1,"FM simulation failure"); end
        @(negedge clk); cmd_valid=0;
    end
endtask
task tick;
    begin
        @(negedge clk); sample_ce=1;
        @(posedge clk); #1; latency=0;
        if(sample_valid) begin
            $fdisplay(output_file,"%0d %0d %0d",id,n,$signed(sample)); samples=samples+1;
        end else begin
            @(negedge clk); sample_ce=0;
            while(!sample_valid && latency<64) begin @(posedge clk); #1; latency=latency+1; end
            if(!sample_valid) begin $display("FAIL sample deadline"); $fatal(1,"FM simulation failure"); end
            $fdisplay(output_file,"%0d %0d %0d",id,n,$signed(sample)); samples=samples+1;
        end
        if(latency>max_latency) max_latency=latency;
        @(negedge clk); sample_ce=0;
        // Numeric rendering uses >=20 system clocks per sample. The physical
        // 1040-clock / PT8211 schedule is checked by the shared board probe test.
        repeat(3) @(negedge clk);
    end
endtask
initial begin
    vectors=$fopen("fm_cases.txt","r"); output_file=$fopen("fm_numeric_samples.txt","w");
    if(!vectors || !output_file) begin $display("FAIL files"); $fatal(1,"FM simulation failure"); end
    repeat(5) @(negedge clk); rst=0;
    while(!$feof(vectors)) begin
        result=$fscanf(vectors,"%d %d %d %d %d\n",id,pitch,vel,count,gate);
        if(result==5) begin
            command(2,pitch,vel); command(0,pitch,vel);
            for(n=0;n<count;n=n+1) begin
                if(n==gate) command(1,pitch,vel);
                tick;
            end
        end
    end
    $fclose(vectors);$fclose(output_file);
    $display("FM_NUMERIC_TB_PASS samples=%0d max_latency=%0d",samples,max_latency);
    $finish;
end
initial begin #3000000000.0; $display("FAIL numeric timeout"); $fatal(1,"FM simulation failure"); end
endmodule

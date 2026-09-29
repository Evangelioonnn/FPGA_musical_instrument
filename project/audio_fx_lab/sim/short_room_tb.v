`timescale 1ns/1ps
module short_room_tb #(parameter FRAME_CLOCKS=1040);
    reg clk=0;
    always #10 clk=~clk;
    reg rst=1, in_valid=0, fx_enable=0;
    reg signed [15:0] in_sample=0;
    reg [8:0] wet_q8=0;
    wire out_valid,clip,ready,busy,overrun;
    wire signed [15:0] out_left,out_right;
    wire [8:0] wet_applied;
    short_room_reverb dut(clk,rst,in_valid,in_sample,fx_enable,wet_q8,
        out_valid,out_left,out_right,clip,ready,busy,overrun,wet_applied);
    integer input_file,output_file,scan_count,value,enabled,wet;
    integer frame_index=0,clock_index=0,accepted_clock=0,accepted_ready=0;
    integer outputs=0;
    always @(posedge clk) begin
        clock_index=clock_index+1;
        if(in_valid) begin accepted_clock=clock_index; accepted_ready=ready; end
        #1;
        if(out_valid) begin
            if(clock_index-accepted_clock != 24) begin
                $display("FX_FAIL latency=%0d",clock_index-accepted_clock); $finish;
            end
            if(^out_left === 1'bx || ^out_right === 1'bx || clip || overrun) begin
                $display("FX_FAIL X/clip/overrun frame=%0d",outputs); $finish;
            end
            $fwrite(output_file,"%0d %0d %0d %0d %0d %0d\n",
                outputs,accepted_ready,wet_applied,out_left,out_right,clock_index-accepted_clock);
            outputs=outputs+1;
        end
    end
    initial begin
        input_file=$fopen("fx_vectors.txt","r");
        output_file=$fopen("fx_output.txt","w");
        if(input_file==0 || output_file==0) begin $display("FX_FAIL files");$finish;end
        repeat(5) @(negedge clk);
        rst=0;
        while(!$feof(input_file)) begin
            scan_count=$fscanf(input_file,"%d %d %d\n",value,enabled,wet);
            if(scan_count==3) begin
                in_sample=value;fx_enable=enabled;wet_q8=wet;in_valid=1;
                @(negedge clk);in_valid=0;
                repeat(FRAME_CLOCKS-1) @(negedge clk);
                frame_index=frame_index+1;
            end
        end
        if(outputs != frame_index) begin $display("FX_FAIL output count");$finish;end
        $fclose(input_file);$fclose(output_file);
        $display("SHORT_ROOM_TB_PASS frames=%0d latency=24",outputs);
        $finish;
    end
endmodule

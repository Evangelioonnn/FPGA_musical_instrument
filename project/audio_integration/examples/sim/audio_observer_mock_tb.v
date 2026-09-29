`timescale 1ns/1ps
module audio_observer_mock_tb;
    reg clk=0,rst=1;
    always #10 clk=~clk;
    wire pcm_valid,snapshot_valid;
    wire signed [15:0] pcm_left,pcm_right;
    wire [31:0] pcm_index;
    wire [2367:0] snapshot_data;
    wire [255:0] snapshot_extension;
    wire [24:0] snapshot_keys;
    wire [127:0] capabilities;
    audio_observer_mock #(.FRAME_CYCLES(4),.SNAPSHOT_FRAMES(3)) mock(.*);
    integer samples=0,snapshots=0,expected;
    always @(posedge clk) begin
        #1;
        if(!rst && pcm_valid) begin
            expected=((samples&2048)!=0 ? (2047-(samples&2047)) : (samples&2047))*16-16384;
            if(pcm_index!==samples || pcm_left!==expected || pcm_right!==expected) begin
                $display("MOCK_FAIL sample/index expected=%0d index=%0d pcm=%0d",expected,pcm_index,pcm_left);$stop;
            end
            samples=samples+1;
        end
        if(!rst && snapshot_valid) begin
            if(snapshot_data[31:0]!==snapshots || snapshot_extension[31:0]!==samples-1 ||
                snapshot_keys!==(25'b1<<(snapshots%25)) ||
                snapshot_data[80:64]!==17'd8249 || snapshot_data[362]!==1'b1 ||
                snapshot_data[358:352]!==48+(snapshots%25)) begin
                $display("MOCK_FAIL coherent state seq=%0d samples=%0d",snapshots,samples);$stop;
            end
            snapshots=snapshots+1;
        end
    end
    initial begin
        repeat(3) @(negedge clk);rst=0;
        repeat(17000) @(negedge clk);
        if(samples!=4250 || snapshots!=1416 || capabilities[63:48]!=25 || capabilities[31:16]!=32 ||
            capabilities[111:96]!=2368) begin
            $display("MOCK_FAIL counts samples=%0d snapshots=%0d",samples,snapshots);$stop;
        end
        $display("AUDIO_OBSERVER_MOCK_TB_PASS samples=%0d snapshots=%0d independent_triangle_and_coherent_keys",samples,snapshots);
        $finish;
    end
endmodule

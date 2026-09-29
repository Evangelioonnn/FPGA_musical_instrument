// Resource probe: eight dynamic phase accumulators share one synchronous ROM.
// The scheduler uses ten system clocks per audio sample, far below the 1040
// clocks available at the current PT8211 rate. Envelope and event state are
// intentionally outside this first probe; the testbench compares waveform
// samples exactly before adding those state machines.
module shared_sine8_probe(
    input wire clk,rst,sample_ce,
    input wire [7:0] active,
    input wire [255:0] phase_step_bus,
    output reg out_valid,output reg signed [31:0] mix_sample
);
    reg [31:0] phase[0:7];
    reg [9:0] rom_addr;
    wire signed [15:0] rom_data;
    sine_rom shared_rom(clk,rom_addr,rom_data);
    reg running;
    reg [1:0] issue_pipe;
    reg [3:0] issue_count;
    reg [2:0] issue_index,idx_pipe0,idx_pipe1;
    reg signed [15:0] samples[0:7];
    reg [3:0] collected;
    wire signed [31:0] frame_sum =
        $signed({{16{samples[0][15]}},samples[0]}) +
        $signed({{16{samples[1][15]}},samples[1]}) +
        $signed({{16{samples[2][15]}},samples[2]}) +
        $signed({{16{samples[3][15]}},samples[3]}) +
        $signed({{16{samples[4][15]}},samples[4]}) +
        $signed({{16{samples[5][15]}},samples[5]}) +
        $signed({{16{samples[6][15]}},samples[6]}) +
        $signed({{16{samples[7][15]}},samples[7]});
    integer i;
    always @(posedge clk) begin
        if(rst) begin
            rom_addr<=0;running<=0;issue_pipe<=0;issue_count<=0;issue_index<=0;
            idx_pipe0<=0;idx_pipe1<=0;collected<=0;out_valid<=0;mix_sample<=0;
            for(i=0;i<8;i=i+1) begin phase[i]<=0;samples[i]<=0;end
        end else begin
            out_valid<=0;
            if(sample_ce && !running) begin
                running<=1;issue_pipe<=0;issue_count<=0;issue_index<=0;
                collected<=0;
            end else if(running) begin
                if(issue_pipe[1]) begin
                    samples[idx_pipe1]<=active[idx_pipe1] ? rom_data : 16'sd0;
                    collected<=collected+1'b1;
                end
                issue_pipe[1]<=issue_pipe[0];
                idx_pipe1<=idx_pipe0;
                issue_pipe[0]<=0;
                if(issue_count<8) begin
                    rom_addr<=phase[issue_index][31:22];
                    idx_pipe0<=issue_index;issue_pipe[0]<=1;
                    issue_index<=issue_index+1'b1;issue_count<=issue_count+1'b1;
                end else if(!issue_pipe[1] && !issue_pipe[0] && collected==8) begin
                    running<=0;out_valid<=1;
                    mix_sample<=frame_sum;
                    for(i=0;i<8;i=i+1)
                        if(active[i]) phase[i]<=phase[i]+phase_step_bus[i*32 +: 32];
                end
            end
        end
    end
endmodule

// Structurally identical reference with eight independent ROMs. It is used
// only as a resource and sample-equivalence control for the shared probe.
module duplicated_sine8_probe(
    input wire clk,rst,sample_ce,
    input wire [7:0] active,
    input wire [255:0] phase_step_bus,
    output reg out_valid,output reg signed [31:0] mix_sample
);
    reg [31:0] phase[0:7];
    reg [9:0] addr[0:7];
    wire signed [15:0] rom_data[0:7];
    genvar g;
    generate for(g=0;g<8;g=g+1) begin: roms
        sine_rom rom(clk,addr[g],rom_data[g]);
    end endgenerate
    reg pending;
    reg [1:0] pipe;
    wire signed [31:0] dup_sum =
        $signed({{16{rom_data[0][15]}},rom_data[0]}) +
        $signed({{16{rom_data[1][15]}},rom_data[1]}) +
        $signed({{16{rom_data[2][15]}},rom_data[2]}) +
        $signed({{16{rom_data[3][15]}},rom_data[3]}) +
        $signed({{16{rom_data[4][15]}},rom_data[4]}) +
        $signed({{16{rom_data[5][15]}},rom_data[5]}) +
        $signed({{16{rom_data[6][15]}},rom_data[6]}) +
        $signed({{16{rom_data[7][15]}},rom_data[7]});
    integer i;
    always @(posedge clk) begin
        if(rst) begin
            pending<=0;pipe<=0;out_valid<=0;mix_sample<=0;
            for(i=0;i<8;i=i+1) begin phase[i]<=0;addr[i]<=0;end
        end else begin
            out_valid<=pipe[1];
            if(pipe[1]) begin
                mix_sample<=dup_sum;
            end
            pipe<={pipe[0],sample_ce};
            if(sample_ce) for(i=0;i<8;i=i+1) begin
                if(active[i]) begin
                    addr[i]<=phase[i][31:22];
                    phase[i]<=phase[i]+phase_step_bus[i*32 +: 32];
                end else begin addr[i]<=0;phase[i]<=phase[i];end
            end
        end
    end
endmodule

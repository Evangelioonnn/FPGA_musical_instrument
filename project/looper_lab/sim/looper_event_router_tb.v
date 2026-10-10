`timescale 1ns/1ps
module looper_event_router_tb;
    localparam VOICES = 4;
    reg [11:0] live_tick=0;wire [11:0] record_tick;wire record_busy;
    reg record_ready=1,bank_accepted=0,bank_rejected=0;
    reg flush_all=0,flush_valid=0,flush_whole_track=0;
    reg [1:0] flush_track=0,flush_layer=0;wire flushing;
    wire [1:0] drum_layer;wire [2:0] drum_track;
    reg clk = 0;
    always #10 clk = !clk;
    reg rst = 1;
    reg live_valid = 0;
    wire live_ready;
    reg live_off = 0;
    reg [31:0] live_token = 0;
    reg [6:0] live_note = 60;
    reg [2:0] live_preset = 0;
    reg recording = 0;
    wire record_valid;
    wire [1:0] record_kind;
    wire [6:0] record_note;
    wire [15:0] record_local_id;
    wire [7:0] record_velocity;
    reg loop_valid = 0;
    wire loop_ready;
    reg loop_off = 0;
    reg loop_drum = 0;
    reg [1:0] loop_track = 0;
    reg [1:0] loop_layer = 0;
    reg [15:0] loop_local_id = 0;
    reg [6:0] loop_note = 60;
    reg [7:0] loop_velocity = 127;
    reg [2:0] loop_preset = 0;
    reg [135:0] loop_patch = 0;
    reg bank_ready = 0;
    wire bank_valid, bank_off;
    wire [31:0] bank_token;
    wire [6:0] bank_note;
    wire [2:0] bank_preset;
    wire [2:0] bank_track;
    wire bank_loop;
    wire [135:0] bank_patch;
    reg drum_ready = 0;
    reg drum_accepted = 1;
    wire drum_valid;
    wire [3:0] drum_pad;
    wire [7:0] drum_velocity;
    wire [31:0] route_faults, unmatched_offs;
    reg [31:0] on_token1, on_token2;

    looper_event_router #(.VOICES(VOICES), .PATCH_W(136)) dut(.*);

    integer hits=0,drums=0,records=0;reg [31:0] first_token,second_token;
    always @(posedge clk) if(!rst) begin
        if(bank_valid && bank_ready) begin
            hits=hits+1;
            if(hits==1) first_token=bank_token;
            if(hits==2) begin second_token=bank_token;if(second_token==first_token || bank_track!=1) $fatal(1,"track identity collision");end
            if(hits==3 && (!bank_off || bank_token!=first_token)) $fatal(1,"off token mismatch");
        end
        if(drum_valid && drum_ready) begin
            drums=drums+1;if(drum_pad!=5 || drum_track!=(drums==1 ? 2 : 4) || bank_valid) $fatal(1,"drum routing mismatch");
        end
        if(record_valid) begin records=records+1;
            if(record_local_id!=1 || record_velocity!=255 || record_kind!=(records==1 ? 0 : 1)) $fatal(1,"record identity mismatch");
        end
    end
    task loop_command;
        input off;input [1:0] tr;input isdrum;
        begin
            @(negedge clk);loop_valid=1;loop_off=off;loop_track=tr;loop_layer=0;
            loop_local_id=11;loop_note=isdrum ? 5 : 60;loop_drum=isdrum;loop_velocity=127;
            #1;wait(loop_ready);@(posedge clk);#1;@(negedge clk);loop_valid=0;loop_drum=0;
        end
    endtask
    task live_command;
        input off;
        begin
            @(negedge clk);live_valid=1;live_off=off;live_token=7;live_note=64;live_preset=2;
            #1;wait(live_ready);@(posedge clk);#1;@(negedge clk);live_valid=0;
        end
    endtask
    initial begin
        #200000;$fatal(1,"router watchdog");
    end
    initial begin
        repeat(3) @(negedge clk);rst=0;bank_ready=1;drum_ready=1;
        loop_command(0,0,0);loop_command(0,1,0);
        @(negedge clk);bank_ready=0;
        fork loop_command(1,0,0);
            begin wait(bank_valid);repeat(4) begin @(negedge clk);
                if(!bank_valid || bank_token!=first_token || !bank_off) $fatal(1,"stalled payload changed");end
                bank_ready=1;
            end
        join
        loop_command(1,0,0);
        if(unmatched_offs!=1) $fatal(1,"unmatched off missing");
        loop_command(0,2,1);
        recording=1;repeat(2) @(negedge clk);live_command(0);live_command(1);
        recording=0;
        @(negedge clk);flush_all=1;@(negedge clk);flush_all=0;
        wait(flushing);wait(!flushing);
        if(dut.map_valid!=0 || records!=2 || drums!=1 || hits!=6 || route_faults!=0)
            $fatal(1,"router totals hits=%0d records=%0d drums=%0d faults=%0d map=%b",hits,records,drums,route_faults,dut.map_valid);
        recording=1;drum_accepted=0;
        @(negedge clk);live_valid=1;live_off=0;live_token=8;live_note=5;live_preset=6;
        wait(live_ready);@(posedge clk);#1;@(negedge clk);live_valid=0;
        if(records!=2 || drums!=2 || route_faults!=1) $fatal(1,"rejected drum was recorded or stalled");
        $display("LOOPER_EVENT_ROUTER_TB_PASS track_identity=isolated stalled_payload=stable flush=clean record_pair=1");$finish;
    end
endmodule

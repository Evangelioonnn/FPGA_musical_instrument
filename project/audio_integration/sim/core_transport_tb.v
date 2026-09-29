`timescale 1ns/1ps
module core_transport_tb;
    reg audio_clk=0,observer_clk=0,client_clk=0,arst=1;
    always #10 audio_clk=!audio_clk;
    always #7 observer_clk=!observer_clk;
    always #13 client_clk=!client_clk;
    reg [24:0] keys=0;
    reg changed=0;
    reg client_valid=0;
    reg [4:0] client_addr=0;
    reg [31:0] client_value=0;
    reg [15:0] client_tag=0;
    wire client_ready,reply_valid,reply_accepted,reply_applied;
    wire [4:0] reply_addr;
    wire [31:0] reply_value;
    wire [15:0] reply_tag;
    reg state_ready=1,pcm_ready=1;
    wire state_valid,state_first,state_last,state_session_start;
    wire [5:0] state_word_index;
    wire [63:0] state_data;
    wire pcm_valid,pcm_gap,pcm_session_start,pcm_overflow,command_protocol_error;
    wire signed [15:0] pcm_left,pcm_right,final_left,final_right;
    wire [31:0] pcm_index,pcm_drops,state_drops,sample_index;
    wire final_valid,deadline_missed;
    audio_integration_example dut(
        .audio_clk(audio_clk),.observer_clk(observer_clk),.client_clk(client_clk),.arst(arst),
        .keys(keys),.changed(changed),.ghost(1'b0),.all_released(keys==0),.button_n(3'b111),
        .step_valid(1'b0),.step(2'sd0),.adc_valid(1'b0),
        .adc_ch0(12'd0),.adc_ch1(12'd0),.adc_ch2(12'd0),.adc_ch3(12'd0),.adc_ch4(12'd0),
        .client_valid(client_valid),.client_ready(client_ready),.client_addr(client_addr),
        .client_value(client_value),.client_tag(client_tag),.reply_valid(reply_valid),.reply_ready(1'b1),
        .reply_addr(reply_addr),.reply_value(reply_value),.reply_tag(reply_tag),
        .reply_accepted(reply_accepted),.reply_applied(reply_applied),
        .state_valid(state_valid),.state_ready(state_ready),.state_data(state_data),
        .state_word_index(state_word_index),.state_first(state_first),.state_last(state_last),
        .state_session_start(state_session_start),.pcm_valid(pcm_valid),.pcm_ready(pcm_ready),
        .pcm_left(pcm_left),.pcm_right(pcm_right),.pcm_index(pcm_index),
        .pcm_gap(pcm_gap),.pcm_session_start(pcm_session_start),.pcm_drops(pcm_drops),
        .state_drops(state_drops),.pcm_overflow(pcm_overflow),.command_protocol_error(command_protocol_error),
        .final_valid(final_valid),.final_left(final_left),.final_right(final_right),
        .sample_index(sample_index),.deadline_missed(deadline_missed));
    wire view_valid;
    wire [31:0] view_sequence,view_pcm,view_revision;
    wire [24:0] view_keys;
    wire [16:0] view_master;
    wire [31:0] view_occupied,view_held,view_gated,malformed;
    wire [223:0] view_notes;
    wire [95:0] view_presets;
    audio_state_view view(.clk(observer_clk),.rst(arst),.in_valid(state_valid&&state_ready),
        .in_data(state_data),.in_word_index(state_word_index),.in_first(state_first),
        .in_last(state_last),.in_session_start(state_session_start),.view_valid(view_valid),
        .transport_sequence(view_sequence),.pcm_index(view_pcm),.parameter_revision(view_revision),
        .keys(view_keys),.master_target(view_master),.occupied(view_occupied),.held(view_held),
        .gated(view_gated),.notes(view_notes),.presets(view_presets),.malformed_records(malformed));
    reg [63:0] expected_pcm[0:8191];
    reg [2815:0] expected_body[0:15];
    reg [63:0] expected_words[0:45];
    reg [31:0] current_record;
    integer produced=0,received=0,snapshots=0,records=0,views=0,replies=0,nonzero=0,i,v;
    reg [31:0] previous_index=0;
    reg have_pcm=0;
    reg [4:0] expected_addr;
    reg [31:0] expected_value;
    reg [15:0] expected_tag;
    task fail;
        input [8*160-1:0] message;
        begin $display("CORE_TRANSPORT_TB_FAIL %0s time=%0t",message,$time);$stop;end
    endtask
    task command;
        input [4:0] addr;
        input [31:0] value;
        integer target;
        begin
            @(negedge client_clk);wait(client_ready);target=replies+1;
            expected_addr=addr;expected_value=value;expected_tag=target;
            client_addr=addr;client_value=value;client_tag=target;client_valid=1;
            @(posedge client_clk);if(!client_ready) fail("command handshake");
            @(negedge client_clk);client_valid=0;wait(replies==target);
        end
    endtask
    task set_keys;
        input [24:0] value;
        begin @(negedge audio_clk);keys=value;changed=1;@(negedge audio_clk);changed=0;end
    endtask
    always @(posedge audio_clk) if(!arst) begin
        if(final_valid) begin
            if(sample_index>=8192) fail("sample scoreboard bounds");
            expected_pcm[sample_index]={sample_index,final_right,final_left};produced=produced+1;
            if(final_left!=0||final_right!=0) nonzero=nonzero+1;
        end
        if(dut.core.snapshot_valid) begin
            if(dut.states.sequence_count>=16) fail("snapshot scoreboard bounds");
            expected_body[dut.states.sequence_count]={39'd0,dut.core.snapshot_keys,
                dut.core.snapshot_extension,dut.core.snapshot_data,dut.core.capabilities};
            snapshots=snapshots+1;
        end
        if(deadline_missed||command_protocol_error) fail("audio deadline or command protocol");
    end
    always @(posedge client_clk) if(!arst&&reply_valid) begin
        if(!reply_accepted||!reply_applied||reply_addr!==expected_addr||
           reply_value!==expected_value||reply_tag!==expected_tag) fail("core canonical ACK");
        replies=replies+1;
    end
    always @(posedge observer_clk) if(!arst) begin
        if(pcm_valid&&pcm_ready) begin
            if({pcm_index,pcm_right,pcm_left}!==expected_pcm[pcm_index]) fail("PCM differs from real DAC sample");
            if(pcm_gap!==(!have_pcm||pcm_index!=previous_index+1)) fail("PCM gap flag");
            previous_index=pcm_index;have_pcm=1;received=received+1;
        end
        if(state_valid&&state_ready) begin
            if(state_word_index==0) begin
                if(!state_first||state_last||state_data!==64'h4132012e25041900) fail("record header");
            end else if(state_word_index==1) begin
                current_record=state_data[31:0];
                if(current_record>=16) fail("record sequence bounds");
                for(i=0;i<44;i=i+1) expected_words[i+2]=expected_body[current_record][i*64+:64];
            end else begin
                if(state_data!==expected_words[state_word_index]) fail("state record differs from producer bundle");
                if(state_last) records=records+1;
            end
        end
        if(view_valid) begin
            views=views+1;
            if(view_sequence!==current_record || view_master!==expected_body[current_record][128+64+:17] ||
               view_keys!==expected_body[current_record][128+2368+256+:25] ||
               view_pcm!==expected_body[current_record][128+2368+:32] ||
               view_revision!==expected_body[current_record][128+32+:32]) fail("compact UI fields differ from core");
            for(v=0;v<32;v=v+1) begin
                if(view_occupied[v]!==expected_body[current_record][128+320+v*64+42] ||
                   view_held[v]!==expected_body[current_record][128+320+v*64+43] ||
                   view_gated[v]!==expected_body[current_record][128+320+v*64+44] ||
                   view_notes[v*7+:7]!==expected_body[current_record][128+320+v*64+32+:7] ||
                   view_presets[v*3+:3]!==expected_body[current_record][128+320+v*64+39+:3]) fail("UI voice field");
            end
        end
    end
    initial begin
        #53;arst=0;repeat(8) @(negedge audio_clk);
        command(1,65536);command(5,1);set_keys(25'h1001001);
        wait(produced>=1100);state_ready=0;pcm_ready=0;
        command(0,2);set_keys(0);repeat(20) @(negedge audio_clk);set_keys(25'h0000042);
        wait(produced>=1200);pcm_ready=1;
        command(0,5);command(15,1);command(20,4095);set_keys(0);
        repeat(20) @(negedge audio_clk);set_keys(25'h0100810);
        wait(produced>=3300);state_ready=1;
        command(0,4);set_keys(0);repeat(20) @(negedge audio_clk);set_keys(25'h0008000);
        wait(produced>=4300&&records>=3&&views>=3);
        if(nonzero<3000||received<4000||pcm_drops==0||state_drops==0||!pcm_overflow||malformed!=0) fail("insufficient active/pressure coverage");
        $display("CORE_TRANSPORT_TB_PASS source_pcm=%0d received_pcm=%0d nonzero=%0d snapshots=%0d records=%0d views=%0d commands=%0d pcm_drops=%0d state_drops=%0d real_core_stall_independence=1",produced,received,nonzero,snapshots,records,views,replies,pcm_drops,state_drops);
        $finish;
    end
    initial begin #120000000;fail("timeout");end
endmodule

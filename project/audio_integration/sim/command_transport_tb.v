`timescale 1ns/1ps
module command_transport_tb;
    reg audio_clk=0,client_clk=0,arst=1;
    always #10 audio_clk=!audio_clk;
    always #13 client_clk=!client_clk;
    reg client_valid=0;
    wire client_ready,reply_valid;
    reg reply_ready=0;
    reg [4:0] client_addr=0;
    reg [31:0] client_value=0;
    reg [15:0] client_tag=0;
    wire [4:0] reply_addr,host_addr;
    wire [31:0] reply_value,host_value;
    wire [15:0] reply_tag;
    wire reply_accepted,reply_applied,host_valid,host_ready,protocol_error;
    wire ack_valid,ack_source,ack_accepted,ack_applied;
    wire [4:0] ack_addr;
    wire [31:0] ack_value;
    reg inject_ack=0;
    audio_command_bridge bridge(.client_clk(client_clk),.audio_clk(audio_clk),.arst(arst),
        .client_valid(client_valid),.client_ready(client_ready),.client_addr(client_addr),
        .client_value(client_value),.client_tag(client_tag),.reply_valid(reply_valid),.reply_ready(reply_ready),
        .reply_addr(reply_addr),.reply_value(reply_value),.reply_tag(reply_tag),
        .reply_accepted(reply_accepted),.reply_applied(reply_applied),
        .host_valid(host_valid),.host_ready(host_ready),.host_addr(host_addr),.host_value(host_value),
        .ack_valid(ack_valid||inject_ack),.ack_source(ack_source||inject_ack),.ack_addr(inject_ack ? 5'd29 : ack_addr),
        .ack_value(ack_value),.ack_accepted(ack_accepted),.ack_applied(ack_applied),.audio_protocol_error(protocol_error));
    wire audio_rst;
    audio_transport_reset service_reset(audio_clk,arst,audio_rst);
    reg [4:0] sample_counter=0;
    reg pause_samples=0;
    wire sample_ce=!pause_samples&&sample_counter==16;
    always @(posedge audio_clk) begin
        if(audio_rst||sample_counter==16) sample_counter<=0;
        else sample_counter<=sample_counter+1'b1;
    end
    reg local_valid=0;
    wire local_ready;
    reg [4:0] local_addr=7;
    reg [31:0] local_value=3;
    wire [16:0] master;
    wire [2:0] preset;
    audio_parameter_service service(.clk(audio_clk),.rst(audio_rst),.sample_ce(sample_ce),
        .local_valid(local_valid),.local_ready(local_ready),.local_addr(local_addr),.local_value(local_value),
        .host_valid(host_valid),.host_ready(host_ready),.host_addr(host_addr),.host_value(host_value),
        .ack_valid(ack_valid),.ack_source(ack_source),.ack_addr(ack_addr),.ack_value(ack_value),
        .ack_accepted(ack_accepted),.ack_applied(ack_applied),.adc_valid(1'b0),
        .adc_ch0(12'd0),.adc_ch1(12'd0),.adc_ch2(12'd0),.adc_ch3(12'd0),.adc_ch4(12'd0),
        .harmonic_snapshot_ready(1'b1),.master_volume_target(master),.selected_preset(preset));
    reg [4:0] expected_addr=0;
    reg [31:0] expected_value=0;
    reg [15:0] expected_tag=0;
    reg expected_legal=0,previous_reply_stall=0,previous_host_stall=0;
    reg [54:0] previous_reply=0;
    reg [36:0] previous_host=0;
    integer replies=0,local_acks=0,host_acks=0,reply_stalls=0,host_stalls=0;
    task fail;
        input [8*140-1:0] message;
        begin $display("COMMAND_TRANSPORT_TB_FAIL %0s time=%0t reply=%0d/%0d/%0d accepted=%b expected=%0d/%0d/%0d",message,$time,reply_addr,reply_value,reply_tag,reply_accepted,expected_addr,expected_value,expected_tag);$stop;end
    endtask
    task send_request;
        input [4:0] addr;
        input [31:0] value,canonical;
        input [15:0] tag;
        input legal;
        begin
            @(negedge client_clk);wait(client_ready);
            expected_addr=addr;expected_value=canonical;expected_tag=tag;expected_legal=legal;
            client_addr=addr;client_value=value;client_tag=tag;client_valid=1;
            @(posedge client_clk);if(!client_ready) fail("request not accepted");
            @(negedge client_clk);client_valid=0;
        end
    endtask
    task reset_link;
        begin
            client_valid=0;reply_ready=0;local_valid=0;arst=1;#53;arst=0;
            repeat(6) @(negedge audio_clk);
        end
    endtask
    always @(posedge client_clk or posedge arst) begin
        if(arst) previous_reply_stall=0;
        else begin
            if(previous_reply_stall&&(!reply_valid||{reply_accepted,reply_applied,reply_tag,reply_addr,reply_value}!==previous_reply)) fail("reply changed while stalled");
            previous_reply_stall=reply_valid&&!reply_ready;
            previous_reply={reply_accepted,reply_applied,reply_tag,reply_addr,reply_value};
            if(reply_valid&&!reply_ready) begin
                reply_stalls=reply_stalls+1;
                if(client_ready) fail("accepted another command before reply consumed");
            end
            if(reply_valid&&reply_ready) begin
                if(reply_addr!==expected_addr||reply_value!==expected_value||reply_tag!==expected_tag||
                   reply_accepted!==expected_legal||reply_applied!==expected_legal) fail("canonical response/tag/legal comparison");
                replies=replies+1;
            end
        end
    end
    always @(posedge audio_clk or posedge arst) begin
        if(arst) previous_host_stall=0;
        else begin
            if(previous_host_stall&&(!host_valid||{host_addr,host_value}!==previous_host)) fail("host payload changed before handshake");
            previous_host_stall=host_valid&&!host_ready;previous_host={host_addr,host_value};
            if(host_valid&&!host_ready) host_stalls=host_stalls+1;
            if(ack_valid) begin
                if(ack_source) host_acks=host_acks+1;
                else local_acks=local_acks+1;
            end
        end
    end
    initial begin
        #53;arst=0;repeat(6) @(negedge audio_clk);
        pause_samples=1;local_valid=1;@(posedge audio_clk);if(!local_ready) fail("local setup");
        @(negedge audio_clk);local_valid=0;
        send_request(1,65536,65536,16'h1101,1);
        wait(host_valid);repeat(24) @(negedge audio_clk);
        if(reply_valid) fail("local pending generated host reply");
        pause_samples=0;wait(reply_valid);repeat(25) @(negedge client_clk);
        if(master!=65536||protocol_error) fail("legal command or local ACK filtering");
        reply_ready=1;wait(replies==1);wait(client_ready);
        send_request(0,1,1,16'h1102,0);wait(replies==2);wait(client_ready);
        if(preset!=0) fail("illegal ID changed preset");
        send_request(2,-32'd400,65136,16'h1103,1);wait(replies==3);wait(client_ready);
        if(master!=65136) fail("canonical relative volume");
        send_request(29,42,42,16'h1104,0);wait(replies==4);wait(client_ready);
        send_request(0,5,5,16'h1105,1);wait(replies==5);wait(client_ready);
        if(preset!=5) fail("valid custom preset");
        pause_samples=1;send_request(1,32000,32000,16'hdead,1);
        wait(host_valid&&host_ready);repeat(5) @(negedge audio_clk);reset_link;
        pause_samples=0;repeat(40) @(negedge audio_clk);
        if(reply_valid||host_valid||master!=8249) fail("pending request survived reset");
        send_request(1,12345,12345,16'h2201,1);wait(reply_valid);
        repeat(15) @(negedge client_clk);reset_link;
        if(reply_valid) fail("stalled reply survived reset");
        reply_ready=1;send_request(1,23456,23456,16'h2202,1);wait(replies==6);wait(client_ready);
        @(negedge audio_clk);inject_ack=1;@(negedge audio_clk);inject_ack=0;
        if(!protocol_error) fail("unexpected host ACK not diagnosed");
        repeat(30) @(negedge client_clk);if(reply_valid) fail("unexpected ACK became response");
        if(local_acks<1||host_stalls<20||reply_stalls<30) fail("insufficient interleaving/stall coverage");
        $display("COMMAND_TRANSPORT_TB_PASS replies=%0d host_acks=%0d local_acks=%0d host_stalls=%0d reply_stalls=%0d nack=2 reset_pending_and_reply=1 unexpected_ack=1",replies,host_acks,local_acks,host_stalls,reply_stalls);
        $finish;
    end
    initial begin #500000;fail("timeout");end
endmodule

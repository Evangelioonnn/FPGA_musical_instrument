`timescale 1ns/1ps
module session_controls_tb;
reg clk=0;always #10 clk=~clk;
reg rst=1,sample_ce=1,transport_run=0,host_ready=1,has_layers=0;
reg [2:0] down=0,released=0;reg step_valid=0;reg signed [1:0] step=1;
reg ui_valid=0;wire ui_ready;reg [7:0] ui_addr=0;reg [31:0] ui_value=0;
reg ui_recording=0,ui_armed=0,ui_count_in=0,ui_busy=0,ui_flushing=0,menu_drums_commit=0;
reg [15:0] ui_layers=0;wire ui_ack,ui_accepted,ui_applied;wire [7:0] ui_reason;wire [31:0] ui_result;
wire host_valid;wire [4:0] host_addr;wire [31:0] host_value;
wire [2:0] preset,page,mode,meter,bars;wire [1:0] track,quantize;
wire start_req,stop_req,record_req,undo_req,clear_req,met_enable,overflow;
wire [7:0] bpm;wire [8:0] click_gain;wire [67:0] track_gains,mixer_targets;wire [3:0] muted,mixer_invalidate;
looper_controls #(.LONG_CYCLES(20)) dut(.sync_valid(1'b0),.sync_remote(1'b0),.sync_addr(5'd0),.sync_value(32'd0),.mixer_valid(1'b0),.mixer_data(68'd0),.mixer_ready(),.*);
integer count=0,i;reg [242:0] before_state;
// Targets, rather than smoothed gains, are checked for rejection immutability.
wire [242:0] configuration={mixer_targets,muted,dut.master,dut.raw[0],dut.raw[1],dut.raw[2],dut.raw[3],
    page,mode,track,preset,met_enable,bpm,meter,bars,click_gain,quantize};
task action;input [7:0] a;input [31:0] v;input [7:0] reason;
begin
 @(negedge clk);before_state=configuration;ui_addr=a;ui_value=v;ui_valid=1;
 if(!ui_ready) $fatal(1,"unexpected not ready");
 @(negedge clk);ui_valid=0;count=count+1;
 if(!ui_ack || ui_reason!==reason || ui_accepted!==(reason==0) || ui_applied!==(reason==0))
  $fatal(1,"action %h %h expected reason%0d actual%0d",a,v,reason,ui_reason);
 if(reason && (configuration!==before_state || start_req || stop_req || record_req || undo_req || clear_req))
  $fatal(1,"rejected action mutated state %h",a);
 if(ui_result!=={reason,a,count[15:0]}) $fatal(1,"result sequence");
end endtask
initial begin
 repeat(4) @(negedge clk);rst=0;
 action('h20,4,0);action('h21,3,0);action('h21,4,2);action('h20,1,0);action('h21,1,2);
 action('h20,0,0);action('h21,7,0);action('h21,8,2);action('h20,5,2);
 action('h22,2,0);action('h22,4,2);
 action('h23,1,0);if(!start_req) $fatal(1,"start missing");transport_run=1;
 action('h23,1,3);action('h24,0,2);action('h24,1,0);if(!stop_req) $fatal(1,"stop missing");transport_run=0;
 action('h24,1,0);action('h25,1,0);if(!record_req||!start_req) $fatal(1,"idle take admission");
 ui_layers=16'h0f00;action('h25,1,5);action('h26,0,4);action('h26,2,0);if(track!=2||!undo_req) $fatal(1,"target undo");
 action('h27,2,2);action('h27,32'h434c5202,0);if(!clear_req) $fatal(1,"clear confirmation");
 ui_recording=1;action('h26,2,3);ui_recording=0;ui_armed=1;action('h25,1,3);ui_armed=0;
 ui_count_in=1;action('h27,32'h434c5202,3);ui_count_in=0;ui_busy=1;action('h26,2,3);ui_busy=0;
 ui_flushing=1;action('h2d,0,3);ui_flushing=0;
 action('h28,(2<<17)|32768,0);repeat(256) @(negedge clk);
 if(track_gains[34+:17]!=32768 || track_gains[0+:17]!=65536 || dut.master!=8249) $fatal(1,"track isolation");
 action('h28,(2<<17)|65537,2);action('h28,32'h80000000,2);
 action('h29,5,0);repeat(512) @(negedge clk);if(track_gains[34+:17]!=0 || muted!=4'b0100) $fatal(1,"mute isolation");
 action('h29,4,0);repeat(256) @(negedge clk);if(track_gains[34+:17]!=32768) $fatal(1,"unmute restoration");action('h29,8,2);
 action('h2a,40,0);action('h2a,240,0);action('h2a,39,2);action('h2a,241,2);
 action('h2b,2,0);action('h2c,4,0);has_layers=1;action('h2b,3,3);action('h2c,1,3);has_layers=0;
 action('h2b,5,2);action('h2c,0,2);action('h2d,3,0);action('h2d,4,2);
 action('h2e,1,0);action('h2e,2,2);action('h2f,256,0);action('h2f,257,2);action('h30,0,1);
 @(negedge clk);down=1;ui_valid=1;ui_addr='h22;ui_value=3;repeat(8) @(negedge clk);
 if(ui_ready||ui_ack||track!=2) $fatal(1,"panel priority");down=0;
 @(negedge clk);ui_valid=0;if(!ui_ack||track!=3) $fatal(1,"held UI resumed");
 if(overflow) $fatal(1,"control overflow");
 $display("SESSION_CONTROLS_TB_PASS actions=%0d ranges busy empty full clear_confirmation local_priority target_isolation smoothed_mute",count+1);$finish;
end
initial begin #3000000;$fatal(1,"control watchdog");end
endmodule

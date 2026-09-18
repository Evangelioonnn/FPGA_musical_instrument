module expression_controls(
    input wire clk,rst,sample_ce,cfg_valid,
    input wire [3:0] cfg_addr,
    input wire [31:0] cfg_data,
    output wire cfg_ready,
    output reg ack,accepted,
    output reg [31:0] applied,
    output reg [16:0] volume_target,gain,
    output reg [1:0] timbre,
    output reg [14:0] weight2,weight3,
    output reg [17:0] bend_ratio,
    output reg [30:0] glide_delta,
    output reg sustain,sostenuto,panic,
    output reg [15:0] attack_step,decay_step,sustain_level,release_step
);
    reg legal;
    wire [14:0] target2=timbre==2 ? 15'd16384 : 15'd0;
    wire [14:0] target3=timbre!=0 ? 15'd16384 : 15'd0;
    function [16:0] approach;
        input [16:0] cur,target,delta;
        begin
            if(cur<target) approach=(target-cur<=delta) ? target : cur+delta;
            else approach=(cur-target<=delta) ? target : cur-delta;
        end
    endfunction
    wire [16:0] next_weight2=approach({2'b0,weight2},{2'b0,target2},32);
    wire [16:0] next_weight3=approach({2'b0,weight3},{2'b0,target3},32);
    assign cfg_ready=!rst;
    always @* begin
        case(cfg_addr)
            0:legal=cfg_data<=65536;
            1:legal=cfg_data<=2;
            2:legal=cfg_data>=32768 && cfg_data<=131072;
            3:legal=!cfg_data[31];
            4,5:legal=cfg_data<=1;
            6:legal=cfg_data==1;
            7,8,10:legal=cfg_data>=1 && cfg_data<=65535;
            9:legal=cfg_data<=65535;
            default:legal=0;
        endcase
    end
    always @(posedge clk) begin
        if(rst) begin
            ack<=0;accepted<=0;applied<=0;volume_target<=65536;gain<=65536;
            timbre<=0;weight2<=0;weight3<=0;bend_ratio<=65536;glide_delta<=0;
            sustain<=0;sostenuto<=0;panic<=0;
            attack_step<=68;decay_step<=6;sustain_level<=32768;release_step<=3;
        end else begin
            ack<=cfg_valid;accepted<=cfg_valid && legal;panic<=0;
            if(cfg_valid) applied<=legal ? cfg_data : 32'hffffffff;
            if(cfg_valid && legal) case(cfg_addr)
                0:volume_target<=cfg_data[16:0];
                1:timbre<=cfg_data[1:0];
                2:bend_ratio<=cfg_data[17:0];
                3:glide_delta<=cfg_data[30:0];
                4:sustain<=cfg_data[0];
                5:sostenuto<=cfg_data[0];
                6:panic<=1;
                7:attack_step<=cfg_data[15:0];
                8:decay_step<=cfg_data[15:0];
                9:sustain_level<=cfg_data[15:0];
                10:release_step<=cfg_data[15:0];
            endcase
            if(sample_ce) begin
                gain<=approach(gain,volume_target,128);
                weight2<=next_weight2[14:0];
                weight3<=next_weight3[14:0];
            end
        end
    end
endmodule

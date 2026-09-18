module system_controls(
    input wire clk,rst,sample_ce,cfg_valid,
    input wire [3:0] cfg_addr,input wire [31:0] cfg_data,
    input wire [16:0] pressure_gain,
    output wire cfg_ready,
    output reg ack,accepted,output reg [31:0] applied,
    output reg [16:0] master_volume,gain,
    output reg sustain,sostenuto,panic
);
    reg legal;
    wire [16:0] pressure=pressure_gain>65536 ? 17'd65536 : pressure_gain;
    wire [33:0] product=master_volume*pressure;
    // Registered product gives the multiplier a full clock, not an audio tick.
    reg [16:0] target;
    assign cfg_ready=!rst;
    always @* begin
        case(cfg_addr)
            0:legal=cfg_data<=65536;
            4,5:legal=cfg_data<=1;
            6:legal=cfg_data==1;
            default:legal=0;
        endcase
    end
    always @(posedge clk) begin
        if(rst) begin
            ack<=0;accepted<=0;applied<=0;master_volume<=65536;gain<=65536;target<=65536;
            sustain<=0;sostenuto<=0;panic<=0;
        end else begin
            target<=product[32:16];ack<=cfg_valid && cfg_ready;
            accepted<=cfg_valid && cfg_ready && legal;panic<=0;
            if(cfg_valid && cfg_ready) begin
                applied<=legal ? cfg_data : 32'hffffffff;
                if(legal) case(cfg_addr)
                    0:master_volume<=cfg_data[16:0];
                    4:sustain<=cfg_data[0];
                    5:sostenuto<=cfg_data[0];
                    6:begin panic<=1;sustain<=0;sostenuto<=0;end
                endcase
            end
            if(sample_ce) begin
                if(gain<target) gain<=target-gain<=128 ? target : gain+17'd128;
                else if(gain>target) gain<=gain-target<=128 ? target : gain-17'd128;
            end
        end
    end
endmodule

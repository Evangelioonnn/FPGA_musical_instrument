module expression_demo #(parameter SLOT=48077)(
    input wire clk,rst,ce,
    output reg event_valid,
    output reg [1:0] event_kind,
    output reg [6:0] event_note,event_value,
    output reg [8:0] event_velocity,
    output reg cfg_valid,
    output reg [3:0] cfg_addr,
    output reg [31:0] cfg_data
);
    reg [4:0] slot;
    reg [31:0] position;
    task write_cfg;
        input [3:0] addr;input [31:0] data;
        begin cfg_valid<=1;cfg_addr<=addr;cfg_data<=data;end
    endtask
    task note;
        input [1:0] kind;input [6:0] id,target;input [8:0] velocity;
        begin event_valid<=1;event_kind<=kind;event_note<=id;event_value<=target;event_velocity<=velocity;end
    endtask
    always @(posedge clk) begin
        if(rst) begin
            slot<=0;position<=0;event_valid<=0;event_kind<=0;event_note<=0;event_value<=0;event_velocity<=0;
            cfg_valid<=0;cfg_addr<=0;cfg_data<=0;
        end else begin
            event_valid<=0;cfg_valid<=0;
            if(ce) begin
                if(position==SLOT-1) begin position<=0;slot<=slot==23 ? 5'd0 : slot+5'd1;end
                else position<=position+1'b1;
                case(slot)
                    0:begin
                        if(position==0) write_cfg(1,0);
                        if(position==2) write_cfg(3,0);
                        if(position==4) write_cfg(2,65536);
                    end
                    1:if(position==0) note(0,69,0,256);
                    2:if(position==0) write_cfg(1,1);
                    3:if(position==0) write_cfg(1,2);
                    4:if(position==0) write_cfg(0,16384);
                    5:if(position==0) write_cfg(0,0);
                    6:if(position==0) begin write_cfg(0,65536);end
                    7:begin
                        if(position==0) write_cfg(3,2048);
                        if(position==32) note(2,69,76,0);
                    end
                    8:if(position==0) note(2,69,69,0);
                    9:if(position==0) write_cfg(2,73562);
                    10:begin
                        if(position==0) write_cfg(2,65536);
                        if(position==64) note(1,69,0,0);
                        if(position==128) write_cfg(3,0);
                    end
                    11:begin
                        if(position==0) write_cfg(4,1);
                        if(position==2) write_cfg(1,0);
                    end
                    12:begin
                        if(position==0) note(0,60,0,256);
                        if(position==2) note(0,64,0,256);
                        if(position==4) note(0,67,0,256);
                    end
                    13:begin
                        if(position==0) note(1,60,0,0);
                        if(position==2) note(1,64,0,0);
                        if(position==4) note(1,67,0,0);
                    end
                    14:if(position==0) write_cfg(4,0);
                    15:begin
                        if(position==0) note(0,72,0,256);
                        if(position==32) write_cfg(5,1);
                    end
                    16:begin
                        if(position==0) note(0,76,0,256);
                        if(position==128) note(1,72,0,0);
                        if(position==130) note(1,76,0,0);
                    end
                    17:if(position==0) write_cfg(5,0);
                    18,19,20:begin
                        if(position==0) note(0,69,0,slot==18 ? 9'd64 : slot==19 ? 9'd128 : 9'd256);
                        if(position==SLOT/2) note(1,69,0,0);
                    end
                    21:begin
                        if(position==0) begin write_cfg(1,2);note(0,48,0,256);end
                        if(position==1) note(0,52,0,256);
                        if(position==2) note(0,55,0,256);
                        if(position==3) note(0,60,0,256);
                        if(position==4) note(0,64,0,256);
                        if(position==5) note(0,67,0,256);
                        if(position==6) note(0,72,0,256);
                        if(position==7) note(0,76,0,256);
                    end
                    22:if(position==0) write_cfg(6,1);
                endcase
            end
        end
    end
endmodule

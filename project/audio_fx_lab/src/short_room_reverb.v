// Four bounded feedback combs share a single synchronous delay RAM.
module short_room_reverb(
    input wire clk, rst,
    input wire in_valid,
    input wire signed [15:0] in_sample,
    input wire fx_enable,
    input wire [8:0] wet_q8,
    output reg out_valid,
    output reg signed [15:0] out_left, out_right,
    output reg clip,
    output reg ready,
    output wire busy,
    output reg overrun,
    output reg [8:0] wet_applied
);
    reg signed [15:0] delay_mem [0:4095];
    reg [11:0] clear_address, ram_address;
    reg signed [15:0] ram_read, ram_write_data;
    reg ram_write;
    reg [5:0] state;
    reg [1:0] comb_index;
    reg [10:0] position [0:3];
    reg signed [15:0] delayed [0:3];
    reg signed [15:0] dry;
    reg [8:0] frame_wet;
    reg frame_bypass;
    reg signed [19:0] stereo_sum_left, stereo_sum_right;
    reg signed [15:0] wet_left, wet_right;
    reg signed [17:0] multiplier_a;
    reg signed [9:0] multiplier_b;
    reg signed [27:0] multiplier_result;
    reg signed [19:0] mix_left, mix_right;
    integer i;

    assign busy = state != 0;
    wire [8:0] wet_target = !fx_enable ? 9'd0 :
        (wet_q8 > 9'd128 ? 9'd128 : wet_q8);
    wire [8:0] wet_next = wet_applied < wet_target ? wet_applied + 1'b1 :
        (wet_applied > wet_target ? wet_applied - 1'b1 : wet_applied);

    function [11:0] comb_address;
        input [1:0] index;
        input [10:0] offset;
        begin
            case(index)
                0: comb_address = offset;
                1: comb_address = 12'd768 + offset;
                2: comb_address = 12'd1536 + offset;
                default: comb_address = 12'd2560 + offset;
            endcase
        end
    endfunction
    function [10:0] comb_last;
        input [1:0] index;
        begin
            case(index)
                0: comb_last = 11'd600;
                1: comb_last = 11'd732;
                2: comb_last = 11'd886;
                default: comb_last = 11'd1090;
            endcase
        end
    endfunction
    function signed [19:0] trunc_shift;
        input signed [27:0] value;
        input [3:0] amount;
        begin
            trunc_shift = value < 0 ? -((-value) >>> amount) : value >>> amount;
        end
    endfunction
    function signed [15:0] saturate;
        input signed [19:0] value;
        begin
            if (value > 20'sd32767) saturate = 16'sh7fff;
            else if (value < -20'sd32768) saturate = 16'sh8000;
            else saturate = value[15:0];
        end
    endfunction
    wire signed [19:0] input_quarter = trunc_shift({{12{dry[15]}},dry},2);
    wire signed [19:0] feedback = trunc_shift(
        $signed({{12{ram_read[15]}},ram_read}) +
        ($signed({{12{ram_read[15]}},ram_read}) <<< 1),2);
    wire signed [19:0] comb_new = input_quarter + feedback;

    // Clearing is an addressed write sweep, so memory remains block-RAM eligible.
    always @(posedge clk) begin
        ram_read <= delay_mem[ram_address];
        if (!rst && !ready) delay_mem[clear_address] <= 16'sd0;
        else if (!rst && ram_write) delay_mem[ram_address] <= ram_write_data;
        multiplier_result <= multiplier_a * multiplier_b;
    end

    always @(posedge clk) begin
        if (rst) begin
            clear_address <= 0;
            ram_address <= 0;
            ram_write_data <= 0;
            ram_write <= 0;
            ready <= 0;
            state <= 0;
            comb_index <= 0;
            dry <= 0;
            frame_wet <= 0;
            frame_bypass <= 1;
            stereo_sum_left <= 0;
            stereo_sum_right <= 0;
            wet_left <= 0;
            wet_right <= 0;
            multiplier_a <= 0;
            multiplier_b <= 0;
            mix_left <= 0;
            mix_right <= 0;
            wet_applied <= 0;
            out_valid <= 0;
            out_left <= 0;
            out_right <= 0;
            clip <= 0;
            overrun <= 0;
            for(i=0;i<4;i=i+1) begin
                position[i] <= 0;
                delayed[i] <= 0;
            end
        end else begin
            out_valid <= 0;
            clip <= 0;
            ram_write <= 0;
            if (!ready) begin
                if (clear_address == 12'd4095) ready <= 1;
                else clear_address <= clear_address + 1'b1;
            end
            if (in_valid && busy) overrun <= 1;
            case(state)
                0: if (in_valid) begin
                    dry <= in_sample;
                    frame_bypass <= !ready;
                    frame_wet <= ready ? wet_next : 9'd0;
                    wet_applied <= ready ? wet_next : 9'd0;
                    comb_index <= 0;
                    state <= 1;
                end
                1: begin
                    ram_address <= comb_address(comb_index,position[comb_index]);
                    state <= 2;
                end
                2: state <= 3;
                3: begin
                    delayed[comb_index] <= frame_bypass ? 16'sd0 : ram_read;
                    ram_write_data <= comb_new[15:0];
                    ram_write <= !frame_bypass;
                    state <= 4;
                end
                4: begin
                    if (!frame_bypass) begin
                        if (position[comb_index] == comb_last(comb_index)) position[comb_index] <= 0;
                        else position[comb_index] <= position[comb_index] + 1'b1;
                    end
                    if (comb_index == 3) state <= 20;
                    else begin comb_index <= comb_index + 1'b1; state <= 1; end
                end
                20: begin
                    stereo_sum_left <=
                        $signed({{4{delayed[0][15]}},delayed[0]}) +
                        ($signed({{4{delayed[0][15]}},delayed[0]}) <<< 1) +
                        ($signed({{4{delayed[1][15]}},delayed[1]}) <<< 1) +
                        $signed({{4{delayed[2][15]}},delayed[2]}) +
                        ($signed({{4{delayed[3][15]}},delayed[3]}) <<< 1);
                    stereo_sum_right <=
                        $signed({{4{delayed[0][15]}},delayed[0]}) +
                        ($signed({{4{delayed[1][15]}},delayed[1]}) <<< 1) +
                        $signed({{4{delayed[2][15]}},delayed[2]}) +
                        ($signed({{4{delayed[2][15]}},delayed[2]}) <<< 1) +
                        ($signed({{4{delayed[3][15]}},delayed[3]}) <<< 1);
                    state <= 21;
                end
                21: begin
                    wet_left <= trunc_shift({{8{stereo_sum_left[19]}},stereo_sum_left},3);
                    wet_right <= trunc_shift({{8{stereo_sum_right[19]}},stereo_sum_right},3);
                    state <= 22;
                end
                22: begin
                    multiplier_a <= $signed({{2{wet_left[15]}},wet_left}) - $signed({{2{dry[15]}},dry});
                    multiplier_b <= $signed({1'b0,frame_wet});
                    state <= 23;
                end
                23: state <= 24;
                24: begin
                    mix_left <= $signed({{4{dry[15]}},dry}) + trunc_shift(multiplier_result,8);
                    multiplier_a <= $signed({{2{wet_right[15]}},wet_right}) - $signed({{2{dry[15]}},dry});
                    state <= 25;
                end
                25: state <= 26;
                26: begin
                    mix_right <= $signed({{4{dry[15]}},dry}) + trunc_shift(multiplier_result,8);
                    state <= 27;
                end
                27: begin
                    out_left <= saturate(mix_left);
                    out_right <= saturate(mix_right);
                    clip <= mix_left > 20'sd32767 || mix_left < -20'sd32768 ||
                        mix_right > 20'sd32767 || mix_right < -20'sd32768;
                    out_valid <= 1;
                    state <= 0;
                end
                default: state <= 0;
            endcase
        end
    end
endmodule

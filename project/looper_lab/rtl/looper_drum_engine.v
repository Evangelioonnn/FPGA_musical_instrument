module looper_drum_engine #(
    parameter VOICES = 8,
    parameter SW = (VOICES > 1 ? $clog2(VOICES) : 1)
)(
    input wire clk,
    input wire rst,
    input wire sample_ce,
    input wire strike_valid,
    output wire strike_ready,
    output wire strike_accepted,
    input wire [3:0] strike_pad,
    input wire [1:0] strike_layer,
    input wire [2:0] strike_track,
    input wire [67:0] track_gains,
    input wire flush_all,flush_valid,
    input wire [1:0] flush_track,flush_layer,input wire flush_whole_track,
    input wire [7:0] strike_velocity,
    output reg sample_valid,
    output reg signed [19:0] sample,
    output reg [VOICES-1:0] active,
    output wire [VOICES*4-1:0] active_pads,
    output reg [31:0] late_strikes,
    output reg [31:0] rejected_strikes
);
    localparam IDLE = 0;
    localparam SCAN = 1;
    localparam MIX = 2;
    reg [2:0] state;
    reg [SW-1:0] index;
    reg [1:0] layers[0:VOICES-1];reg [2:0] tracks[0:VOICES-1];reg [VOICES-1:0] forced_release;
    reg [16:0] rise_q,loss_q;reg [15:0] level_q,target_q;
    reg signed [31:0] wave_product_q;
    reg signed [37:0] track_product_q;
    wire [16:0] gain_raw=tracks[index]<4 ? track_gains[tracks[index]*17+:17] : 17'd65536;
    wire [16:0] selected_gain=gain_raw>65536 ? 17'd65536 : gain_raw;
    reg free_found, choke_found;
    reg [SW-1:0] free_index, choke_index;
    reg [3:0] pad [0:VOICES-1];
    reg [31:0] phase [0:VOICES-1];
    reg [31:0] step [0:VOICES-1];
    reg [31:0] step_floor [0:VOICES-1];
    reg [15:0] level [0:VOICES-1];
    reg [15:0] target_level [0:VOICES-1];
    reg [VOICES-1:0] attack_done;
    reg [15:0] noise [0:VOICES-1];
    reg [3:0] attack_shift [0:VOICES-1];
    reg [4:0] decay_shift [0:VOICES-1];
    reg [23:0] accumulator;
    reg [9:0] rom_address;
    wire signed [15:0] sine_sample;
    reg signed [15:0] wave_sample;
    reg signed [31:0] scaled_product;
    reg signed [23:0] voice_sample;
    reg [15:0] next_noise;
    reg [31:0] next_step;
    reg [31:0] next_phase;
    reg [16:0] env_loss;
    reg [16:0] env_rise;
    reg signed [23:0] next_sum;
    integer i;
    integer reset_i;

    sine_rom shared_drum_sine(clk, rom_address, sine_sample);

    genvar g;
    generate for (g = 0; g < VOICES; g = g + 1) begin: pad_outputs
        assign active_pads[g*4 +: 4] = pad[g];
    end endgenerate

    function [31:0] start_step;
        input [3:0] drum_pad;
        begin
            case (drum_pad)
                0: start_step = 32'd5800000;
                1: start_step = 32'd16500000;
                2: start_step = 32'd8900000;
                3: start_step = 32'd11600000;
                4: start_step = 32'd15200000;
                5: start_step = 32'd60100000;
                6: start_step = 32'd37700000;
                7: start_step = 32'd108000000;
                8: start_step = 32'd127000000;
                9: start_step = 32'd73300000;
                10: start_step = 32'd41800000;
                11: start_step = 32'd69000000;
                12: start_step = 32'd18800000;
                13: start_step = 32'd28400000;
                14: start_step = 32'd23000000;
                default: start_step = 32'd32000000;
            endcase
        end
    endfunction

    function [3:0] attack_rate;
        input [3:0] drum_pad;
        begin
            case (drum_pad)
                0, 1, 2, 3, 4: attack_rate = 4'd7;
                7, 8: attack_rate = 4'd6;
                default: attack_rate = 4'd4;
            endcase
        end
    endfunction

    function [4:0] decay_rate;
        input [3:0] drum_pad;
        begin
            case (drum_pad)
                0: decay_rate = 5'd11;
                1: decay_rate = 5'd9;
                2, 3, 4: decay_rate = 5'd10;
                5, 11: decay_rate = 5'd7;
                6: decay_rate = 5'd9;
                7, 8: decay_rate = 5'd11;
                9, 10: decay_rate = 5'd10;
                default: decay_rate = 5'd10;
            endcase
        end
    endfunction

    always @* begin
        free_found = 0;
        free_index = 0;
        choke_found = 0;
        choke_index = 0;
        for (i = 0; i < VOICES; i = i + 1) begin
            if (!active[i] && !free_found) begin
                free_found = 1;
                free_index = i[SW-1:0];
            end
            if ((strike_pad == 5 || strike_pad == 11) && active[i] &&
                (pad[i] == 6 || pad[i] == 11) && !choke_found) begin
                choke_found = 1;
                choke_index = i[SW-1:0];
            end
        end
    end

    assign strike_ready = state == IDLE && !sample_ce;
    assign strike_accepted = strike_ready && (free_found || choke_found);

    always @* begin
        rom_address = phase[index][31:22];
        wave_sample = sine_sample;
        next_noise = {noise[index][14:0], noise[index][15] ^ noise[index][13] ^
                      noise[index][12] ^ noise[index][10]};
        if (pad[index] != 0 && pad[index] != 2 && pad[index] != 3 && pad[index] != 4) begin
            if (pad[index] == 10) begin
                wave_sample = (phase[index][31] ^ phase[index][27] ^ phase[index][23]) ?
                    16'sd16383 : -16'sd16384;
            end else begin
                wave_sample = noise[index][0] ? 16'sd32767 : -16'sd32768;
                if (pad[index] == 1)
                    wave_sample = (sine_sample >>> 1) + (wave_sample >>> 1);
                else if (pad[index] >= 5)
                    wave_sample = (wave_sample >>> 1) +
                        ((phase[index][31] ^ phase[index][27] ^ phase[index][24]) ?
                            16'sd16383 : -16'sd16384);
            end
        end
        scaled_product = wave_sample * $signed({1'b0, level[index]});
        voice_sample = active[index] ? scaled_product >>> 16 : 24'sd0;
        env_rise = (({1'b0,target_level[index]} - {1'b0,level[index]}) >> attack_shift[index]) + 1'b1;
        env_loss = ({1'b0,level[index]} >> decay_shift[index]) + 1'b1;
        next_step = step[index];
        if (pad[index] == 0 && step[index] > step_floor[index]) begin
            next_step = step[index] - (step[index] >> 7);
            if (next_step < step_floor[index]) next_step = step_floor[index];
        end else if (pad[index] >= 2 && pad[index] <= 4 && step[index] > step_floor[index]) begin
            next_step = step[index] - (step[index] >> 9);
            if (next_step < step_floor[index]) next_step = step_floor[index];
        end
        next_phase = phase[index] + step[index];
        next_sum = $signed(accumulator) + (track_product_q>>>16);
    end

    always @(posedge clk) begin
        if (rst) begin
            state <= IDLE;
            index <= 0;
            accumulator <= 0;
            sample_valid <= 0;
            sample <= 0;
            active <= 0;
            attack_done <= 0;forced_release<=0;wave_product_q<=0;track_product_q<=0;rise_q<=0;loss_q<=0;level_q<=0;target_q<=0;
            late_strikes <= 0;
            rejected_strikes <= 0;
            for (reset_i = 0; reset_i < VOICES; reset_i = reset_i + 1) begin
                pad[reset_i] <= 0;tracks[reset_i]<=4;layers[reset_i]<=0;
                phase[reset_i] <= 0;
                step[reset_i] <= 0;
                step_floor[reset_i] <= 0;
                level[reset_i] <= 0;
                target_level[reset_i] <= 0;
                noise[reset_i] <= 16'h1ace;
                attack_shift[reset_i] <= 4;
                decay_shift[reset_i] <= 10;
            end
        end else begin
            sample_valid <= 0;
            if (strike_valid && strike_ready && (free_found || choke_found)) begin
                if (strike_pad == 5 || strike_pad == 11) begin
                    for (reset_i = 0; reset_i < VOICES; reset_i = reset_i + 1)
                        if (active[reset_i] && (pad[reset_i] == 6 || pad[reset_i] == 11)) begin
                            active[reset_i] <= 0;
                            level[reset_i] <= 0;
                        end
                end
                active[choke_found ? choke_index : free_index] <= 1;
                tracks[choke_found ? choke_index : free_index]<=strike_track;
                layers[choke_found ? choke_index : free_index]<=strike_layer;
                forced_release[choke_found ? choke_index : free_index]<=0;
                pad[choke_found ? choke_index : free_index] <= strike_pad;
                phase[choke_found ? choke_index : free_index] <= 0;
                step[choke_found ? choke_index : free_index] <= start_step(strike_pad);
                step_floor[choke_found ? choke_index : free_index] <=
                    (strike_pad == 0 || (strike_pad >= 2 && strike_pad <= 4)) ?
                        (start_step(strike_pad) >> 1) : start_step(strike_pad);
                level[choke_found ? choke_index : free_index] <= 0;
                attack_done[choke_found ? choke_index : free_index] <= 0;
                target_level[choke_found ? choke_index : free_index] <=
                    {strike_velocity, strike_velocity};
                attack_shift[choke_found ? choke_index : free_index] <= attack_rate(strike_pad);
                decay_shift[choke_found ? choke_index : free_index] <= decay_rate(strike_pad);
                noise[choke_found ? choke_index : free_index] <=
                    16'h9e37 ^ {12'd0, strike_pad};
            end
            if (sample_ce) begin
                if (state != IDLE) late_strikes <= late_strikes + 1'b1;
                state <= SCAN;
                index <= 0;
                accumulator <= 0;
            end else case (state)
                IDLE: begin end
                SCAN: state <= 3;
                3:begin rise_q<=env_rise;loss_q<=env_loss;level_q<=level[index];target_q<=target_level[index];wave_product_q<=scaled_product;state<=4;end
                4:begin track_product_q<=(active[index] ? $signed(wave_product_q>>>16) : 32'sd0)*$signed({1'b0,selected_gain});state<=MIX;end
                MIX: begin
                    if (active[index]) begin
                        phase[index] <= next_phase;
                        step[index] <= next_step;
                        noise[index] <= next_noise == 0 ? 16'h1 : next_noise;
                        if(forced_release[index]) begin
                            level[index]<=level[index]>128 ? level[index]-16'd128 : 0;
                            if(level[index]<=128) active[index]<=0;
                        end else if (!attack_done[index] && level_q < target_q) begin
                            if ({1'b0, level_q} + rise_q >= {1'b0, target_q})
                                begin level[index] <= target_q; attack_done[index] <= 1; end
                            else level[index] <= level_q + rise_q[15:0];
                        end else if (level[index] <= loss_q) begin
                            level[index] <= 0;
                            active[index] <= 0;
                        end else level[index] <= level_q - loss_q[15:0];
                    end
                    if (index == VOICES - 1) begin
                        if (next_sum > 24'sd524287) sample <= 20'sh7ffff;
                        else if (next_sum < -24'sd524288) sample <= 20'sh80000;
                        else sample <= next_sum[19:0];
                        sample_valid <= 1;
                        accumulator <= 0;
                        state <= IDLE;
                    end else begin
                        accumulator <= next_sum;
                        index <= index + 1'b1;
                        state <= SCAN;
                    end
                end
                default: state <= IDLE;
            endcase
            if(flush_all === 1'b1 || flush_valid === 1'b1)
                for(reset_i=0;reset_i<VOICES;reset_i=reset_i+1)
                    if(tracks[reset_i]<4 && (flush_all === 1'b1 || (tracks[reset_i]==flush_track && (flush_whole_track || layers[reset_i]==flush_layer)))) forced_release[reset_i]<=1;
            if (strike_valid && strike_ready && !free_found && !choke_found)
                rejected_strikes <= rejected_strikes + 1'b1;
        end
    end
endmodule

module looper_transport #(
    parameter PPQN = 96,
    parameter MAX_BARS = 4
)(
    input wire clk,
    input wire rst,
    input wire tick_pulse,
    input wire beat_pulse,
    input wire bar_pulse,
    input wire [6:0] tick_in_beat,
    input wire [2:0] beat_in_bar,
    input wire start_req,
    input wire stop_req,
    input wire record_req,
    input wire [2:0] beats_per_bar,
    input wire [2:0] loop_bars,
    input wire metronome_enable,
    output reg transport_run,
    output reg count_in,
    output reg playing,
    output reg recording,
    output reg record_armed,
    output reg record_start_pulse,
    output reg record_done_pulse,
    output reg loop_wrap_pulse,
    output reg stop_pulse,
    output reg metronome_click,
    output reg metronome_accent,
    output reg [11:0] loop_tick,
    output reg [31:0] loop_number
);
    localparam [11:0] MAX_LOOP_TICKS = PPQN * 7 * MAX_BARS;
    reg pending_first_record;
    reg first_pass_record;
    reg [2:0] active_beats_per_bar;
    reg [2:0] active_loop_bars;
    wire [11:0] requested_length = PPQN *
        (beats_per_bar == 0 ? 3'd4 : beats_per_bar) *
        (loop_bars == 0 ? 3'd1 : loop_bars);

    always @(posedge clk) begin
        if (rst) begin
            transport_run <= 0;
            count_in <= 0;
            playing <= 0;
            recording <= 0;
            record_armed <= 0;
            record_start_pulse <= 0;
            record_done_pulse <= 0;
            loop_wrap_pulse <= 0;
            stop_pulse <= 0;
            metronome_click <= 0;
            metronome_accent <= 0;
            loop_tick <= 0;
            loop_number <= 0;
            pending_first_record <= 0;
            first_pass_record <= 0;
            active_beats_per_bar <= 4;
            active_loop_bars <= 1;
        end else begin
            record_start_pulse <= 0;
            record_done_pulse <= 0;
            loop_wrap_pulse <= 0;
            stop_pulse <= 0;
            metronome_click <= 0;
            metronome_accent <= 0;

            if (stop_req && transport_run) begin
                transport_run <= 0;
                count_in <= 0;
                playing <= 0;
                recording <= 0;
                record_armed <= 0;
                pending_first_record <= 0;
                first_pass_record <= 0;
                loop_tick <= 0;
                stop_pulse <= 1;
            end else begin
                if (start_req && !transport_run) begin
                    transport_run <= 1;
                    count_in <= 1;
                    playing <= 0;
                    recording <= 0;
                    record_armed <= 0;
                    pending_first_record <= record_req;
                    first_pass_record <= record_req;
                    loop_tick <= 0;
                    loop_number <= 0;
                    active_beats_per_bar <= beats_per_bar == 0 ? 3'd4 : beats_per_bar;
                    active_loop_bars <= loop_bars == 0 ? 3'd1 : loop_bars;
                end

                if (transport_run && metronome_enable && beat_pulse) begin
                    metronome_click <= 1;
                    metronome_accent <= beat_in_bar == 0;
                end

                if (transport_run && count_in && bar_pulse) begin
                    count_in <= 0;
                    playing <= 1;
                    loop_tick <= 0;
                    if (pending_first_record) begin
                        recording <= 1;
                        record_start_pulse <= 1;
                        pending_first_record <= 0;
                    end
                end else if (transport_run && playing && tick_pulse) begin
                    if (loop_tick + 1'b1 >= PPQN * active_beats_per_bar * active_loop_bars) begin
                        loop_tick <= 0;
                        loop_wrap_pulse <= 1;
                        loop_number <= loop_number + 1'b1;
                        if (record_armed) begin
                            recording <= 1;
                            record_armed <= 0;
                            record_start_pulse <= 1;
                            first_pass_record <= 0;
                        end else if (recording) begin
                            recording <= 0;
                            record_done_pulse <= 1;
                            first_pass_record <= 0;
                        end
                    end else begin
                        loop_tick <= loop_tick + 1'b1;
                    end
                end

                if (transport_run && playing && record_req && !recording && !record_armed)
                    record_armed <= 1;
            end
        end
    end
endmodule

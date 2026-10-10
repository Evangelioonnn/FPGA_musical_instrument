module drum_audit_top(
    input wire sys_clk,
    input wire [3:0] pad,
    input wire hit,
    input wire [7:0] velocity,
    output wire sample_valid,
    output wire signed [19:0] sample,
    output wire [7:0] active,
    output wire late_seen
);
    reg [10:0] sample_div;
    reg [15:0] startup;
    reg hit_armed;
    wire rst = startup[15] == 0;
    wire sample_ce = sample_div == 11'd1039;
    wire strike_ready;
    wire [31:0] late_strikes;
    wire [31:0] rejected_strikes;

    always @(posedge sys_clk) begin
        if (rst) begin
            startup <= startup + 1'b1;
            sample_div <= 0;
            hit_armed <= 0;
        end else begin
            if (sample_ce) sample_div <= 0;
            else sample_div <= sample_div + 1'b1;
            if (hit) hit_armed <= 1;
            else if (strike_ready) hit_armed <= 0;
        end
    end

    looper_drum_engine #(.VOICES(8)) engine(
        .clk(sys_clk), .rst(rst), .sample_ce(sample_ce),
        .strike_valid(hit_armed), .strike_ready(strike_ready),
        .strike_pad(pad), .strike_velocity(velocity),
        .sample_valid(sample_valid), .sample(sample), .active(active),
        .active_pads(), .late_strikes(late_strikes), .rejected_strikes(rejected_strikes));

    assign late_seen = |late_strikes || |rejected_strikes;
endmodule

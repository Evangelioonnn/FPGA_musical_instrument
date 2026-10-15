create_clock -name sys_clk -period 20.000 -waveform {0 10} [get_ports {sys_clk}]
set_false_path -from [get_ports {enc_a enc_b button_n[*] matrix_col_n[*]}]
# Only first-stage scalar toggle synchronizers are asynchronous.
set_false_path -to [get_regs {*text_frames/ack_meta* *text_frames/request_meta* *scope_frames/ack_meta* *scope_frames/request_meta* *page_select/page_meta*}]
# Dual-clock RAM banks are held stable until frame-boundary acknowledgment.
# No wide register-bus CDC or blanket clock-group timing exceptions.

# Sequenced-reset exception: OSER10 clocks are gated off for 320 ns before
# RESET falls and stay off for another 320 ns afterwards. This is NOT a
# running-clock asynchronous release. See av_serializer_start and PHY test.
set_false_path -from [get_regs {*transport/startup/serializer_reset*}] -to [get_pins {*transport/lanes_gen*.serializer/RESET}]

# DHCE has a four-negedge internal synchronization chain in the GW5A model.
# Its CEN receives a persistent asynchronous enable request, not cycle data.
set_false_path -from [get_regs {*transport/startup/clocks_enable*}] -to [get_pins {transport/serial_gate/CEN}]
# Async assertion / two-pixel-clock synchronous release synchronizer ONLY.
# Keep both stages' D paths and the released reset fanout timed normally.
set_false_path -to [get_pins {video_reset/release_pipe*/PRESET}]

create_clock -name audio_clk -period 20.000 [get_ports {sys_clk}]
create_clock -name observer_clk -period 20.000 [get_ports {observer_clk}]
set_false_path -from [get_ports {arst enc_a enc_b button_n[*] matrix_col_n[*]}]
set_input_delay -clock audio_clk -max 1.000 [get_ports {extra_keys[*] extra_changed}]
set_input_delay -clock audio_clk -min 0.000 [get_ports {extra_keys[*] extra_changed}]
set_output_delay -clock observer_clk -max 1.000 [get_ports {audit_digest}]
set_output_delay -clock observer_clk -min 0.000 [get_ports {audit_digest}]
set_output_delay -clock audio_clk -max 1.000 [get_ports {adc_ready matrix_row_n[*] hp_bck hp_ws hp_din pa_en status_led}]
set_output_delay -clock audio_clk -min 0.000 [get_ports {adc_ready matrix_row_n[*] hp_bck hp_ws hp_din pa_en status_led}]
# Scalar toggles are synchronized. Keep synchronizer stage1->stage2 timed.
set_false_path -to [get_regs {*ack_sync1* *request_sync1*}]
# Bound Gray pointer routing; do not mask these with blanket clock_groups.
set_max_delay -from [get_regs {*waveform/write_gray_* *waveform/read_gray_*}] -to [get_regs {*waveform/write_gray_sync1* *waveform/read_gray_sync1*}] 6.000
set_false_path -hold -to [get_regs {*waveform/write_gray_sync1* *waveform/read_gray_sync1*}]
# Command buses remain held from publication until the complete reply is consumed.
# Constrain the two bundled-data crossings to their retained capture registers.
set_max_delay -from [get_regs {*commands/held_addr* *commands/held_value*}] -to [get_regs {*commands/host_addr* *commands/host_value*}] 6.000
set_false_path -hold -from [get_regs {*commands/held_addr* *commands/held_value*}] -to [get_regs {*commands/host_addr* *commands/host_value*}]
set_max_delay -from [get_regs {*commands/held_reply_addr* *commands/held_reply_value* *commands/held_reply_tag*}] -to [get_regs {*commands/reply_addr* *commands/reply_value* *commands/reply_tag*}] 6.000
set_false_path -hold -from [get_regs {*commands/held_reply_addr* *commands/held_reply_value* *commands/held_reply_tag*}] -to [get_regs {*commands/reply_addr* *commands/reply_value* *commands/reply_tag*}]

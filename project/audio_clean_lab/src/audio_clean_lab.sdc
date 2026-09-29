create_clock -name sys_clk -period 20.000 -waveform {0 10} [get_ports {sys_clk}]
set_false_path -from [get_ports {timbre_button_n matrix_col_n[*]}]

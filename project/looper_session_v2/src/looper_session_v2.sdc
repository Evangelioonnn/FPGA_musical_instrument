# Physical board clock: 50 MHz. The 18 ns guard run is retained as failed evidence.
create_clock -name sys_clk -period 20.000 -waveform {0 10} [get_ports {sys_clk}]
set_false_path -from [get_ports {enc_a enc_b button_n[*] matrix_col_n[*]}]

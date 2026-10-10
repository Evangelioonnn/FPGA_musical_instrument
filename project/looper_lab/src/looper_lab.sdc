# Board oscillator is 50 MHz. 18 ns is a deliberate 2 ns integration margin.
create_clock -name sys_clk -period 18.000 -waveform {0 9} [get_ports {sys_clk}]
set_false_path -from [get_ports {enc_a enc_b button_n[*] matrix_col_n[*]}]

create_clock -name sys_clk -period 20.000 -waveform {0 10} [get_ports {sys_clk}]
# Each asynchronous input feeds only its first synchronizer stage.
# Synchronizer-to-synchronizer paths remain timed; external serial timing is bench/scope checked.
set_false_path -from [get_ports {enc_a enc_b button_n[*] matrix_col_n[*]}]

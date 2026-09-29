create_clock -name sys_clk -period 20.000 -waveform {0 10} [get_ports {sys_clk}]
# Mechanical inputs are asynchronous; their only fanout is the first sync stage.
# The path between synchronization stages remains timed by sys_clk.
set_false_path -from [get_ports {enc_a enc_b}]

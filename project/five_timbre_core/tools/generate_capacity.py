"""Generate a separate unpinned 16-voice capacity project, never a board firmware."""
from pathlib import Path
from generate import HERE, FINAL, PALETTE

name = 'five_capacity16'
p = HERE / 'experiments/capacity16'
p.mkdir(parents=True, exist_ok=True)
sources = ['top.v'] + sorted(f'../../src/{item.name}' for item in (HERE/'src').glob('*.v'))
sources += [f'../../../final_dual_timbre/src/{item}.v' for item in FINAL]
sources += [f'../../../audio_palette_lab/src/{item}.v' for item in PALETTE]
sources += ['../../../audio_output_lab/src/output_tx.v',
            '../../../audio_output_lab/src/output_polarity.v']
files = '\n'.join(f'    <File path="{item}" type="file.verilog" enable="1" />'
                  for item in sources)
(p/'capacity.sdc').write_text('create_clock -name sys_clk -period 20.000 -waveform {0 10} [get_ports {sys_clk}]\n')
(p/(name+'.gprj')).write_text(f'''<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE gowin-fpga-project>
<Project><Template>FPGA</Template><Version>5</Version>
  <Device name="GW5AT-60B" pn="GW5AT-LV60PG484AC1/I0">gw5at60b-002</Device>
  <FileList>
{files}
    <File path="capacity.sdc" type="file.sdc" enable="1" />
  </FileList>
</Project>
''')
(p/'build.tcl').write_text(f'''set project_dir [file dirname [file normalize [info script]]]
open_project [file join $project_dir {name}.gprj]
set_option -top_module {name}
set_option -output_base_name {name}
run all
''')
print(p)

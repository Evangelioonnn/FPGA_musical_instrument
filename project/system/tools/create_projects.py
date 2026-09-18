"""Recreate small Gowin project wrappers with only the five verified board pins."""
from pathlib import Path
import os
ROOT=Path(__file__).resolve().parents[3]
def create(folder,name,top,sources):
    folder=ROOT/folder;folder.mkdir(parents=True,exist_ok=True)
    entries=[]
    for source in sources:
        p=ROOT/source;rel=Path(os.path.relpath(p,folder)).as_posix()
        kind={'.v':'verilog','.cst':'cst','.sdc':'sdc'}[p.suffix]
        entries.append(f'        <File path="{rel}" type="file.{kind}" enable="1"/>')
    project='''<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE gowin-fpga-project>
<Project>
    <Template>FPGA</Template><Version>5</Version>
    <Device name="GW5AT-60B" pn="GW5AT-LV60PG484AC1/I0">gw5at60b-002</Device>
    <FileList>
'''+ '\n'.join(entries)+ '\n    </FileList>\n</Project>\n'
    (folder/(name+'.gprj')).write_text(project,encoding='utf-8')
    (folder/'build.tcl').write_text(f'''set project_dir [file dirname [file normalize [info script]]]
open_project [file join $project_dir {name}.gprj]
set_option -top_module {top}
set_option -output_base_name {name}
run all
''',encoding='utf-8')
base=[f'project/instrument/src/{x}' for x in ['adsr_envelope.v','sine_rom.v','note_table.v','synth_voice.v','pt8211_tx.v','instrument.cst','instrument.sdc']]
system=base+[f'project/expression/src/{x}.v' for x in ['performance_manager','expression_controls','audio_meter']]
system += ['project/expression_baseline/src/baseline_core.v','project/expression_baseline/src/baseline_demo.v']
system += [p.relative_to(ROOT).as_posix() for p in sorted((ROOT/'project/system/src').glob('*.v'))]
create('project/system','system','system_top',system)
for n in (16,32):create(f'project/experiments/capacity{n}',f'capacity{n}',f'capacity{n}_top',system)
lab=base+['project/lab/src/lab_top.v']
create('project/lab/c4','lab_c4','lab_top',lab)
create('project/lab/a4','lab_a4','lab_a4_top',lab)
create('project/lab/silent','lab_silent','lab_silent_top',lab)
print('GOWIN_PROJECTS_CREATED system, capacity16/32, lab c4/a4/silent')

"""Recreate the two five-IO mono board projects, with verified constraints."""
from pathlib import Path
import os

HERE = Path(__file__).resolve().parents[1]
INSTRUMENT = HERE.parents[1] / 'instrument/src'

def main():
    sources = sorted((HERE/'fm/src').glob('*.v')) + sorted((HERE/'pluck/src').glob('*.v'))
    if not sources:
        raise SystemExit('Voice sources missing; generate them before project wrappers.')
    sources += sorted((HERE/'shared').glob('*.v'))
    sources += [INSTRUMENT/name for name in ('note_table.v','pt8211_tx.v','instrument.cst','instrument.sdc')]
    for voice in ('fm','pluck'):
        folder=HERE/'board'/voice
        folder.mkdir(parents=True,exist_ok=True)
        entries=[]
        for source in sources:
            kind={'.v':'verilog','.cst':'cst','.sdc':'sdc'}[source.suffix]
            relative=Path(os.path.relpath(source,folder)).as_posix()
            entries.append(f'    <File path="{relative}" type="file.{kind}" enable="1"/>')
        name=voice+'_probe'
        (folder/(name+'.gprj')).write_text('''<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE gowin-fpga-project>
<Project>
  <Template>FPGA</Template><Version>5</Version>
  <Device name="GW5AT-60B" pn="GW5AT-LV60PG484AC1/I0">gw5at60b-002</Device>
  <FileList>
'''+ '\n'.join(entries)+'\n  </FileList>\n</Project>\n',encoding='utf-8')
        (folder/'build.tcl').write_text(f'''set project_dir [file dirname [file normalize [info script]]]
open_project [file join $project_dir {name}.gprj]
set_option -top_module {name}_top
set_option -output_base_name {name}
run all
''',encoding='utf-8')
    print('TIMBRE_PROJECTS_CREATED fm_probe, pluck_probe')

if __name__=='__main__':
    main()

"""Run V2 tests with current-source fingerprints and an exact fast sine ROM."""
from pathlib import Path
import argparse
import hashlib
import importlib.util
import json
import re
import subprocess
import xml.etree.ElementTree as ET

LAB = Path(__file__).resolve().parents[1]
ROOT = LAB.parents[1]
SIM = LAB / 'sim'
parser = argparse.ArgumentParser()
parser.add_argument('--modelsim', default='E:/QuartusII/modelsim_ase/win32aloem')
parser.add_argument('--test', action='append')
parser.add_argument('--pluck', type=int, default=8)
parser.add_argument('--ram', action='store_true')
parser.add_argument('--mode', type=int, default=0, choices=[0,1,2])
args = parser.parse_args()
SIM.mkdir(exist_ok=True)


def run(tool, options):
    result = subprocess.run([str(Path(args.modelsim) / tool), *options], cwd=SIM,
                            capture_output=True, text=True, errors='replace')
    log = result.stdout + '\n' + result.stderr
    if result.returncode or re.search(r'\*\* (?:Error|Fatal)', log):
        raise RuntimeError(log[-6500:])
    return log


sources = [(LAB / item.attrib['path']).resolve() for item in ET.parse(LAB / 'audio_v2.gprj').iter('File')
           if item.attrib['type'] == 'file.verilog']
sources = [LAB / 'src/audio_v2_bank_compact.v' if p.name == 'audio_v2_bank.v' else p for p in sources]
sources += [LAB / 'src/audio_v2_pluck.v', LAB / 'src/audio_v2_pool_slot.v', LAB / 'src/audio_v2_tone.v']
sources += [LAB.parent / 'audio_core_v1/src' / name for name in
            ('audio_voice_bank.v', 'audio_voice_slot.v', 'audio_voice_state.v')]
sources += sorted(SIM.glob('*_tb.v'))
inputs = sources + [LAB / 'audio_v2.gprj', Path(__file__).resolve()]
hashes = {p.relative_to(ROOT).as_posix(): hashlib.sha256(p.read_bytes()).hexdigest() for p in inputs}
spec = importlib.util.spec_from_file_location('sim_rom_v1', LAB.parent / 'audio_core_v1/tools/sim_rom.py')
rom_module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(rom_module)
rom = rom_module.prepare_and_verify(args.modelsim)
sources = [Path(rom['replacement_source']) if p.name == 'palette_sine.v' else p for p in sources]
library = 'work_v2_compact'
if not (SIM / library).exists():
    run('vlib.exe', [library])
run('vlog.exe', ['-vlog01compat', '-work', library, *map(str, sources)])
tests = args.test or ['v2_bank_tb', 'v2_core_tb', 'v2_board_tb', 'v2_extended_tb']
records = []
for name in tests:
    log_name=f'{name}_{library}_p{args.pluck}_m{args.mode}.log'
    options = ['-c', '-lib', library, name, '-l', log_name, '-do',
               'onerror {quit -code 1 -f}; onbreak {quit -code 1 -f}; run -all; quit -f']
    if name == 'v2_bank_tb':
        options += [f'-gP={args.pluck}',f'-gMODE={args.mode}']
    elif name in ('v2_core_tb','v2_board_tb','v2_extended_tb'):
        options += [f'-gP={args.pluck}']
    log = run('vsim.exe', options)
    marker = name.upper().replace('_TB', '_TB_PASS')
    result = next((line for line in log.splitlines() if marker in line), None)
    if result is None:
        raise RuntimeError('Missing PASS marker: ' + name)
    if hashes != {p.relative_to(ROOT).as_posix(): hashlib.sha256(p.read_bytes()).hexdigest() for p in inputs}:
        raise RuntimeError('Source changed during simulation')
    records.append({'test': name, 'result': result, 'source_sha256': hashes,
                    'log':log_name,'mode':args.mode,
                    'log_sha256': hashlib.sha256((SIM / log_name).read_bytes()).hexdigest()})
    print(result, flush=True)
results = LAB / 'results'
results.mkdir(exist_ok=True)
for record in records:
    (results / f'{record["test"]}_compact_p{args.pluck}_m{args.mode}.json').write_text(json.dumps(record, indent=2) + '\n', encoding='utf-8')

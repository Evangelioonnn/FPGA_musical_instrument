"""Compare the packed voice RAM against accepted V2 and its existing models."""
from pathlib import Path
import argparse
import hashlib
import importlib.util
import json
import re
import subprocess
import xml.etree.ElementTree as ET

ROOT = Path(__file__).resolve().parents[1]
LAB = ROOT / 'project/audio_core_v2'
PACKED = ROOT / 'project/audio_integration/optimized'
parser = argparse.ArgumentParser()
parser.add_argument('--modelsim', default='E:/QuartusII/modelsim_ase/win32aloem')
parser.add_argument('--test', action='append')
args = parser.parse_args()
SIM = PACKED / 'impl/sim'
SIM.mkdir(parents=True, exist_ok=True)
tests = args.test or ['packed_equivalence_tb', 'v2_bank_tb', 'v2_modulation_tb',
                     'v2_core_tb', 'v2_board_tb', 'v2_extended_tb',
                     'v2_latency_tb', 'v2_pitch32_tb']
sources = [(LAB / item.attrib['path']).resolve()
           for item in ET.parse(LAB / 'audio_v2.gprj').iter('File')
           if item.attrib['type'] == 'file.verilog']
sources = [PACKED / 'audio_v2_bank_packed.v' if p.name == 'audio_v2_bank_stream.v'
           else p for p in sources]
sources += [LAB.parent / 'audio_core_v1/src' / name
            for name in ('audio_voice_bank.v', 'audio_voice_slot.v', 'audio_voice_state.v')]
baseline = LAB / 'src/audio_v2_bank_stream.v'
reference = SIM / 'audio_v2_bank_reference.v'
text = baseline.read_text()
assert text.count('module audio_v2_bank #') == 1
reference.write_text(text.replace('module audio_v2_bank #',
                                 'module audio_v2_bank_reference #'), encoding='ascii')
sources.append(reference)
input_benches = []
for name in tests:
    source = PACKED / 'sim' / f'{name}.v' if name.startswith('packed_') else LAB / 'sim' / f'{name}.v'
    input_benches.append(source)
    if name == 'v2_core_tb':
        old = 'dut.bank.state_mem[0][174:159]'
        body = source.read_text()
        assert body.count(old) == 1
        target = SIM / source.name
        target.write_text(body.replace(old, 'dut.bank.state_mem[1][73:58]'), encoding='ascii')
        sources.append(target)
    else:
        sources.append(source)
sources = list(dict.fromkeys(sources))
inputs = [p for p in sources if SIM not in p.parents] + input_benches + [baseline, Path(__file__).resolve()]
inputs = list(dict.fromkeys(inputs))
sha = lambda p: hashlib.sha256(p.read_bytes()).hexdigest()
hashes = {p.relative_to(ROOT).as_posix(): sha(p) for p in inputs}
spec = importlib.util.spec_from_file_location('sim_rom_v1', LAB.parent / 'audio_core_v1/tools/sim_rom.py')
rom_module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(rom_module)
rom = rom_module.prepare_and_verify(args.modelsim)
sources = [Path(rom['replacement_source']) if p.name == 'palette_sine.v' else p for p in sources]


def run(tool, options):
    result = subprocess.run([str(Path(args.modelsim) / tool), *options], cwd=SIM,
                            capture_output=True, text=True, errors='replace')
    log = result.stdout + '\n' + result.stderr
    if result.returncode or re.search(r'\*\* (?:Error|Fatal)', log):
        raise RuntimeError(log[-7000:])
    return log


library = 'work_packed'
if not (SIM / library).exists():
    run('vlib.exe', [library])
run('vlog.exe', ['-vlog01compat', '-work', library, *map(str, sources)])
records = []
for name in tests:
    options = ['-c', '-lib', library, name, '-l', f'{name}.log', '-do',
               'onerror {quit -code 1 -f}; onbreak {quit -code 1 -f}; run -all; quit -f']
    if name in ('v2_bank_tb', 'v2_modulation_tb', 'v2_core_tb',
                'v2_board_tb', 'v2_extended_tb', 'v2_latency_tb'):
        options.append('-gP=12')
    log = run('vsim.exe', options)
    marker = name.upper().replace('_TB', '_TB_PASS')
    result = next((line for line in log.splitlines() if marker in line), None)
    if result is None:
        raise RuntimeError('Missing PASS marker: ' + name)
    if hashes != {p.relative_to(ROOT).as_posix(): sha(p) for p in inputs}:
        raise RuntimeError('Source changed during simulation')
    records.append({'test': name, 'result': result,
                    'source_sha256': hashes,
                    'log_sha256': sha(SIM / f'{name}.log')})
    (PACKED / 'results').mkdir(exist_ok=True)
    (PACKED / 'results' / f'{name}.json').write_text(json.dumps(records[-1], indent=2) + '\n', encoding='utf-8')
    print(result, flush=True)

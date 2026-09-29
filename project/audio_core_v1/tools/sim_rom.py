"""Prepare and verify an exact simulation-only array implementation of the ROM.

The synthesised palette_sine source and Gowin project remain unchanged.
prepare_and_verify(modelsim=...) returns the verified replacement source and
provenance for a caller's own simulation library.
"""
from pathlib import Path
import argparse
import hashlib
import json
import re
import subprocess
import tempfile
import time

LAB = Path(__file__).resolve().parents[1]
ROOT = LAB.parents[1]
SIM = LAB / 'sim'
DATA = SIM / 'work_rom_data'
ROM = ROOT / 'project/audio_palette_lab/src/palette_sine.v'
BENCH = SIM / 'sine_rom_equivalence_tb.v'
DEFAULT_MODELSIM = 'E:/QuartusII/modelsim_ase/win32aloem'


def _sha(data):
    return hashlib.sha256(data).hexdigest()


def _extract_table(source):
    header = (
        r'\A(?:[ \t]*//[^\n]*\n)*\s*module\s+palette_sine\s*\(\s*'
        r'input\s+wire\s+clk\s*,\s*input\s+wire\s*\[\s*11\s*:\s*0\s*\]\s*addr\s*,\s*'
        r'output\s+reg\s+signed\s*\[\s*15\s*:\s*0\s*\]\s*data\s*=\s*0\s*\)\s*;\s*'
        r'always\s*@\s*\(\s*posedge\s+clk\s*\)\s*case\s*\(\s*addr\s*\)'
    )
    match = re.fullmatch(header + r'(?P<body>.*?)\bendcase\s+endmodule\s*', source, re.S)
    if match is None:
        raise ValueError('palette_sine module/ports/initial value/posedge case shape changed')
    entry = re.compile(r"12'd(?P<address>\d+)\s*:\s*data\s*<=\s*16'h(?P<value>[0-9a-fA-F]{4})\s*;")
    body = match.group('body')
    entries = list(entry.finditer(body))
    if entry.sub('', body).strip():
        raise ValueError('Unexpected ROM case statement, comment, default or extra logic')
    if len(entries) != 4096:
        raise ValueError(f'Expected4096 explicit case entries, found{len(entries)}')
    values = {}
    for item in entries:
        address = int(item['address'])
        if address not in range(4096) or address in values:
            raise ValueError(f'Duplicate or out-of-range ROM address{address}')
        values[address] = item['value'].lower()
    if set(values) != set(range(4096)):
        raise ValueError('ROM address coverage is incomplete')
    return [values[index] for index in range(4096)]


def prepare_and_verify(modelsim=DEFAULT_MODELSIM):
    """Return verified simulation replacement paths and exact source hashes.

    Generated ROM sources remain under sim/work_rom_data. The checker uses a
    fresh temporary ModelSim library and never touches a main rendering library.
    """
    started = time.time()
    inputs = [ROM, BENCH, Path(__file__).resolve()]
    input_bytes = {path: path.read_bytes() for path in inputs}
    raw_hashes = {path.relative_to(ROOT).as_posix(): _sha(data) for path, data in input_bytes.items()}
    lf_hashes = {path.relative_to(ROOT).as_posix(): _sha(data.replace(b'\r\n', b'\n'))
                 for path, data in input_bytes.items()}
    source = input_bytes[ROM].decode('ascii').replace('\r\n', '\n')
    values = _extract_table(source)
    DATA.mkdir(parents=True, exist_ok=True)
    check_root = ROOT / 'tmp/audio_integration_sim'
    check_root.mkdir(parents=True, exist_ok=True)
    check_dir = Path(tempfile.mkdtemp(prefix='rom-check-', dir=check_root))
    hex_path = DATA / 'sine4096.hex'
    replacement = DATA / 'palette_sine_array.v'
    reference = DATA / 'palette_sine_reference.v'
    hex_path.write_text('\n'.join(values) + '\n', encoding='ascii', newline='\n')
    renamed, count = re.subn(r'\bmodule\s+palette_sine\b', 'module palette_sine_reference', source, count=1)
    if count != 1:
        raise ValueError('Could not rename the accepted reference module exactly once')
    reference.write_text(renamed, encoding='ascii', newline='\n')
    filename = hex_path.as_posix().replace('"', '\\"')
    replacement.write_text(f'''// Simulation-only exact constant table; never a Gowin project input.
module palette_sine(input wire clk,input wire [11:0] addr,output reg signed [15:0] data=0);
    reg signed [15:0] rom_words [0:4095];
    initial $readmemh("{filename}",rom_words);
    // The original full case has no default: any X/Z address retains data.
    always @(posedge clk) if((^addr)!==1'bx) data<=rom_words[addr];
endmodule
''', encoding='ascii', newline='\n')

    def run(tool, options):
        result = subprocess.run([str(Path(modelsim) / tool), *options], cwd=check_dir,
                                capture_output=True, text=True, errors='replace')
        log = result.stdout + '\n' + result.stderr
        if result.returncode or re.search(r'\*\* (Error|Fatal)', log):
            raise RuntimeError(tool + ' failed:\n' + log[-6000:])
        return log

    run('vlib.exe', ['work'])
    run('vlog.exe', ['-vlog01compat', '-work', 'work',
                     str(reference), str(replacement), str(BENCH)])
    log = run('vsim.exe', ['-c', '-lib', 'work', 'sine_rom_equivalence_tb',
                           '-l', 'equivalence.log', '-do', 'run -all; quit -f'])
    marker = next((line for line in log.splitlines() if 'SINE_ROM_ARRAY_EQUIVALENCE_PASS' in line), None)
    if marker is None:
        raise RuntimeError('ROM checker did not report PASS:\n' + log[-6000:])
    for path, original in input_bytes.items():
        if path.read_bytes() != original:
            raise RuntimeError('A checker input changed while running: ' + str(path))
    result = dict(replacement_source=str(replacement), reference_source=str(reference),
                  rom_data=str(hex_path), bench_source=str(BENCH),
                  table_entries=4096, all_address_checks=4096,
                  unknown_address_checks=8, consecutive_jump_checks=2048,
                  initial_zero_checked=True, pass_marker=marker,
                  source_sha256=raw_hashes, source_lf_sha256=lf_hashes,
                  generated_sha256={path.relative_to(ROOT).as_posix(): _sha(path.read_bytes())
                                    for path in (replacement, reference, hex_path)},
                  verification_seconds=round(time.time() - started, 3),
                  verification_workspace=check_dir.relative_to(ROOT).as_posix(),
                  synthesis_sources_changed=False, full_audio_chain_verified=False)
    (DATA / 'verification.json').write_text(json.dumps(result, indent=2) + '\n', encoding='ascii', newline='\n')
    return result


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('--modelsim', default=DEFAULT_MODELSIM)
    args = parser.parse_args()
    print(json.dumps(prepare_and_verify(args.modelsim), indent=2))

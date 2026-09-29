from pathlib import Path
import argparse
from datetime import datetime, timezone
import hashlib
import json
import re
import subprocess

HERE = Path(__file__).resolve().parent
parser = argparse.ArgumentParser()
parser.add_argument('--modelsim', default='E:/QuartusII/modelsim_ase/win32aloem')
parser.add_argument('--output', type=Path,
                    default=HERE.parent / 'results' / 'parameters_validation.json')
args = parser.parse_args()


def run(tool, options):
    result = subprocess.run([str(Path(args.modelsim) / tool), *options],
                            cwd=HERE, capture_output=True, text=True,
                            errors='replace')
    log = result.stdout + '\n' + result.stderr
    if result.returncode or re.search(r'\*\* (Error|Fatal)', log):
        raise RuntimeError(f'{tool} failed:\n{log[-6000:]}')
    return log


source = HERE.parent / 'src' / 'audio_parameter_service.v'
benches = sorted(HERE.glob('*_tb.v'))
result = {
    'scope': 'independent parameter targets and fader pickup RTL',
    'status': 'RUNNING',
    'timestamp_utc': datetime.now(timezone.utc).isoformat(),
    'modelsim_directory': args.modelsim,
    'source_hashes': {
        str(path.relative_to(HERE.parent)).replace('\\', '/'):
        hashlib.sha256(path.read_bytes()).hexdigest()
        for path in [source, *benches]
    },
    'tests': [],
    'not_verified': [
        'physical SPI ADC, J13 electrical wiring and actual fader noise',
        'physical input-to-analog-output latency or analog audio quality',
        'whole-design resource use and setup/hold timing',
        'display or Bluetooth hardware integration',
    ],
}
try:
    if not (HERE / 'work_parameters').exists():
        run('vlib.exe', ['work_parameters'])
    run('vlog.exe', ['-vlog01compat', '-work', 'work_parameters',
                      str(source), *[str(path) for path in benches]])
    for top in ('audio_parameter_tb', 'audio_fader_range_tb'):
        log = run('vsim.exe', ['-c', '-lib', 'work_parameters', top,
                             '-l', f'{top}_transcript.log',
                             '-do', 'run -all; quit -f'])
        marker = top.upper() + '_PASS'
        if marker not in log:
            raise RuntimeError(f'{top} did not report PASS:\n{log[-6000:]}')
        line = next(line for line in log.splitlines() if marker in line)
        result['tests'].append({'test': top, 'status': 'PASS', 'result': line})
        print(line)
    result['status'] = 'PASS'
except Exception as exc:
    result['status'] = 'FAIL'
    result['error'] = str(exc)
    raise
finally:
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(result, indent=2) + '\n', encoding='utf-8')

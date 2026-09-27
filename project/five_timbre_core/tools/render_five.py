"""Render actual bank PCM; verify preserved presets against the gallery hashes."""
from concurrent.futures import ThreadPoolExecutor, as_completed
from pathlib import Path
import argparse
import hashlib
import json
import math
import re
import struct
import subprocess
import wave

HERE = Path(__file__).resolve().parents[1]
SIM = HERE / 'sim'
ROOT = HERE.parents[1]
NAMES = ('precision_piano', 'original_pluck', 'warm_pluck',
         'metallic_bell', 'drive_lead')
OLD_IDS = {0: 0, 2: 1, 3: 7, 4: 5}
OLD_RESULTS = json.loads((ROOT / 'project/timbre_gallery/sim/render_results.json').read_text())


def render(mode, preset, modelsim, short):
    tag = f'five_render_{mode}_{preset}'
    command = [str(Path(modelsim) / 'vsim.exe'), '-c', '-lib', 'work_five',
               'five_render_tb', f'-gBALANCE_MODE={mode}', f'-gPRESET={preset}',
               f'-gSHORT={int(short)}', '-l', tag + '.log',
               '-wlf', tag + '.wlf', '-do', 'run -all; quit -f']
    result = subprocess.run(command, cwd=SIM, capture_output=True,
                            text=True, errors='replace')
    log = result.stdout + '\n' + result.stderr
    if result.returncode or re.search(r'\*\* (Error|Fatal)', log) or 'FIVE_RENDER_TB_PASS' not in log:
        raise RuntimeError(f'{tag}: {log[-4000:]}')
    return mode, preset


def analyze(mode, preset, short):
    filename = f'five_cadence_{mode}_{preset}_1.txt' if short else f'five_{mode}_{preset}.txt'
    pcm = [int(value) for value in (SIM / filename).read_text().splitlines()]
    assert len(pcm) == (760 if short else 80100), (mode, preset, len(pcm))
    assert all(-32768 < x < 32767 for x in pcm)
    raw = struct.pack('<' + 'h' * len(pcm), *pcm)
    digest = hashlib.sha256(raw).hexdigest()
    if (mode == 0 and preset in OLD_IDS or preset == 3) and not short:
        expected = OLD_RESULTS[OLD_IDS[preset]]['pcm_sha256']
        assert digest == expected, f'old preset changed: {preset} {digest} != {expected}'
    out_dir = SIM / 'audio'
    out_dir.mkdir(exist_ok=True)
    wav_path = out_dir / f'{mode:02d}_{NAMES[preset]}.wav'
    stereo = b''.join(struct.pack('<hh', value, value) for value in pcm)
    with wave.open(str(wav_path), 'wb') as wav:
        wav.setnchannels(2)
        wav.setsampwidth(2)
        wav.setframerate(48077)
        wav.writeframes(stereo)
    bounds = ((100, 13100), (41100, 54100)) if not short else ((60, 560),)
    rms = [math.sqrt(sum(x*x for x in pcm[a:b]) / (b-a)) for a,b in bounds]
    return {'mode':mode, 'preset':preset, 'name':NAMES[preset],
            'frames':len(pcm), 'peak':max(abs(x) for x in pcm),
            'rms_C3_C5':rms, 'pcm_sha256':digest, 'wav':str(wav_path)}


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--modelsim', default='E:/QuartusII/modelsim_ase/win32aloem')
    parser.add_argument('--pairs', default='0:0,0:1,0:2,0:3,0:4,1:0,1:4,2:0,2:4')
    parser.add_argument('--short', action='store_true')
    parser.add_argument('--workers', type=int, default=2)
    args = parser.parse_args()
    pairs = [tuple(map(int, part.split(':'))) for part in args.pairs.split(',')]
    assert all(mode in (0,1,2) and 0 <= preset < 5 for mode,preset in pairs)
    with ThreadPoolExecutor(max_workers=args.workers) as pool:
        jobs = [pool.submit(render, mode, preset, args.modelsim, args.short)
                for mode,preset in pairs]
        for job in as_completed(jobs):
            print('FIVE_RENDER_TB_PASS', *job.result(), flush=True)
    results = [analyze(mode,preset,args.short) for mode,preset in pairs]
    output = SIM / ('render_short_results.json' if args.short else 'render_results.json')
    existing = json.loads(output.read_text()) if output.exists() else []
    combined = {(item['mode'],item['preset']): item for item in existing}
    combined.update({(item['mode'],item['preset']): item for item in results})
    output.write_text(json.dumps([combined[key] for key in sorted(combined)], indent=2) + '\n')
    for result in results:
        print(result, flush=True)


if __name__ == '__main__':
    main()

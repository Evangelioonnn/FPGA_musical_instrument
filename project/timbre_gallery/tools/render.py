"""Render each candidate from the actual gallery_bank RTL, before master gain."""
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
NAMES = ('piano', 'warm_pluck', 'organ', 'pad', 'clean_lead',
         'drive_lead', 'electric_keys', 'metallic_bell')
EXPECTED_FRAMES = 80100


def render_one(preset, modelsim, fast=1, short=0):
    tag = f'gallery_render_{preset}_{fast}_{short}'
    command = [str(Path(modelsim) / 'vsim.exe'), '-c', '-lib', 'work_gallery',
               'gallery_render_tb', f'-gPRESET={preset}', f'-gFAST={fast}',
               f'-gSHORT={short}', '-l', tag + '.log',
               '-wlf', tag + '.wlf', '-do', 'run -all; quit -f']
    result = subprocess.run(command, cwd=SIM, capture_output=True,
                            text=True, errors='replace')
    log = result.stdout + '\n' + result.stderr
    (SIM / (tag + '.log')).write_text(log, encoding='utf-8')
    if result.returncode or re.search(r'\*\* (Error|Fatal)', log) or 'GALLERY_RENDER_TB_PASS' not in log:
        raise RuntimeError(f'{tag}: {log[-2500:]}')
    return next(line for line in log.splitlines() if 'GALLERY_RENDER_TB_PASS' in line)


def analyze_one(preset, output):
    pcm = [int(value) for value in (SIM / f'gallery_{preset}.txt').read_text().splitlines()]
    assert len(pcm) == EXPECTED_FRAMES, (preset, len(pcm))
    assert all(-32768 < x < 32767 for x in pcm), preset
    assert all(x == 0 for x in pcm[:100]), preset
    # Bounds correspond to the C3, C4, C5 and C-major chord passages.
    bounds = ((100, 13100), (13100, 41100), (41100, 54100), (54100, 80100))
    rms = [math.sqrt(sum(x * x for x in pcm[start:end]) / (end - start))
           for start, end in bounds]
    assert all(value > 10 for value in rms), (preset, rms)
    raw = struct.pack('<' + 'h' * len(pcm), *pcm)
    stereo = b''.join(struct.pack('<hh', x, x) for x in pcm)
    filename = NAMES[preset] + '.wav'
    with wave.open(str(output / filename), 'wb') as wav:
        wav.setnchannels(2)
        wav.setsampwidth(2)
        wav.setframerate(48077)
        wav.writeframes(stereo)
    return {'preset': preset, 'name': NAMES[preset], 'frames': len(pcm),
            'peak': max(abs(x) for x in pcm), 'rms_by_passage': rms,
            'dc_mean': sum(pcm) / len(pcm),
            'clip_samples': sum(x in (-32768, 32767) for x in pcm),
            'pcm_sha256': hashlib.sha256(raw).hexdigest()}


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--modelsim', default='E:/QuartusII/modelsim_ase/win32aloem')
    parser.add_argument('--workers', type=int, default=3)
    parser.add_argument('--presets', default='0,1,2,3,4,5,6,7')
    parser.add_argument('--cadence', action='store_true')
    parser.add_argument('--analyze-only', action='store_true')
    args = parser.parse_args()
    presets = [int(value) for value in args.presets.split(',')]
    assert all(0 <= value < 8 for value in presets)
    if args.cadence:
        with ThreadPoolExecutor(max_workers=args.workers) as pool:
            pending = [pool.submit(render_one, preset, args.modelsim, fast, 1)
                       for preset in presets for fast in (0, 1)]
            for job in as_completed(pending):
                print(job.result(), flush=True)
        for preset in presets:
            first = (SIM / f'gallery_cadence_{preset}_0.txt').read_bytes()
            second = (SIM / f'gallery_cadence_{preset}_1.txt').read_bytes()
            assert first == second, f'cadence mismatch preset {preset}'
        print('GALLERY_CADENCE_EQUIVALENCE_PASS all requested presets', flush=True)
        return
    if not args.analyze_only:
        with ThreadPoolExecutor(max_workers=args.workers) as pool:
            pending = [pool.submit(render_one, preset, args.modelsim) for preset in presets]
            for job in as_completed(pending):
                print(job.result(), flush=True)
    output = SIM / 'audio'
    output.mkdir(exist_ok=True)
    stats = [analyze_one(preset, output) for preset in range(8)]
    (SIM / 'render_results.json').write_text(json.dumps(stats, indent=2) + '\n', encoding='utf-8')
    print(json.dumps(stats, indent=2), flush=True)


if __name__ == '__main__':
    main()

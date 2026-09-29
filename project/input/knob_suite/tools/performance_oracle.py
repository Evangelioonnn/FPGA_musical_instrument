"""Check every mixed performance sample against independent musical math.

No RTL ROM, rendered isolated voice, or active-voice normalization is used.
The expected signal is the sum of 20 independently generated struck notes.
"""
from pathlib import Path
import argparse
import hashlib
import json
import math
from create_projects import HERE, ROOT

FS = 50_000_000 / 1040
TOTAL = 384616
GATE = 31250
ATTACK_END = math.ceil(65535 / 68)
DECAY_END = ATTACK_END + math.ceil((65535 - 32768) / 6)
END = GATE + math.ceil(32768 / 3)


def score():
    events = [(4807, 1), (48077, 1)]
    events += [(n, 1) for n in range(96154, 153846, 4808)]
    events += [(n, -1) for n in range(168269, 196154, 4808)]
    note = 60
    for frame, direction in events:
        note = max(48, min(84, note + direction))
        yield frame, note


def envelope(age):
    if age <= ATTACK_END:
        return min(65535, age * 68)
    if age <= DECAY_END:
        return max(32768, 65535 - (age - ATTACK_END) * 6)
    if age <= GATE:
        return 32768
    return max(0, 32768 - (age - GATE) * 3)


def expected_signal(length):
    sine = [round(32767 * math.sin(2 * math.pi * i / 1024)) for i in range(1024)]
    expected = [0] * length
    active = [0] * length
    for frame, note in score():
        step = round(440 * 2 ** ((note - 69) / 12) * 2**32 / FS)
        # A frame-boundary event starts its voice before the next sample tick.
        for age in range(1, min(END + 1, length - frame)):
            phase = (age * step) % 2**32
            level = envelope(age)
            expected[frame + age] += sine[phase >> 22] * level // 2**22
            if level:
                active[frame + age] += 1
    return expected, max(active)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--sim-dir', type=Path, default=HERE / 'sim')
    parser.add_argument('--allow-prefix', action='store_true', help='Live progress only; no final evidence written')
    args = parser.parse_args()
    path = args.sim_dir / 'performance_samples.txt'
    raw = path.read_bytes()
    lines = raw.splitlines()
    if not raw.endswith(b'\n'):
        lines = lines[:-1]
    samples = [int(x) for x in lines]
    assert 0 < len(samples) <= TOTAL
    if not args.allow_prefix:
        assert len(samples) == TOTAL, len(samples)
    expected, max_active = expected_signal(len(samples))
    mismatches = [(n, got, want) for n, (got, want) in enumerate(zip(samples, expected)) if got != want]
    assert not mismatches, (len(mismatches), mismatches[:12])
    report = {'source': 'independent equal-temperament DDS and analytical ADSR, exact integer sum',
              'samples_checked': len(samples), 'events': list(score()),
              'max_audible_voices': max_active, 'mismatches': 0,
              'per_voice_gain': 'unchanged; no division by voice count',
              'pcm_sha256': hashlib.sha256(raw).hexdigest(),
              'full_render': len(samples) == TOTAL}
    if not args.allow_prefix:
        out = ROOT / 'evidence/knob_suite_2026-09-20/performance_oracle.json'
        out.write_text(json.dumps(report, indent=2) + '\n', encoding='utf-8')
    print('PERFORMANCE_ORACLE_PASS samples=' + str(len(samples)) + ' max_audible=' + str(max_active))


if __name__ == '__main__':
    main()

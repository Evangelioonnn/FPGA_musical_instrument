"""Recheck saved RTL references after the first knob-suite board listening.

This reads reference WAVs, not physical-board captures. The musical model is
independent of the RTL tables; real asynchronous detent timing is not reproduced.
"""
from pathlib import Path
import array
import hashlib
import json
import math
import sys
import wave
from create_projects import ROOT
from performance_oracle import FS, END, envelope, expected_signal, score


def read_pcm(name):
    path = ROOT / 'evidence/audio' / ('knob_' + name + '_raw.wav')
    with wave.open(str(path), 'rb') as source:
        assert source.getnchannels() == 1 and source.getsampwidth() == 2
        assert source.getframerate() == round(FS)
        samples = array.array('h', source.readframes(source.getnframes()))
        if sys.byteorder != 'little':
            samples.byteswap()
    return list(samples), hashlib.sha256(path.read_bytes()).hexdigest()


def main():
    pcm = {}
    report = {'source': 'Saved RTL WAVs, not board recordings',
              'scope': 'Fixed reference score only; asynchronous hardware triggers and analog output remain unmeasured',
              'audio': {}}
    for name in ('performance', 'timbre', 'release', 'volume', 'echo'):
        values, fingerprint = read_pcm(name)
        pcm[name] = values
        report['audio'][name] = {
            'sha256': fingerprint, 'samples': len(values),
            'peak_raw': max(map(abs, values)),
            'max_adjacent_sample_difference': max(abs(a - b) for a, b in zip(values, values[1:]))}
    # First four events precede any selection of pluck or FM.
    length = 96000
    expected = [0] * length
    sine = [round(32767 * math.sin(2 * math.pi * i / 1024)) for i in range(1024)]
    for event, note in ((0, 60), (24038, 64), (48076, 67), (72114, 72)):
        step = round(440 * 2 ** ((note - 69) / 12) * 2**32 / FS)
        for age in range(1, min(END + 1, length - event)):
            phase = age * step % 2**32
            expected[event + age] += sine[phase >> 22] * envelope(age) // 2**22
    assert pcm['timbre'][:length] == expected, 'Unexpected sample in default-timbre segment'
    performance, active = expected_signal(len(pcm['performance']))
    assert pcm['performance'] == performance, 'Unexpected performance sample'
    assert not any(performance[round(5.1 * FS):]), 'Nonzero digital silent tail'
    report['independent_checks'] = {'default_timbre_samples_exact': length,
                                  'performance_samples_exact': len(performance),
                                  'performance_max_audible_voices': active,
                                  'performance_silent_tail_nonzero_samples': 0}
    report['timbre_timing_ms'] = {
        'onset_interval': 24038 / FS * 1000,
        'original_gate': 31250 / FS * 1000,
        'original_release_from_sustain': math.ceil(32768 / 3) / FS * 1000,
        'previous_release_start_after_next_onset': (31250 - 24038) / FS * 1000,
        'previous_envelope_zero_after_next_onset': (END - 24038) / FS * 1000}
    report['performance_onsets'] = []
    for event, note in score():
        first = event + 1
        report['performance_onsets'].append({
            'sample': first, 'time_seconds': first / FS, 'note': note,
            'mixed_pcm_step': performance[first] - performance[first - 1],
            'max_mixed_step_first_2ms': max(abs(performance[j] - performance[j - 1])
                                          for j in range(first, first + 97))})
    out = ROOT / 'evidence/knob_suite_2026-09-20/onset_reference_analysis.json'
    out.write_text(json.dumps(report, indent=2) + '\n', encoding='utf-8', newline='\n')
    print('ONSET_REFERENCE_CHECK_PASS timbre_default=96000 performance=384616 digital_tail_zero=1')


if __name__ == '__main__':
    main()

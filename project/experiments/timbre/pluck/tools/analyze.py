"""Independent floating physical expectation vs real RTL captures.

This is the accepted fractional Karplus-Strong recurrence, evaluated in float64.
It does not reproduce fixed-point shifts/rounding or read the HDL delay table.
Only the PRNG excitation is shared, so the same musical gesture is compared.
"""
from pathlib import Path
import json
import math
import wave
import numpy as np

FS = 50_000_000 / 1040
BASE = Path(__file__).resolve().parents[1]
SIM = BASE / 'sim'
SCALE = 32767 * .24


def excitation(seed, length):
    x = seed or 1
    values = []
    for _ in range(length):
        x ^= (x << 13) & 0xffffffff
        x ^= x >> 17
        x ^= (x << 5) & 0xffffffff
        signed = (x >> 9) - (2 ** 23 if x & 0x80000000 else 0)
        values.append(signed / 2 ** 22)
    result = np.array(values, dtype=float)
    return result - result.mean()


def reference(note, length, seed, velocity=1.):
    delay = FS / (440 * 2 ** ((note - 69) / 12)) - .5
    integer = math.floor(delay)
    fraction = delay - integer
    ring = excitation(seed, integer + 2)
    y = np.empty(length)
    previous = 0.
    pointer = 0
    for i in range(length):
        a = ring[(pointer - integer) % len(ring)]
        b = ring[(pointer - integer - 1) % len(ring)]
        value = (1. - fraction) * a + fraction * b
        ring[pointer] = .997 * (value + previous) * .5
        previous = value
        pointer = (pointer + 1) % len(ring)
        y[i] = SCALE * velocity * value
    return y


def frequency(samples, expected):
    # Independent long-window spectral peak, narrowly around the requested note.
    length = min(len(samples), round(FS * 1.5))
    y = samples[:length].astype(float)
    y -= y.mean()
    transform = np.abs(np.fft.rfft(y * np.hanning(len(y)), 2 ** 21))
    bins = np.fft.rfftfreq(2 ** 21, 1 / FS)
    lo = np.searchsorted(bins, expected * .97)
    hi = np.searchsorted(bins, expected * 1.03)
    peak = lo + int(np.argmax(transform[lo:hi]))
    a, b, c = np.log(transform[peak-1:peak+2] + 1e-30)
    correction = .5 * (a - c) / (a - 2 * b + c)
    return (peak + correction) * FS / 2 ** 21


def rms(y):
    return float(np.sqrt(np.mean(np.asarray(y, dtype=float) ** 2)))


def main():
    report = {'fs': FS, 'model': 'float64 original .997 fractional-delay recurrence; same xorshift excitation',
              'notes': [], 'passed': []}
    peak = 0
    for note in [36, 60, 84]:
        actual = np.loadtxt(SIM / f'pitch{note}.txt', dtype=np.int64)
        assert len(actual) == 120000
        expected = reference(note, len(actual), 2000 + note)
        error = actual - expected
        target = 440 * 2 ** ((note - 69) / 12)
        measured = frequency(actual, target)
        cents = 1200 * math.log2(measured / target)
        early = rms(actual[:round(FS * .1)])
        late = rms(actual[round(FS * 1.4):round(FS * 1.5)])
        peak = max(peak, int(np.max(np.abs(actual))))
        row = {'note': note, 'requested_hz': target, 'measured_hz': measured,
               'cents_error': cents, 'model_max_error_lsb': float(np.max(np.abs(error))),
               'model_rms_error_lsb': rms(error), 'normalized_rms_error': rms(error)/rms(expected),
               'initial_100ms_rms': early, 'late_100ms_rms': late}
        print(row)
        assert abs(cents) <= 5, row
        assert rms(error)/rms(expected) < .01, row
        assert np.max(np.abs(error)) < 5, row
        assert 0 <= late < early, row
        report['notes'].append(row)
    report['passed'] += ['low/middle/high pitch within 5 cents', 'same-excitation float model <1% relative RMS and <5 LSB max',
                         'natural decay at all three notes', 'no raw saturation']
    assert peak < 32767
    velocities = np.loadtxt(SIM / 'velocity.txt', dtype=np.int64).reshape(4,4096)
    assert np.array_equal(velocities[2], velocities[3]), 'velocity clamp failed'
    assert np.max(np.abs(velocities[0] * 4 - velocities[2])) <= 3
    assert np.max(np.abs(velocities[1] * 2 - velocities[2])) <= 1
    report['passed'] += ['velocity linearity 0.25/0.5/1.0', 'overrange velocity equals full scale']
    release = np.loadtxt(SIM / 'release.txt', dtype=np.int64)
    expected = reference(60, 12300, 2060)[5000:]
    # Physical release: 150ms descending straight line, then silence.
    env = np.maximum(0, 1 - np.arange(7300) / round(FS * .15))
    expected *= env
    assert np.max(np.abs(release - expected)) < 5
    assert np.all(release[7211:] == 0)
    report['release_duration_ms'] = 7212 / FS * 1000
    report['release_max_error_lsb'] = float(np.max(np.abs(release-expected)))
    report['passed'] += ['150ms linear release and exact silence']
    audition = np.loadtxt(SIM / 'audition.txt', dtype=np.int64)
    assert len(audition) == 360580
    assert np.max(np.abs(audition)) < 32767
    wav = SIM / 'pluck_rtl_raw.wav'
    with wave.open(str(wav), 'wb') as f:
        f.setparams((1,2,48077,0,'NONE','not compressed'))
        f.writeframes(audition.astype('<i2').tobytes())
    report['audition'] = {'file': wav.name, 'samples': len(audition), 'peak': int(np.max(np.abs(audition))),
                          'rms': rms(audition), 'normalization': 'none; direct signed16 RTL',
                          'seventh_slot': 'single C4 replaces offline three-note chord'}
    report['tested_peak'] = peak
    (SIM / 'analysis.json').write_text(json.dumps(report, indent=2) + '\n', encoding='utf-8')
    print('PLUCK_ANALYSIS_PASS')


if __name__ == '__main__':
    main()

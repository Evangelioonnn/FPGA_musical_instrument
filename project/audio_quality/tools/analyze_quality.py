"""Compare RTL samples; no claim about board analog noise. Requires numpy."""
import json
from pathlib import Path
import numpy as np

ROOT = Path(__file__).resolve().parents[1]
FS = 50_000_000 / 1040
SLOT = 48077


def measure(y, frequency):
    t = np.arange(len(y)) / FS
    basis = np.column_stack((np.sin(2*np.pi*frequency*t),
                             np.cos(2*np.pi*frequency*t), np.ones(len(y))))
    coeff = np.linalg.lstsq(basis, y, rcond=None)[0]
    residual = y - basis @ coeff
    amplitude = np.hypot(coeff[0], coeff[1])
    rms = amplitude / np.sqrt(2)
    residual_rms = np.sqrt(np.mean(residual**2))
    window = np.hanning(len(y))
    spectrum = 2*np.abs(np.fft.rfft(residual*window))/window.sum()
    frequencies = np.fft.rfftfreq(len(y), 1/FS)
    indices = np.flatnonzero((frequencies >= 2000) & (frequencies <= 20000))
    peak = indices[np.argmax(spectrum[indices])]
    return dict(fundamental_rms_codes=float(rms), dc_codes=float(coeff[2]),
                residual_rms_codes=float(residual_rms),
                residual_dbc=float(20*np.log10(residual_rms/rms)),
                strongest_2k_20k_hz=float(frequencies[peak]),
                strongest_2k_20k_dbc=float(20*np.log10(spectrum[peak]/amplitude)))


def main():
    samples = np.loadtxt(ROOT/'sim/ab_samples.txt', dtype=np.int16)
    assert samples.shape == (6*SLOT, 2), samples.shape
    assert samples[:, 0].min() >= -512 and samples[:, 0].max() <= 511
    assert samples[:, 1].min() >= -512 and samples[:, 1].max() <= 512
    assert np.all(samples[:SLOT] == 0) and np.all(samples[5*SLOT:] == 0)
    rows = []
    for slot, note in enumerate((60, 64, 67, 72), start=1):
        frequency = 440*2**((note-69)/12)
        sustain = samples[slot*SLOT+12000:slot*SLOT+29000]
        a, b = [measure(sustain[:, ch].astype(float), frequency) for ch in (0, 1)]
        gain_db = 20*np.log10(b['fundamental_rms_codes']/a['fundamental_rms_codes'])
        # Compare at identical nominal gain; improvement is a software criterion only.
        assert abs(gain_db) < 0.01, (note, gain_db)
        assert b['residual_rms_codes'] < a['residual_rms_codes'], note
        assert abs(b['dc_codes']) < 0.02, note
        assert np.all(samples[slot*SLOT+43000:(slot+1)*SLOT] == 0), note
        rows.append(dict(note=note, target_hz=frequency, A=a, B=b, gain_change_db=float(gain_db)))
    result = dict(sample_rate_hz=FS, samples_per_path=len(samples),
                  source='RTL simulation, not a hardware recording',
                  method='17k-sample sustain; least-squares fundamental+DC removal; Hann FFT',
                  notes=rows)
    (ROOT/'sim/quality_analysis.json').write_text(json.dumps(result, indent=2)+'\n', encoding='utf-8')
    for row in rows:
        print('note={} residual A={:.2f} B={:.2f} dBc; high spur A={:.2f} B={:.2f} dBc'.format(
            row['note'], row['A']['residual_dbc'], row['B']['residual_dbc'],
            row['A']['strongest_2k_20k_dbc'], row['B']['strongest_2k_20k_dbc']))
    print('QUALITY_ANALYSIS_PASS')


if __name__ == '__main__':
    main()

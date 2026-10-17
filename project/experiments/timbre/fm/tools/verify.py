"""Independent closed-form float oracle and spectral/behavior acceptance.

This does not reproduce the RTL recurrence, table lookup or integer arithmetic.
The reference is the previously accepted mathematical FM candidate formula.
NumPy is required; outputs are disposable simulation evidence in ../sim.
"""
from pathlib import Path
import json
import math
import sys
import wave
import numpy as np

ROOT = Path(__file__).resolve().parents[1]
SIM = ROOT / 'sim'
FS = 50_000_000 / 1040
SLOT, GATE, RELEASE = (round(FS*x) for x in (.75, .53, .15))
SCORE = [(48,205),(55,205),(60,205),(64,205),(67,205),(72,205),
         (60,154),(60,64),(60,128),(60,230)]


def cases():
    result = []
    for note in range(36, 85):
        result.append(dict(id=len(result), note=note, velocity=205, samples=8192,
                           gate=-1, group='chromatic'))
    for note in (36,60,84):
        result.append(dict(id=len(result), note=note, velocity=205,
                           samples=round(FS*.95), gate=-1, group='pitch'))
    for velocity in (0,1,64,128,256,511):
        result.append(dict(id=len(result), note=69, velocity=velocity, samples=8192,
                           gate=-1, group='velocity'))
    result.append(dict(id=len(result), note=60, velocity=256, samples=round(FS*3),
                       gate=round(FS*2.5), group='envelope'))
    for note, velocity in SCORE:
        result.append(dict(id=len(result), note=note, velocity=velocity, samples=SLOT,
                           gate=GATE, group='audition'))
    return result


def reference(case):
    t = np.arange(case['samples']) / FS
    frequency = 440 * 2 ** ((case['note'] - 69) / 12)
    velocity = min(case['velocity'], 256) / 256
    envelope = (1 - np.exp(-t/.006)) * np.exp(-t/1.15)
    modulation = (1.2+1.8*velocity) * np.exp(-t/.16)
    phase = 2*np.pi*frequency*t
    result = .13*velocity*32767*envelope*np.sin(phase + modulation*np.sin(phase))
    if case['gate'] >= 0:
        count = len(t)-case['gate']
        fade = np.clip(1-np.arange(count)/(RELEASE-1),0,1)
        result[case['gate']:] *= fade
    return result


def pitch_estimate(values, expected):
    # The stable late segment's fundamental, not the early bright harmonic peak.
    segment = values[round(FS*.35):].astype(float)
    segment -= np.mean(segment)
    nfft = 1 << (len(segment)*16-1).bit_length()
    spectrum = np.abs(np.fft.rfft(segment*np.hanning(len(segment)), n=nfft))
    frequencies = np.fft.rfftfreq(nfft,1/FS)
    a,b = np.searchsorted(frequencies,[expected*.9,expected*1.1])
    peak = a + np.argmax(spectrum[a:b+1])
    left, middle, right = np.log(np.maximum(spectrum[peak-1:peak+2],1e-30))
    fraction = .5*(left-right)/(left-2*middle+right)
    return (peak+fraction)*FS/nfft


def write_wav(path, values):
    with wave.open(str(path),'wb') as out:
        out.setparams((1,2,48077,0,'NONE','not compressed'))
        out.writeframes(np.asarray(values,dtype='<i2').tobytes())


def prepare():
    vectors=cases()
    (SIM/'fm_cases.txt').write_text(''.join(
        f"{c['id']} {c['note']} {c['velocity']} {c['samples']} {c['gate']}\n" for c in vectors))
    (SIM/'fm_cases.json').write_text(json.dumps(vectors,indent=2)+'\n')
    print(f'FM independent reference cases: {len(vectors)}, {sum(c["samples"] for c in vectors)} samples')


def analyze():
    vectors=cases()
    data=np.loadtxt(SIM/'fm_numeric_samples.txt',dtype=np.int64)
    assert data.shape==(sum(c['samples'] for c in vectors),3), data.shape
    offset=0; audition=[]; audition_ref=[]; results=[]; velocity_results={}
    total_error=0.; total_signal=0.; max_error=0.; peak_all=0
    pitch_results=[]
    for case in vectors:
        count=case['samples']; block=data[offset:offset+count]; offset+=count
        assert np.all(block[:,0]==case['id'])
        assert np.array_equal(block[:,1],np.arange(count))
        actual=block[:,2].astype(float); expected=reference(case)
        error=actual-expected
        peak=int(np.max(np.abs(actual))); rms_error=float(np.sqrt(np.mean(error*error)))
        worst=float(np.max(np.abs(error))); peak_all=max(peak_all,peak)
        total_error+=np.sum(error*error);total_signal+=np.sum(expected*expected)
        max_error=max(max_error,worst)
        # Includes table interpolation, Q28 envelope coefficient quantization,
        # final PCM rounding and independent floating-point phase generation.
        assert worst<3.5, (case,worst)
        assert rms_error<1.0, (case,rms_error)
        assert peak<=4261, (case,peak)
        if case['gate']>=0:
            assert np.all(actual[case['gate']+RELEASE-1:]==0),case
        if case['group']=='pitch':
            frequency=440*2**((case['note']-69)/12)
            measured=pitch_estimate(actual,frequency)
            cents=1200*math.log2(measured/frequency)
            assert abs(cents)<=5,(case,cents)
            pitch_results.append(dict(note=case['note'],expected_hz=frequency,
                                      measured_hz=measured,error_cents=cents))
        if case['group']=='velocity':velocity_results[case['velocity']]=actual.copy()
        if case['group']=='audition':
            audition.append(actual);audition_ref.append(np.rint(expected))
        results.append(dict(case,peak=peak,max_abs_error_lsb=worst,rms_error_lsb=rms_error))
    assert np.all(velocity_results[0]==0)
    assert np.array_equal(velocity_results[256],velocity_results[511]),'velocity clamp'
    rms_by_velocity={v:float(np.sqrt(np.mean(x*x))) for v,x in velocity_results.items()}
    assert all(rms_by_velocity[a]<rms_by_velocity[b] for a,b in ((0,1),(1,64),(64,128),(128,256)))
    audio=np.concatenate(audition);float_audio=np.concatenate(audition_ref)
    write_wav(SIM/'fm_rtl_audition.wav',audio)
    write_wav(SIM/'fm_float_same_score.wav',float_audio)
    # A diagnostic difference file deliberately has no normalization, so it is
    # not confused with a timbre. It is not one of the public audition outputs.
    write_wav(SIM/'fm_rtl_minus_float.wav',audio-float_audio)
    report=dict(algorithm='1:1 phase modulation, independent accepted closed-form oracle',
        sample_rate_hz=FS,wav_rate_hz=48077,cases=len(vectors),samples=len(data),
        max_raw_peak=peak_all,max_abs_error_lsb=max_error,
        rms_error_lsb=math.sqrt(total_error/len(data)),
        error_snr_db=10*math.log10(total_signal/total_error),
        pitch=pitch_results,velocity_rms=rms_by_velocity,
        audition_samples=len(audio),audition_peak=int(np.max(np.abs(audio))),
        audition_score=SCORE,audition_mono=True,
        release_samples=RELEASE,slot_samples=SLOT,gate_samples=GATE,
        notes='No normalization. Slot 7 is one C4, not the offline candidate chord.',
        cases_detail=results)
    (SIM/'fm_validation.json').write_text(json.dumps(report,indent=2)+'\n')
    concise={k:v for k,v in report.items() if k!='cases_detail'}
    print(json.dumps(concise,indent=2))
    print('FM_MATHEMATICAL_ACCEPTANCE_PASS')


if __name__=='__main__':
    {'prepare':prepare,'analyze':analyze}[sys.argv[1]]()

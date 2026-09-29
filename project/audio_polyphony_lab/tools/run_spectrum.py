"""Focused real-RTL spectrum evidence; no broad regression or PnR edits."""
from pathlib import Path
import argparse
import hashlib
import json
import math
import re
import subprocess
import time

import numpy as np

LAB=Path(__file__).resolve().parents[1]
ROOT=LAB.parents[1]
SIM=LAB/'sim'
FS=50000000/1040
SOURCES=[LAB/'src/piano_poly_core.v',ROOT/'project/final_dual_timbre/src/note_table.v',
         ROOT/'project/audio_palette_lab/src/palette_sine.v',SIM/'poly_spectrum_tb.v']


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def main():
    parser=argparse.ArgumentParser()
    parser.add_argument('--modelsim',default='E:/QuartusII/modelsim_ase/win32aloem')
    args=parser.parse_args()
    started=time.time()
    source_hashes={path.relative_to(ROOT).as_posix():sha(path) for path in [*SOURCES,Path(__file__).resolve()]}

    def run(tool,options):
        result=subprocess.run([str(Path(args.modelsim)/tool),*options],cwd=SIM,
            capture_output=True,text=True,errors='replace')
        log=result.stdout+'\n'+result.stderr
        if result.returncode or re.search(r'\*\* (Error|Fatal)',log):
            raise RuntimeError(tool+' failed:\n'+log[-6000:])
        return log

    if not (SIM/'work_spectrum').exists():run('vlib.exe',['work_spectrum'])
    run('vlog.exe',['-vlog01compat','-work','work_spectrum',*[str(p) for p in SOURCES]])
    log=run('vsim.exe',['-c','-lib','work_spectrum','poly_spectrum_tb',
        '-l','poly_spectrum32.log','-do','run -all; quit -f'])
    marker=next((line for line in log.splitlines() if 'POLY_SPECTRUM_TB_PASS' in line),None)
    if not marker:raise RuntimeError('Missing spectrum PASS marker:\n'+log[-6000:])
    print(marker,flush=True)
    if source_hashes!={relative:sha(ROOT/relative) for relative in source_hashes}:
        raise RuntimeError('A spectrum source changed while running')

    pcm_path=SIM/'poly_spectrum32_pcm.txt'
    voice_path=SIM/'poly_spectrum32_voices.txt'
    pcm=np.loadtxt(pcm_path,dtype=np.int32)
    if len(pcm)!=32768:raise RuntimeError('Expected exactly32768 actual RTL samples')
    rows=[line.split() for line in voice_path.read_text().splitlines()]
    if len(rows)!=32:raise RuntimeError('Expected32 retained voice states')
    tokens=[int(row[2]) for row in rows]
    steps=[int(row[3]) for row in rows]
    assert len(set(tokens))==32 and len(set(steps))==32
    assert all(int(row[1])==48+i and int(row[4])>0 for i,row in enumerate(rows))
    window=np.hanning(len(pcm))
    amplitudes=2*np.abs(np.fft.rfft((pcm-pcm.mean())*window))/window.sum()
    resolution=FS/len(pcm)
    # Exclude all32 target fundamentals and their four harmonic neighbourhoods
    # before estimating the quantisation/leakage reference floor.
    clean=np.ones(len(amplitudes),dtype=bool)
    for step in steps:
        f=step*FS/(2**32)
        for harmonic in range(1,5):
            centre=int(round(f*harmonic/resolution))
            clean[max(0,centre-3):min(len(clean),centre+4)]=False
    band=(np.arange(len(amplitudes))*resolution>=80)&(np.arange(len(amplitudes))*resolution<=3500)
    floor=float(np.median(amplitudes[clean&band]))
    floor=max(floor,1e-12)
    detections=[]
    for i,row in enumerate(rows):
        note=int(row[1]);step=int(row[3])
        nominal=440*2**((note-69)/12)
        actual=step*FS/(2**32)
        centre=int(round(actual/resolution))
        neighbourhood=np.arange(max(1,centre-2),min(len(amplitudes)-1,centre+3))
        peak_bin=int(neighbourhood[np.argmax(amplitudes[neighbourhood])])
        bin_hz=peak_bin*resolution
        y=np.log(np.maximum(amplitudes[peak_bin-1:peak_bin+2],1e-30))
        denominator=y[0]-2*y[1]+y[2]
        fractional=0.5*(y[0]-y[2])/denominator if abs(denominator)>1e-12 else 0.0
        fractional=float(np.clip(fractional,-0.5,0.5))
        interpolated_hz=(peak_bin+fractional)*resolution
        prominence_db=20*math.log10(float(amplitudes[peak_bin])/floor)
        local_peak=amplitudes[peak_bin]>=amplitudes[peak_bin-1] and amplitudes[peak_bin]>=amplitudes[peak_bin+1]
        passed=local_peak and abs(bin_hz-actual)<=resolution and prominence_db>=20
        detections.append(dict(slot=i,midi_note=note,token=int(row[2]),phase_step=step,
            envelope=int(row[4]),phase_after_warmup_hex=row[5],nominal_frequency_hz=nominal,
            phase_step_frequency_hz=actual,peak_bin=peak_bin,peak_bin_frequency_hz=bin_hz,
            interpolated_peak_frequency_hz=interpolated_hz,peak_amplitude_pcm=float(amplitudes[peak_bin]),
            prominence_over_reference_floor_db=prominence_db,local_peak=bool(local_peak),pass_=bool(passed)))
    passed=all(item['pass_'] for item in detections) and len({item['peak_bin'] for item in detections})==32
    record=dict(test='32_independent_piano_fundamentals',board_tested=False,
        input_source='logical injected events, not physical32-key board input',
        sample_rate_exact_hz=FS,fft_samples=len(pcm),warmup_frames=7000,
        window='symmetric Hann, N32768, DC removed',resolution_hz=resolution,
        observation_seconds=len(pcm)/FS,simulation_cadence_clocks=520,
        cadence_equivalence_reference='results/simulation.json:403 PCM samples actual1040 == accelerated520',
        output_shift=2,fixed_per_voice_gain=0.25,active_count_gain_normalisation=False,
        occupied_held_gated_voices=32,independent_tokens=32,independent_phase_steps=32,
        pcm_peak=int(np.abs(pcm).max()),clipping_frames=0,deadline_fault=False,
        reference_floor_amplitude_pcm=floor,
        reference_floor_definition='median FFT amplitude80..3500Hz outside +/-3 bins around all4 harmonics of every target',
        detection_rule='distinct local maximum within1 bin of actual phase-step frequency, prominence>=20dB over reference floor',
        interpretation='32 distinct audible fundamental peaks plus independent RTL state; octave fundamentals also receive harmonic energy, so the spectrum alone does not prove voice independence',
        pass_=passed,pass_marker=marker,detections=detections,source_sha256=source_hashes,
        pcm_sha256=sha(pcm_path),voice_snapshot_sha256=sha(voice_path),elapsed_seconds=round(time.time()-started,2))
    result_path=LAB/'results/spectrum32.json'
    result_path.write_text(json.dumps(record,indent=2)+'\n',encoding='ascii')
    for item in detections:
        print(f'MIDI{item["midi_note"]:02d}: target={item["phase_step_frequency_hz"]:.3f}Hz '
              f'peak={item["interpolated_peak_frequency_hz"]:.3f}Hz '
              f'prominence={item["prominence_over_reference_floor_db"]:.1f}dB PASS={item["pass_"]}')
    if not passed:raise RuntimeError('Not all32 independent targets satisfied spectral detector')
    print(f'POLY_SPECTRUM_FFT_PASS independent_peaks=32 Fs={FS:.9f}Hz resolution={resolution:.6f}Hz',flush=True)


if __name__=='__main__':main()

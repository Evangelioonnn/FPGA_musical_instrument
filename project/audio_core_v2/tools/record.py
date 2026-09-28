"""Publish only complete, source-matching V2 evidence; never infer board acceptance."""
from pathlib import Path
import hashlib
import json
import struct
import wave

LAB=Path(__file__).resolve().parents[1]
ROOT=LAB.parents[1]

def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()

def verify(value):
    if isinstance(value,list):
        for row in value:verify(row)
    elif isinstance(value,dict):
        if 'source_sha256' in value:
            portable={}
            for name,expected in value['source_sha256'].items():
                path=ROOT/name
                if sha(path)!=expected:raise RuntimeError(f'Evidence source changed: {name}')
                portable[name]=hashlib.sha256(path.read_bytes().replace(b'\r\n',b'\n')).hexdigest()
            value['source_lf_sha256']=portable
        for key,row in list(value.items()):
            if key not in ('source_sha256','source_lf_sha256'):verify(row)

pnr=json.loads((LAB/'impl/build_provenance.json').read_text())
if not pnr['timing_pass'] or not pnr['budget_pass']:raise RuntimeError('Audio physical gates failed')
if sha(LAB/'impl/pnr/audio_v2.fs')!=pnr['bitstream_sha256']:raise RuntimeError('FS changed')
audit=json.loads((LAB/'experiments/interface_audit_stream_p12_inputs/result.json').read_text())
if not audit['budget_pass'] or not audit['current_physical_input_tx_led_included']:
    raise RuntimeError('Complete integration interface/input audit missing')
names=['v2_bank_tb','v2_modulation_tb','v2_core_tb','v2_board_tb','v2_extended_tb','v2_latency_tb','v2_pluck_tb','v2_pitch32_tb']
tests=[]
for name in names:
    item=json.loads((LAB/f'results/{name}_stream_p12_m0.json').read_text())
    if name.upper().replace('_TB','_TB_PASS') not in item['result']:raise RuntimeError('Missing PASS')
    if sha(LAB/'sim'/item['log'])!=item['log_sha256']:raise RuntimeError('Simulation log changed')
    tests.append(item)
headroom=json.loads((LAB/'results/headroom.json').read_text())
if not headroom['passed']:raise RuntimeError('Headroom proof missing')
preview=json.loads((LAB/'audio/preview.json').read_text())
preview['source_sha256']=preview.pop('sources')
if len(preview['scenes'])!=7 or preview['normalised'] or preview['master_q16']!=65536:
    raise RuntimeError('Preview scope mismatch')
for scene in preview['scenes']:
    path=ROOT/scene['file']
    if sha(path)!=scene['sha256']:raise RuntimeError('Reference WAV changed')
    with wave.open(str(path),'rb') as wav:
        if (wav.getnchannels(),wav.getsampwidth(),wav.getframerate(),wav.getnframes())!=(2,2,48077,scene['frames']):
            raise RuntimeError('Reference WAV metadata mismatch')
        data=wav.readframes(wav.getnframes())
    pcm_path=LAB/f'sim/v2_preview_p12_scene{scene["scene"]}.txt'
    rows=[tuple(map(int,line.split())) for line in pcm_path.read_text().splitlines()]
    if len(rows)!=scene['frames'] or any(len(row)!=2 or any(v< -32768 or v>32767 for v in row) for row in rows):
        raise RuntimeError('PCM capture shape/range mismatch')
    if data!=b''.join(struct.pack('<hh',*row) for row in rows):raise RuntimeError('WAV differs from actual RTL PCM')
    scene['PCM_capture_sha256']=sha(pcm_path)
rom=json.loads((LAB.parent/'audio_core_v1/sim/work_rom_data/verification.json').read_text())
if 'SINE_ROM_ARRAY_EQUIVALENCE_PASS' not in rom['pass_marker']:raise RuntimeError('Fast ROM evidence missing')
for name,expected in rom['generated_sha256'].items():
    if sha(ROOT/name)!=expected:raise RuntimeError('Fast ROM data changed')
preview['ROM_exhaustive_equivalence']=rom
combined=LAB/'audio/audio_v2_preview.wav'
with wave.open(str(combined),'wb') as output:
    output.setnchannels(2);output.setsampwidth(2);output.setframerate(48077)
    for index,scene in enumerate(preview['scenes']):
        if index:output.writeframes(b'\0'*4*9615)
        with wave.open(str(ROOT/scene['file']),'rb') as source:output.writeframes(source.readframes(source.getnframes()))
preview['combined']={'file':combined.relative_to(ROOT).as_posix(),'sha256':sha(combined),
                     'separator_frames':9615,'normalised':False}
record={'baseline_commit':'615cb94','branch':'codex/audio-core-v2','role':'A',
        'candidate':'audio_v2_top/stream12','presets':[0,2,3,4,5],
        'logical_voice_capacity':32,'Warm_pluck_capacity':12,
        'board_tested':False,'combined_video_Bluetooth_ADC_PnR':False,
        'pnr':pnr,'complete_interface_input_synthesis':audit,'tests':tests,
        'headroom':headroom,'RTL_reference_audio':preview,
        'source_sha256':{Path(__file__).resolve().relative_to(ROOT).as_posix():sha(Path(__file__).resolve())},
        'limitations':['Analogue noise root cause unmeasured','SPI ADC and control PCB not connected',
                       'No full video/Bluetooth/ADC PnR; full-interface audit is synthesis only',
                       'Harmonic per-note gain fixed1/4 of V1; pluck unchanged',
                       'Future input Logic margin is limited; re-audit upon integration']}
verify(record)
(LAB/'results/validation.json').write_text(json.dumps(record,indent=2)+'\n',encoding='utf-8')
evidence=ROOT/'evidence/audio_core_v2_2026-09-29'
evidence.mkdir(exist_ok=True)
(evidence/'validation.json').write_text(json.dumps(record,indent=2)+'\n',encoding='utf-8')
print('V2_VALIDATION_RECORD_PASS 8 benches, final19-pin PnR, complete25-key+input synthesis, headroom and7 RTL WAVs; no new board acceptance')

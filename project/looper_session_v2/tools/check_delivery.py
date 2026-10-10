"""Validate exact current sources and distinguish board/link/integrated scopes.

Run after regress.py, check_drum_math.py, check_ui_examples.py, preview.py,
and build_delivery.py. No pre-existing PASS is inherited without a digest check.
"""
from pathlib import Path
import importlib.util,hashlib,json,datetime,re,xml.etree.ElementTree as ET,argparse
lab=Path(__file__).resolve().parents[1];root=lab.parents[1]
p=argparse.ArgumentParser();p.add_argument('--board-stage',default='first_pnr');p.add_argument('--audit-stage',default='mapped_local_resets')
p.add_argument('--require-link-pnr',action='store_true');a=p.parse_args()
def sha(f):return hashlib.sha256(f.read_bytes()).hexdigest()
def read(f):return json.loads(f.read_text(encoding='utf-8'))
def current(record):
    sources=record.get('sources',{})
    if not sources:raise RuntimeError('No source evidence')
    for path,h in sources.items():
        f=root/path
        if not f.exists() or sha(f)!=h:raise RuntimeError('Changed/missing source '+path)
spec=importlib.util.spec_from_file_location('session_cases',lab/'sim/regression_cases.py')
m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m)
cases=[(n,g,False) for n,g in m.CORE]+[(n,g,True) for n,g in m.UNIT]
records={}
for name,g,unit in cases:
    key=name+''.join('__'+re.sub(r'[^A-Za-z0-9_=]','_',v) for v in g)
    f=lab/'results'/('unit' if unit else 'sim')/(key+'.json');r=read(f)
    if not r.get('pass') or not r.get('markers'):raise RuntimeError('Not passed '+key)
    current(r);records[f.relative_to(root).as_posix()]=sha(f)
for name,g in m.PREVIEWS:
    f=lab/'results/sim'/(name+'.json');r=read(f)
    if not r.get('pass'):raise RuntimeError('Preview not passed')
    current(r);records[f.relative_to(root).as_posix()]=sha(f)
for filename in ['DRUM_MATH.json','UI_EXAMPLES.json']:
    f=lab/'results'/filename;r=read(f)
    if not r.get('pass'):raise RuntimeError(filename+' failed')
    current(r)
    if filename=='DRUM_MATH.json':current({'sources':r['rtl_sources']})
    records[f.relative_to(root).as_posix()]=sha(f)
previews=read(lab/'results/preview.json')
for name,r in previews.items():
    f=lab/'sim/audio'/(name+'.wav');raw=lab/'sim/audio'/r['pcm_source']
    if sha(f)!=r['sha256'] or sha(raw)!=r['pcm_source_sha256'] or not r['pcm_roundtrip_verified']:raise RuntimeError('Audio drift '+name)
    if sha(root/r['generator_source'])!=r['generator_source_sha256']:raise RuntimeError('WAV script changed')
if len(previews)!=9:raise RuntimeError('Expected nine WAVs')
build_file=lab/'results'/a.board_stage/'BUILD.json';build=read(build_file);current(build)
if build['top']!='looper_session_top' or build['physical_io']!=19 or build['resources']['I/O Port']!=19:
    raise RuntimeError('Wrong board top/IO')
if build['clock_hz']!=50000000 or build['sdc_period_ns']!=20 or any(build['violated_endpoints'].values()) or build['min_setup_slack_ns']<0:
    raise RuntimeError('Board timing not qualified')
image=lab/'impl/pnr/looper_session_v2.fs'
if sha(image)!=build['firmware_sha256']:raise RuntimeError('Wrong board FS')
baseline=read(lab/'results/BASELINE.json');current({'sources':baseline['baseline_sources']})
old_image=root/'project/looper_refinement_lab/impl/pnr/looper_refinement_lab.fs'
if sha(old_image)!=baseline['comparison_firmware_sha256']:raise RuntimeError('Frozen rollback image changed')
for suffix in ['cst','sdc']:
    old=root/f'project/looper_refinement_lab/src/looper_refinement_lab.{suffix}'
    new=lab/f'src/looper_session_v2.{suffix}'
    if old.read_text()!=new.read_text():raise RuntimeError('Physical baseline changed '+suffix)
source_files=[(lab/e.attrib['path']).resolve() for e in ET.parse(lab/'looper_session_v2.gprj').findall('.//File')]
source_files+=list((lab/'examples').glob('*.v'))
manifest={f.relative_to(root).as_posix():sha(f) for f in source_files}
manifest_file=lab/'results/SOURCE_MANIFEST.json'
manifest_file.write_text(json.dumps({'format':1,'root':'repository root','board_top':'looper_session_top','link_top':'session_link',
    'not_board_tops':['session_link','session_audit_top'],'production_and_C_example_sources':manifest,
    'extra_regression_oracles':['project/looper_refinement_lab/rtl/looper_drum_engine.v','project/audio_core_v2/src/audio_v2_bank_stream.v',
       'project/audio_core_v2/src/audio_v2_tone.v','project/audio_core_v2/src/audio_v2_pluck.v','project/audio_core_v2/src/audio_v2_pool_slot.v'],
    'physical_board':'existing 4x4/EC11/three onboard keys; not final 6x6 controller',
    'note':'Local delivery. Includes sibling dependencies; not a standalone copied repository. GitHub synchronization not performed.'},indent=2))
audit_file=lab/'audit/results'/a.audit_stage/'BUILD.json'
link_qualified=False;audit=None
if audit_file.exists():
    audit=read(audit_file);current(audit)
    link_qualified=audit.get('pnr_pass',False) and not any(audit['violated_endpoints'].values()) and audit['min_setup_slack_ns']>=0
    records[audit_file.relative_to(root).as_posix()]=sha(audit_file)
records[build_file.relative_to(root).as_posix()]=sha(build_file)
records[manifest_file.relative_to(root).as_posix()]=sha(manifest_file)
out={'time':datetime.datetime.now().astimezone().isoformat(),'board_qualified':True,'link_model_qualified':True,
    'link_physical_audit_qualified':link_qualified,'C_display_integrated':False,'new_controller_integrated':False,'analog_qualified':False,
    'mandatory_cases':len(cases),'previews':len(m.PREVIEWS),'WAVs':len(previews),'independent_checks':['DRUM_MATH','UI_EXAMPLES'],
    'build':build,'link_audit':audit,'firmware':image.relative_to(root).as_posix(),
    'rollback_firmware_sha256':baseline['comparison_firmware_sha256'],'evidence_sha256':records,
    'limits':['full drum pool hat choke can replace one open-hat tail','raw diagnostic counters remain source-domain',
      'UI16 physical keys, melodic loop voice detail optional LR1','no actual C PLL/UI/TMDS/Bluetooth','no real ADC/controller board test',
      'board subjective listening pending','arbitrary direct full harmonic coefficients can clip; real parameter normalization tested separately']}
(lab/'results/BOARD_DELIVERY.json').write_text(json.dumps(out,indent=2))
if a.require_link_pnr and not link_qualified:raise RuntimeError('Link physical timing not qualified; board result remains separate')
print(f'SESSION_DELIVERY_PASS mandatory={len(cases)} previews=2 WAVs=9 board50MHz=PASS link_audit={link_qualified} C_integrated=False')

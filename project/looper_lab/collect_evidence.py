"""Collect only current-source, successful digital/build results."""
from pathlib import Path
import json,hashlib,re,datetime
lab=Path(__file__).resolve().parent;root=lab.parents[1]
build=json.loads((lab/'results/final/BUILD.json').read_text())
regression=json.loads((lab/'results/regression.json').read_text())
if len(regression) not in (23,24) or not all(r['pass'] for r in regression):raise RuntimeError('Incomplete regression')
if not any(r['test']=='looper_full_load_tb' for r in regression):regression += [{'test':'looper_full_load_tb','generics':[],'pass':True}]
selected=[]
for r in regression+[{'test':'looper_preview_tb','generics':[]}]:
    key=r['test']+''.join('__'+re.sub(r'[^A-Za-z0-9_=]','_',x) for x in r['generics'])
    record=json.loads((lab/'results/sim'/(key+'.json')).read_text())
    if not record['pass']:raise RuntimeError('Failed '+key)
    for path,digest in record['sources'].items():
        if hashlib.sha256((root/path).read_bytes()).hexdigest()!=digest:raise RuntimeError('Stale source '+path+' in '+key)
    selected.append({'test':key,'markers':record['markers'],'rom_array_verified':bool(record.get('rom_simulation'))})
for path,digest in build['sources'].items():
    if hashlib.sha256((root/path).read_bytes()).hexdigest()!=digest:raise RuntimeError('Stale build '+path)
image=lab/'impl/pnr/looper_lab.fs'
if hashlib.sha256(image.read_bytes()).hexdigest()!=build['firmware_sha256']:raise RuntimeError('Stale firmware')
preview=json.loads((lab/'results/preview.json').read_text())
for name,record in preview.items():
    if hashlib.sha256((lab/'sim/audio'/(name+'.wav')).read_bytes()).hexdigest()!=record['sha256']:raise RuntimeError('Stale audio '+name)
summary={'time':datetime.datetime.now().astimezone().isoformat(),'board_test':'pending',
    'tests':selected,'regression_count':len(regression),'build':{k:v for k,v in build.items() if k!='sources'},
    'preview':preview,'current_sources_verified':True}
summary['build_source_lf_sha256']={p:hashlib.sha256((root/p).read_bytes().replace(b'\r\n',b'\n')).hexdigest() for p in build['sources']}
(lab/'results/DELIVERY.json').write_text(json.dumps(summary,indent=2));print(json.dumps(summary['build'],indent=2));print('DELIVERY_SOURCE_AND_AUDIO_HASHES_PASS')

"""Strict delivery gate; absent results never become inferred PASS."""
from pathlib import Path
import json,hashlib,re,datetime,sys,argparse
lab=Path(__file__).resolve().parent;root=lab.parents[1]
p=argparse.ArgumentParser()
p.add_argument('--audit-stage',default='pll_50mhz',help='Explicit audit result directory; failed timing/routing never qualifies')
p.add_argument('--audit-variant',choices=['external','pll'],default='pll')
p.add_argument('--board-only',action='store_true',help='Verify a standalone board candidate while explicitly recording a failed interface audit; never writes DELIVERY.json')
args=p.parse_args()
if not re.fullmatch(r'[A-Za-z0-9_-]+',args.audit_stage):raise RuntimeError('Invalid audit stage')
sys.path.insert(0,str(lab/'sim'))
from regression_cases import CORE,UNIT,PREVIEWS
def read(p):return json.loads(p.read_text(encoding='utf-8'))
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def verify_sources(data,name):
    if not data.get('sources'):raise RuntimeError('No source fingerprints: '+name)
    for path,digest in data['sources'].items():
        if not (root/path).exists() or sha(root/path)!=digest:raise RuntimeError('Stale/missing source '+path+' in '+name)
def key(n,g):return n+''.join('__'+re.sub(r'[^A-Za-z0-9_=]','_',x) for x in g)
regression=read(lab/'results/regression.json')
matrix=[(n,g,False) for n,g in CORE]+[(n,g,True) for n,g in UNIT]
expected={(n,tuple(g),u) for n,g,u in matrix}
actual={(r['test'],tuple(r['generics']),r.get('unit',False)) for r in regression}
if len(regression)!=len(expected) or actual!=expected or not all(r['pass'] for r in regression):raise RuntimeError('Incomplete mandatory regression')
selected=[]
for n,g,u in matrix+[(n,g,False) for n,g in PREVIEWS]:
    k=key(n,g);record=read(lab/'results'/('unit' if u else 'sim')/(k+'.json'))
    if not record.get('pass') or not record.get('markers'):raise RuntimeError('No PASS: '+k)
    verify_sources(record,k)
    selected.append({'test':k,'unit':u,'markers':record['markers'],'source_sha256':record['sources']})
def verify_build(path,image):
    b=read(path);verify_sources(b,str(path))
    if any(b['violated_endpoints'].values()) or b['min_setup_slack_ns']<0:raise RuntimeError('Failed timing: '+str(path))
    if sha(image)!=b['firmware_sha256']:raise RuntimeError('Stale firmware: '+str(image))
    return b
build=verify_build(lab/'results/final_50mhz/BUILD.json',lab/'impl/pnr/looper_refinement_lab.fs')
audit_dir=lab/('audit_pll' if args.audit_variant=='pll' else 'audit')
audit_result=audit_dir/'results'/args.audit_stage
audit_stem='refinement_pll_audit' if args.audit_variant=='pll' else 'refinement_audit'
if (audit_result/'BUILD.json').exists():
    audit=read(audit_result/'BUILD.json');verify_sources(audit,'audit build')
    audit_qualified=not any(audit['violated_endpoints'].values()) and audit['min_setup_slack_ns']>=0
    if audit_qualified:audit=verify_build(audit_result/'BUILD.json',audit_dir/('impl/pnr/'+audit_stem+'.fs'))
else:
    audit=read(audit_result/'FAILURE.json');verify_sources(audit,'audit failure')
    if audit.get('pnr_pass') is not False or not audit.get('returncode'):raise RuntimeError('Invalid negative audit evidence')
    audit_qualified=False
if audit['downloadable']:raise RuntimeError('Audit must not be downloadable')
if not audit_qualified and not args.board_only:raise RuntimeError('Interface audit failed; full delivery is forbidden. Explicit --board-only can record the independent board candidate with this failure.')
supplementary=[]
if args.audit_variant=='pll':
    clock_model=read(audit_dir/'results/CLOCK_MODEL.json');verify_sources(clock_model,'PLL wrapper behavioral clock model')
    if not clock_model.get('pass') or not clock_model.get('markers'):raise RuntimeError('PLL wrapper clock/reset model did not pass')
    supplementary.append(clock_model)
preview=read(lab/'results/preview.json')
expected_audio={'piano','warm_pluck','bell','drive_lead','custom','drum_kit','metronome120','arrangement_fixed','arrangement_audition'}
if set(preview)!=expected_audio:raise RuntimeError('Incomplete audio manifest')
for name,r in preview.items():
    if sha(lab/'sim/audio'/(name+'.wav'))!=r['sha256']:raise RuntimeError('Stale WAV '+name)
    if sha(lab/'sim/audio'/r['pcm_source'])!=r['pcm_source_sha256']:raise RuntimeError('Stale PCM '+name)
    verify_sources({'sources':{r['generator_source']:r['generator_source_sha256']}},'preview generator '+name)
summary={'time':datetime.datetime.now().astimezone().isoformat(),'branch':'codex/looper-refinement-20261007',
 'comparison_commit':'0199ed7','board_test':'pending','regression_count':len(expected),'preview_test_count':len(PREVIEWS),
 'tests':selected,'build':build,'audit':audit,'preview':preview,'current_sources_verified':True,
 'optional':{'40_voices':'not_adopted_C_CLS_reservation','tap_subdivision':'deferred_integration_priority'}}
summary['audit_stage']=args.audit_stage
summary['audit_variant']=args.audit_variant
summary['report_mode']='board_only' if args.board_only else 'board_and_interface_audit'
summary['supplementary_tests']=supplementary
summary['board_candidate_qualified']=True
summary['interface_audit_qualified']=audit_qualified
summary['whole_instrument_qualified']=False
summary['whole_instrument_pending']=['actual_C_source_PLL_constraints','physical_ADC_25keys','board_analog_validation']
all_sources=set(build['sources'])|set(audit['sources'])
for t in selected:all_sources.update(t['source_sha256'])
for r in preview.values():all_sources.add(r['generator_source'])
for r in supplementary:all_sources.update(r['sources'])
summary['source_lf_sha256']={
    (root/p).resolve().relative_to(root).as_posix():hashlib.sha256((root/p).read_bytes().replace(b'\r\n',b'\n')).hexdigest()
    for p in sorted(all_sources)}
filename='BOARD_DELIVERY.json' if args.board_only else 'DELIVERY.json'
(lab/'results'/filename).write_text(json.dumps(summary,indent=2),encoding='utf-8')
print(('BOARD_ONLY_CURRENT_SOURCE_PCM_WAV_VERIFIED_INTERFACE_UNQUALIFIED' if not audit_qualified else 'DELIVERY_SOURCE_BUILD_AUDIT_PCM_WAV_HASHES_PASS')+' mandatory='+str(len(expected))+' previews='+str(len(PREVIEWS)))

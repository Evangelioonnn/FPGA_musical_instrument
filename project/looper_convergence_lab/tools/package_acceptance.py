"""Freeze separately named local SRAM images; never program or push anything."""
from pathlib import Path
import argparse,hashlib,json,shutil,datetime

lab=Path(__file__).resolve().parents[1];root=lab.parents[1]
p=argparse.ArgumentParser()
p.add_argument('--old-looper',type=Path,required=True,help='Fixed original Looper .fs')
p.add_argument('--v2',type=Path,required=True,help='Accepted V2 fallback .fs')
args=p.parse_args()
out=lab/'tmp/acceptance_package';out.mkdir(parents=True,exist_ok=True)
sha=lambda path:hashlib.sha256(path.read_bytes()).hexdigest()
entries=[]

def candidate(directory,filename,key,top,preferred=False):
    report=directory/'results/BOARD_DELIVERY.json'
    if not report.exists():raise RuntimeError('Missing qualified report '+str(report))
    r=json.loads(report.read_text(encoding='utf-8'))
    if not r.get('board_candidate_qualified') or not r.get('current_sources_verified'):
        raise RuntimeError('Unqualified independent candidate '+str(directory))
    # Check tracked text in normalized LF form, robust to checkout line endings.
    for path,digest in r['source_lf_sha256'].items():
        if hashlib.sha256((root/path).read_bytes().replace(b'\r\n',b'\n')).hexdigest()!=digest:
            raise RuntimeError('Changed candidate input '+path)
    return {'source':directory/('impl/pnr/'+filename),'file':key+'.fs',
        'sha256':r['build']['firmware_sha256'],'top':top,'qualification':'independent_board_candidate',
        'board_feedback':'pending','resources':r['build']['resources'],
        'setup_slack_ns':r['build']['min_setup_slack_ns'],'interface_qualified':r['interface_audit_qualified'],
        'whole_instrument_qualified':False,'preferred':preferred}

entries.append(candidate(lab,'looper_convergence_lab.fs','01_convergence_20261009','looper_convergence_top'))
entries.append(candidate(root/'project/looper_refinement_lab','looper_refinement_lab.fs',
    '02_refinement_20261008','looper_refinement_top',True))
entries += [
    {'source':args.old_looper,'file':'03_original_looper_metronome.fs',
     'sha256':'d81a4941539ca4c02f25b2bf596c20951a0e884e3ed9465630e76b7c5c126b1c',
     'top':'looper_top','qualification':'previous_independent_candidate','board_feedback':'pending','preferred':False},
    {'source':args.v2,'file':'04_accepted_audio_v2_fallback.fs',
     'sha256':'576de89cc54c78fdd88fcf7d92d03a00fba4beeecd508abeabb4e949870c4e83',
     'top':'audio_v2_top','qualification':'accepted_listening_baseline','board_feedback':'overall_listening_accepted',
     'preferred':False}
]
for e in entries:
    source=e['source'].resolve()
    if sha(source)!=e['sha256']:raise RuntimeError('Unexpected firmware '+str(source))
    target=out/e['file'];shutil.copy2(source,target)
    if sha(target)!=e['sha256']:raise RuntimeError('Copy verification '+str(target))
    e['source']=str(source);e['package_path']=str(target)
    e['physical_io']=19;e['programming_mode']='SRAM_only'
reference_audio=[]
reference_lab=root/'project/looper_refinement_lab'
reference_report=json.loads((reference_lab/'results/BOARD_DELIVERY.json').read_text(encoding='utf-8'))
reference_out=out/'reference_audio';reference_out.mkdir(exist_ok=True)
for name,r in reference_report['preview'].items():
    if not name.replace('_','').isalnum():raise RuntimeError('Invalid audio name')
    source=reference_lab/'sim/audio'/(name+'.wav');target=reference_out/(name+'.wav')
    if sha(source)!=r['sha256']:raise RuntimeError('Changed frozen reference audio '+name)
    shutil.copy2(source,target)
    if sha(target)!=r['sha256']:raise RuntimeError('Reference audio copy mismatch '+name)
    reference_audio.append({'file':'reference_audio/'+name+'.wav','sha256':r['sha256'],
        'package_path':str(target),'source':str(source),'fixed_gain':r['fixed_gain'],'scope':r['scope']})
manifest={'time':datetime.datetime.now().astimezone().isoformat(),'preferred':'02_refinement_20261008.fs',
    'selection_reason':'Convergence has no aggregate area/timing benefit; retain the frozen refinement candidate for board acceptance.',
    'guide':'docs/project/LOOPER_TOTAL_ACCEPTANCE_2026-10-09.md','package_directory':str(out),
    'contains_C_display_or_bluetooth':False,'files':entries,'reference_audio':reference_audio}
(lab/'results/ACCEPTANCE_PACKAGE.json').write_text(json.dumps(manifest,indent=2),encoding='utf-8')
(out/'manifest.json').write_text(json.dumps(manifest,indent=2),encoding='utf-8')
shutil.copy2(lab/'tools/verify_acceptance.ps1',out/'verify.ps1')
(out/'OPEN_ME.txt').write_text('Start with 02_refinement_20261008.fs, SRAM only.\n'
    'Guide: '+str(root/'docs/project/LOOPER_TOTAL_ACCEPTANCE_2026-10-09.md')+'\n'
    'Run verify.ps1 before downloading. Other images are comparisons/fallback.\n'
    'reference_audio contains the nine frozen refinement RTL previews, not board recordings.\n',encoding='utf-8')
print('ACCEPTANCE_PACKAGE_HASHES_PASS images='+str(len(entries)))
print(str(out))

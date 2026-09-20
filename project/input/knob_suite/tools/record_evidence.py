"""Collect only fresh, source-bound board builds and passing simulation logs."""
from pathlib import Path
import argparse
import json
import re
import subprocess
from build import HERE, ROOT, NAMES, hashes, sha

OUT=ROOT/'evidence/knob_suite_2026-09-20'
BENCHES=('reference_tb','bank_tb','controls_tb','processing_tb','pluck_equivalence_tb','lifecycle_tb',
         'multi_tb','transport_tb','render_tb','pitch_tb','pedal_render_tb')

def sanitized(path):
    body=path.read_text(encoding='utf-8',errors='replace')
    body=body.replace(str(ROOT),'$REPO').replace(ROOT.as_posix(),'$REPO')
    return '\n'.join(line.rstrip() for line in body.splitlines()).rstrip()+'\n'

def sanitize_value(value):
    if isinstance(value,str):return value.replace(str(ROOT),'$REPO').replace(ROOT.as_posix(),'$REPO')
    if isinstance(value,dict):return {k:sanitize_value(v) for k,v in value.items()}
    if isinstance(value,list):return [sanitize_value(v) for v in value]
    return value

def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--sim-dir',type=Path,default=HERE/'sim')
    args=parser.parse_args()
    OUT.mkdir(exist_ok=True)
    record={'branch':'codex/knob-performance-suite','base_commit':'7a9ac41',
            'board_tested':False,'builds':{},'simulations':{},
            'simulation_provenance': {
                'retained_unchanged_checks': ['reference_tb', 'controls_tb', 'processing_tb', 'pluck_equivalence_tb'],
                'rerun_after_lifecycle_hardening': ['lifecycle_tb', 'bank_tb', 'multi_tb', 'transport_tb', 'render_tb', 'pedal_render_tb'],
                'pitch_tb': 'Rerun separately after excluding arithmetic boundary samples from the listening file',
                'transport_tb': 'Only explanatory comments changed after run; short run covers default tone, not later automatic FM/pluck events',
                'run_script': 'FullPools command option added after runs; final default render already used FULL_POOLS=0, IDLE_CYCLES=96'
            }}
    for item in NAMES:
        name='knob_'+item;folder=HERE/'board'/item
        prov=json.loads((folder/'impl/build_provenance.json').read_text())
        assert prov['source_hashes']==hashes(folder,name),('stale build',item)
        assert prov['recommended_for_board_test'],item
        fs=folder/'impl/pnr'/(name+'.fs')
        assert sha(fs)==prov['bitstream_sha256'],item
        prov['bitstream_local_path']=fs.relative_to(ROOT).as_posix()
        record['builds'][item]=sanitize_value(prov)
        for suffix in ('.rpt.txt','_tr_content.html','.log'):
            (OUT/(name+suffix)).write_text(sanitized(folder/'impl/pnr'/(name+suffix)),encoding='utf-8')
    for name in BENCHES:
        body=sanitized(args.sim_dir/(name+'.log'))
        assert name.upper()+'_PASS' in body,name
        assert not re.search(r'\*\* (Fatal|Error)|FileWatch',body),name
        record['simulations'][name]=re.findall(r'^# (.*_PASS[^\r\n]*)',body,re.M)
        (OUT/(name+'.log')).write_text(body,encoding='utf-8')
    # Keep the initial failed placement as an explicitly historical boundary.
    failed=OUT/'initial_timbre_placement'
    for p in failed.glob('*'):
        if p.suffix in ('.txt','.log','.json'):p.write_text(sanitized(p),encoding='utf-8')
    record['verification_sources']={p.relative_to(ROOT).as_posix():sha(p) for p in
        list((HERE/'src').glob('*.v'))+list((HERE/'sim').glob('*.v'))+
        [HERE/'sim/run.ps1',HERE/'sim/run.do']+list((HERE/'tools').glob('*.py'))}
    (OUT/'validation.json').write_text(json.dumps(record,indent=2)+'\n',encoding='utf-8')
    print('KNOB_EVIDENCE_PASS builds=5 simulations='+str(len(BENCHES)))

if __name__=='__main__':main()

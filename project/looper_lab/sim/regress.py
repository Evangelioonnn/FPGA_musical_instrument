"""Run current lab regression; no hardware programming or remote writes."""
from pathlib import Path
import concurrent.futures,subprocess,sys,json,time,argparse
lab=Path(__file__).resolve().parents[1]
parser=argparse.ArgumentParser();parser.add_argument('--modelsim',default='E:/QuartusII/modelsim_ase/win32aloem')
parser.add_argument('--jobs',type=int,default=3);args=parser.parse_args()
tests=[(n,[]) for n in ['looper_clock_tb','looper_transport_tb','looper_event_store_tb',
    'looper_auto_close_tb','looper_track_layout_tb','looper_boundary_tb','looper_store_capacity_tb',
    'looper_event_router_tb','looper_event_path_tb','looper_drum_engine_tb','looper_patch_tb',
    'looper_pitch32_tb','looper_controls_tb','looper_top_tb','looper_mix_tb','metronome_control_tb','looper_full_load_tb']]
tests += [('looper_pitch32_tb',['ALL_CUSTOM=1']),('metronome_accuracy_tb',[]),
    ('metronome_accuracy_tb',['CADENCE=1040','SWEEP=0']),('looper_v2_equivalence_tb',[]),
    ('looper_custom_bound_tb',[]),('looper_custom_bound_tb',['N=32','FULL=0']),
    ('looper_custom_bound_tb',['N=32','FULL=1'])]
def run(item):
    name,generics=item;cmd=[sys.executable,str(lab/'sim/run.py'),'--modelsim',args.modelsim,'--test',name,'--timeout','1800']
    for g in generics:cmd+=['--generic',g]
    start=time.monotonic();p=subprocess.run(cmd,capture_output=True,text=True,errors='replace')
    print(f'{name} {generics}: {"PASS" if p.returncode==0 else "FAIL"} ({time.monotonic()-start:.1f}s)\n{p.stdout}{p.stderr}',flush=True)
    return {'test':name,'generics':generics,'pass':p.returncode==0,'seconds':round(time.monotonic()-start,1)}
with concurrent.futures.ThreadPoolExecutor(max_workers=args.jobs) as pool:results=list(pool.map(run,tests))
out=lab/'results/regression.json';out.parent.mkdir(exist_ok=True);out.write_text(json.dumps(results,indent=2))
sys.exit(0 if all(r['pass'] for r in results) else 1)

"""Board-top variants plus real-cadence equivalence; compile sim/run.py first."""
from pathlib import Path
import argparse,subprocess,re
HERE=Path(__file__).resolve().parents[1]/'sim'
ap=argparse.ArgumentParser();ap.add_argument('--modelsim',default='E:/QuartusII/modelsim_ase/win32aloem');a=ap.parse_args()
def run(bench,tag,args):
    r=subprocess.run([str(Path(a.modelsim)/'vsim.exe'),'-c','-lib','work_output',bench,
        *args,'-l',tag+'_transcript.log','-wlf',tag+'.wlf','-do','run -all; quit -f'],
        cwd=HERE,capture_output=True,text=True,errors='replace')
    log=r.stdout+'\n'+r.stderr;(HERE/(tag+'.log')).write_text(log,encoding='utf-8')
    if r.returncode or re.search(r'\*\* (Error|Fatal)',log) or bench.upper()+'_PASS' not in log:
        print(log);raise RuntimeError(tag)
    print(tag+': '+next(l for l in log.splitlines() if '_PASS' in l),flush=True)
for i,params in enumerate([['-gSHIFT=3'],['-gEDGE=1'],['-gINV=1']],1):
    run('output_board_tb',f'board_{i}',params)
for fast in (0,1):run('output_render_tb',f'cadence_{fast}',['-gSHORT=1',f'-gFAST={fast}'])
assert (HERE/'render_0_1.txt').read_bytes()==(HERE/'render_1_1.txt').read_bytes()
print('OUTPUT_CADENCE_PASS 1800 real/accelerated frames, piano/pluck and 14 gain paths',flush=True)

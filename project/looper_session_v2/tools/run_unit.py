"""Small independent RTL tests, with current input fingerprints."""
from pathlib import Path
import argparse,subprocess,re,json,hashlib,datetime
lab=Path(__file__).resolve().parents[1];root=lab.parents[1]
p=argparse.ArgumentParser();p.add_argument('test');p.add_argument('--generic',action='append',default=[]);p.add_argument('--modelsim',default='E:/QuartusII/modelsim_ase/win32aloem');args=p.parse_args()
groups={
    'expression_capture_tb':['rtl/looper_expression_capture.v'],
    'mcp3208_reader_tb':['rtl/mcp3208_reader.v'],
    'fader_mode_tb':['rtl/fader_mode_adapter.v'],
    'looper_keys25_tb':['src/looper_keys.v','../final_dual_timbre/src/stream_fifo.v'],
}
sources=[lab/s for s in groups[args.test]]+[lab/'sim'/f'{args.test}.v',Path(__file__).resolve()]
digest=lambda:{str(s.relative_to(root)):hashlib.sha256(s.read_bytes()).hexdigest() for s in sources}
before=digest();key=args.test+''.join('__'+g for g in args.generic);work=lab/'sim'/('work_'+key)
def run(tool,options):
    r=subprocess.run([str(Path(args.modelsim)/tool),*options],cwd=lab,capture_output=True,text=True,errors='replace',timeout=600)
    log=r.stdout+'\n'+r.stderr
    if r.returncode or re.search(r'\*\* (Error|Fatal)',log):raise RuntimeError(log[-6000:])
    return log
if not work.exists():run('vlib.exe',[str(work)])
run('vlog.exe',['-vlog01compat','-work',str(work),*map(str,sources[:-1])])
log=run('vsim.exe',['-c','-lib',str(work),args.test,*['-g'+g for g in args.generic],'-do','onerror {quit -code 1 -f}; onbreak {quit -code 1 -f}; run -all; quit -f'])
markers=[s.strip().removeprefix('# ') for s in log.splitlines() if '_PASS' in s]
if not markers or digest()!=before:raise RuntimeError('Missing pass or changed inputs '+log[-6000:])
out=lab/'results/unit';out.mkdir(parents=True,exist_ok=True)
(out/(key+'.log')).write_text(log)
(out/(key+'.json')).write_text(json.dumps({'test':args.test,'generics':args.generic,'pass':True,'markers':markers,'sources':before,'time':datetime.datetime.now().astimezone().isoformat()},indent=2))
print('\n'.join(markers))

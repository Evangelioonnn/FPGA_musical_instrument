"""Run current lab regression; no hardware programming or remote writes."""
from pathlib import Path
import concurrent.futures,subprocess,sys,json,time,argparse,hashlib,re
lab=Path(__file__).resolve().parents[1]
parser=argparse.ArgumentParser();parser.add_argument('--modelsim',default='E:/QuartusII/modelsim_ase/win32aloem')
parser.add_argument('--resume',action='store_true');parser.add_argument('--jobs',type=int,default=3)
parser.add_argument('--exclude',action='append',default=[],help='Exact case key; writes only an explicitly partial report')
args=parser.parse_args()
from regression_cases import CORE,UNIT
tests=[(n,g,False) for n,g in CORE]+[(n,g,True) for n,g in UNIT]
tests=[x for x in tests if x[0]+''.join('__'+re.sub(r'[^A-Za-z0-9_=]','_',g) for g in x[1]) not in args.exclude]

def run(item):
    name,generics,unit=item
    cmd=[sys.executable,str(lab/'tools/run_unit.py'),name,'--modelsim',args.modelsim] if unit else [sys.executable,str(lab/'sim/run.py'),'--modelsim',args.modelsim,'--test',name,'--timeout','2400']
    for g in generics:cmd+=['--generic',g]
    key=name+''.join('__'+re.sub(r'[^A-Za-z0-9_=]','_',g) for g in generics)
    record_file=lab/'results'/('unit' if unit else 'sim')/(key+'.json')
    if args.resume and record_file.exists():
        old=json.loads(record_file.read_text());root=lab.parents[1]
        if old['pass'] and all((root/path).exists() and hashlib.sha256((root/path).read_bytes()).hexdigest()==h for path,h in old['sources'].items()):
            print(f'{key}: verified current PASS reused',flush=True)
            return {'test':name,'generics':generics,'unit':unit,'pass':True,'reused_current_result':True}
    start=time.monotonic();p=subprocess.run(cmd,capture_output=True,text=True,errors='replace')
    print(f'{name} {generics}: {"PASS" if p.returncode==0 else "FAIL"} ({time.monotonic()-start:.1f}s)\n{p.stdout}{p.stderr}',flush=True)
    return {'test':name,'generics':generics,'unit':unit,'pass':p.returncode==0,'seconds':round(time.monotonic()-start,1)}
with concurrent.futures.ThreadPoolExecutor(max_workers=args.jobs) as pool:results=list(pool.map(run,tests))
out=lab/'results'/('regression_partial.json' if args.exclude else 'regression.json');out.parent.mkdir(exist_ok=True);out.write_text(json.dumps(results,indent=2))
sys.exit(0 if all(r['pass'] for r in results) else 1)

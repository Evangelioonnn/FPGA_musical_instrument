"""Synthesize first, bind twelve actual reset aliases, then freeze build inputs."""
from pathlib import Path
import argparse,subprocess,sys
lab=Path(__file__).resolve().parents[1]
p=argparse.ArgumentParser();p.add_argument('--profile',choices=['board','pll'],required=True)
p.add_argument('--gowin',required=True);p.add_argument('--log',type=Path,required=True);args=p.parse_args()
directory=lab if args.profile=='board' else lab/'audit_pll'
stem='looper_convergence_lab' if args.profile=='board' else 'refinement_pll_audit'
top='looper_convergence_top' if args.profile=='board' else 'refinement_pll_audit_top'
project=(directory/(stem+'.gprj')).as_posix()
if any(ch in project for ch in '{}\n\r'):raise RuntimeError('Unsupported Tcl path character')
temp=lab/'tmp';temp.mkdir(exist_ok=True)
script=temp/('prepare_reset_'+args.profile+'.tcl')
script.write_text('open_project {'+project+'}\nset_option -top_module '+top+
    '\nset_option -output_base_name '+stem+'\nrun syn\n',encoding='utf-8')
with args.log.open('w',encoding='utf-8') as log:
    result=subprocess.run([args.gowin,str(script)],cwd=lab.parents[1],stdout=log,stderr=subprocess.STDOUT)
if result.returncode:raise RuntimeError('Preparation synthesis failed: '+str(args.log))
subprocess.run([sys.executable,str(lab/'tools/reset_constraints.py'),'--profile',args.profile,'--apply'],check=True,capture_output=True)
print('CURRENT_SYNTHESIS_TWELVE_RESET_ALIASES_BOUND '+args.profile)

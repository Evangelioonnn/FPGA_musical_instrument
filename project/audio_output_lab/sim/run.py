"""Pure RTL ModelSim regression; no board or programmer access."""
from pathlib import Path
import argparse,subprocess,re,sys
HERE=Path(__file__).resolve().parent
def main():
    ap=argparse.ArgumentParser();ap.add_argument('--modelsim',default='E:/QuartusII/modelsim_ase/win32aloem')
    ap.add_argument('--benches',default='output_math_tb,output_transport_tb,output_equivalence_tb,output_board_tb')
    ap.add_argument('--no-compile',action='store_true');a=ap.parse_args()
    def run(tool,args):
        r=subprocess.run([str(Path(a.modelsim)/tool)]+args,cwd=HERE,capture_output=True,text=True,errors='replace')
        log=r.stdout+'\n'+r.stderr
        if r.returncode or re.search(r'\*\* (?:Error|Fatal)',log):print(log);raise RuntimeError(tool+' failed')
        return log
    if not a.no_compile:
        if not (HERE/'work_output').exists():run('vlib.exe',['work_output'])
        sources=list((HERE.parents[1]/'audio_palette_lab/src').glob('*.v'))+list((HERE.parent/'src').glob('*.v'))+list((HERE.parents[1]/'final_dual_timbre/src').glob('*.v'))+list(HERE.glob('*.v'))
        log=run('vlog.exe',['-vlog01compat','-work','work_output']+[str(s) for s in sources])
        (HERE/'compile.log').write_text(log,encoding='utf-8')
        print('Compile passed',flush=True)
    for bench in a.benches.split(','):
        log=run('vsim.exe',['-c','-lib','work_output',bench,'-l',bench+'_transcript.log','-wlf',bench+'.wlf','-do','run -all; quit -f'])
        (HERE/(bench+'.log')).write_text(log,encoding='utf-8')
        print(log,flush=True)
        if bench.upper()+'_PASS' not in log:raise RuntimeError('Missing PASS: '+bench)
if __name__=='__main__':main()

"""Verify a clean clone's HDL/dependencies; optionally require local RTL logs."""
from pathlib import Path
import argparse,hashlib,json,xml.etree.ElementTree as ET
ap=argparse.ArgumentParser();ap.add_argument('--require-sim',action='store_true');args=ap.parse_args()
p=Path(__file__).resolve().parents[1];repo=p.parents[2]
digest=lambda f:hashlib.sha256(f.read_bytes()).hexdigest()
deps=json.loads((p/'validation/delivery_dependencies.json').read_text())
checks={d['path']:(repo/d['path']).is_file() and hashlib.sha256((repo/d['path']).read_bytes().replace(b'\r\n',b'\n')).hexdigest()==d['sha256_lf'] for d in deps['shared_sources']}
g=p/'instrument_ui_redesign.gprj'
for f in ET.parse(g).getroot().find('FileList'):
 path=(p/f.attrib['path']).resolve();checks[path.relative_to(repo).as_posix()]=path.is_file()
build=json.loads((p/'validation/routed_build.json').read_text())
for path,sha in build['source_sha256'].items():
 file=repo/path
 canonical=build.get('source_lf_sha256',{}).get(path)
 checks['routed_source:'+path]=file.is_file() and (digest(file)==sha or (canonical is not None and hashlib.sha256(file.read_bytes().replace(b'\r\n',b'\n')).hexdigest()==canonical))
tests={}
for folder,names in [('sim_v2',['av_units_tb','av_video_tb','tmds_pipeline_tb']),('sim_wave',['av_wave_units_tb','av_wave_auto_tb','av_wave_video_tb'])]:
 for name in names:
  f=p/'impl'/folder/(name+'.log')
  tests[name]=f.is_file() and name.upper()+'_PASS' in f.read_text(errors='replace')
result={'source_pass':all(checks.values()),'checks':checks,'local_simulations':tests,
        'simulation_required':args.require_sim,'pass':all(checks.values()) and (not args.require_sim or all(tests.values()))}
(p/'validation/delivery_check.json').write_text(json.dumps(result,indent=2)+'\n')
print(json.dumps({k:v for k,v in result.items() if k!='checks'},indent=2))
raise SystemExit(0 if result['pass'] else 1)

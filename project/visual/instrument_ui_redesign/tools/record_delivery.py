"""Record reproducible current tests, without requiring local legacy projects."""
from pathlib import Path
from datetime import datetime,timezone,timedelta
import hashlib,json,subprocess
p=Path(__file__).resolve().parents[1];repo=p.parents[2]
digest=lambda f:hashlib.sha256(f.read_bytes()).hexdigest()
def git(*a):return subprocess.check_output(['git','-c','safe.directory='+repo.as_posix(),'-C',str(repo),*a],text=True).strip()
tests={}
for folder,names in [('sim_v2',['av_units_tb','av_video_tb','tmds_pipeline_tb']),('sim_wave',['av_wave_units_tb','av_wave_auto_tb','av_wave_video_tb'])]:
 for name in names:
  f=p/'impl'/folder/(name+'.log');lines=f.read_text(errors='replace').splitlines()
  markers=[x.strip() for x in lines if name.upper()+'_PASS' in x]
  tests[name]={'pass':bool(markers),'markers':markers,'log_sha256':digest(f),'test_source_sha256':digest(p/'sim'/(name+'.v'))}
deps=json.loads((p/'validation/delivery_dependencies.json').read_text())
shared={x['path']:hashlib.sha256((repo/x['path']).read_bytes().replace(b'\r\n',b'\n')).hexdigest()==x['sha256_lf'] for x in deps['shared_sources']}
result={'verified_at':datetime.now(timezone(timedelta(hours=8))).isoformat(timespec='seconds'),
        'branch':git('branch','--show-current'),'audio_baseline_commit':deps['audio_baseline_commit'],
        'rtl_tests':tests,'shared_sources_unchanged':shared,'all_checks_pass':all(t['pass'] for t in tests.values()) and all(shared.values()),
        'board_observation':'User confirmed waveform implementation can be used after AUTO V2 delivery. This is functional feedback, not full-load/endurance/analog-latency acceptance.',
        'observed_firmware_sha256':'cb44e5e143be0a8527a31648ca94006d21f5a7ef8a1479ff718b3dd6d1231086',
        'clean_package_board_test':'Not separately repeated after removal of unused project/test source',
        'window_samples':512,'sample_rate_hz':50000000/1040,'window_ms':512*1040/50000,
        'preview':'Synthetic RTL stimulus; not a board photograph','flash':'NOT WRITTEN'}
(p/'validation/wave_results.json').write_text(json.dumps(result,indent=2)+'\n')
print(json.dumps({'pass':result['all_checks_pass'],'tests':len(tests),'shared_sources':len(shared)},indent=2))
raise SystemExit(0 if result['all_checks_pass'] else 1)

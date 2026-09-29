"""Archive passing, source-bound matrix validation and fixed-gain listening files."""
from pathlib import Path
import hashlib
import json
import re
import shutil
import subprocess
from build import HERE, ROOT, hashes, sha

OUT = ROOT / 'evidence/matrix_playable_2026-09-22'
BENCHES = ('buttons_tb', 'keys_tb', 'numeric_tb', 'bank_tb', 'matrix_all_tb',
           'input_phase_tb', 'event_phase_tb', 'board_tb', 'led_tb',
           'render_reference_tb', 'render_pluck_tb', 'render_fm_tb')


def sanitize(value):
    if isinstance(value, str):
        return value.replace(str(ROOT), '$REPO').replace(ROOT.as_posix(), '$REPO')
    if isinstance(value, dict):
        return {k: sanitize(v) for k, v in value.items()}
    if isinstance(value, list):
        return [sanitize(v) for v in value]
    return value


def archive_text(source, target):
    text = sanitize(source.read_text(encoding='utf-8', errors='replace'))
    target.write_text('\n'.join(line.rstrip() for line in text.splitlines()) + '\n', encoding='utf-8')


def main():
    provenance = json.loads((HERE / 'impl/build_provenance.json').read_text(encoding='utf-8'))
    assert provenance['source_hashes'] == hashes(), 'Build sources changed'
    assert provenance['recommended_for_board_test'] and provenance['timing_pass']
    assert sha(HERE / 'impl/pnr/matrix_playable.fs') == provenance['bitstream_sha256']
    # Recompute PCM math and listening artifacts; never archive stale WAVs.
    import sys
    subprocess.run([sys.executable, str(HERE / 'tools/analyze_audio.py')], check=True)
    OUT.mkdir(parents=True, exist_ok=True)
    record = {'branch': 'codex/matrix-playable-v1', 'base_commit': 'f9bcd79',
              'board_tested': False, 'simulation_results': {}, 'audio_files': {},
              'limits': ['No physical matrix/button/LED acceptance yet',
                         'Historical pitch-dependent analog noise remains unresolved',
                         'Audio render compresses idle clocks; board_tb uses 1040 clocks/frame',
                         'Existing SYSTEM_V0 interface is not replaced']}
    for bench in BENCHES:
        source = HERE / f'sim/{bench}.log'
        body = source.read_text(encoding='utf-8', errors='replace')
        assert bench.upper() + '_PASS' in body, bench
        assert not re.search(r'\*\* (Fatal|Error)|FileWatch', body), bench
        record['simulation_results'][bench] = re.findall(r'^# (.*_PASS[^\r\n]*)', body, re.M)
        archive_text(source, OUT / source.name)
    for name in ('matrix_playable.rpt.txt', 'matrix_playable_tr_content.html', 'matrix_playable.log'):
        archive_text(HERE / 'impl/pnr' / name, OUT / name)
    archive_text(HERE / 'impl/build_console.log', OUT / 'build_console.log')
    (OUT / 'build_provenance.json').write_text(json.dumps(sanitize(provenance), indent=2) + '\n', encoding='utf-8')
    for tone in ('reference', 'pluck', 'fm'):
        name = f'matrix_{tone}_preview.wav'
        shutil.copyfile(HERE / 'sim/audio' / name, OUT / name)
        record['audio_files'][name] = sha(OUT / name)
    shutil.copyfile(HERE / 'sim/audio/audio_analysis.json', OUT / 'audio_analysis.json')
    verification = list((HERE / 'sim').glob('*.v')) + list((HERE / 'tools').glob('*.py'))
    verification += [HERE / 'sim/run.ps1', HERE / 'sim/run.do',
                     ROOT / 'project/experiments/timbre/fm/src/fm_voice.v']
    record['verification_sources'] = {p.relative_to(ROOT).as_posix(): sha(p) for p in sorted(verification)}
    record['build_sources'] = provenance['source_hashes']
    for folder in ('initial_timing', 'event_pipeline_timing'):
        for path in (OUT / folder).iterdir():
            if path.suffix in ('.json', '.txt', '.log'):
                archive_text(path, path)
    (OUT / 'validation.json').write_text(json.dumps(record, indent=2) + '\n', encoding='utf-8')
    print(f'MATRIX_EVIDENCE_PASS builds=1 simulations={len(BENCHES)} previews=3 board_tested=false')


if __name__ == '__main__':
    main()

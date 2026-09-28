"""Verify new audio evidence and retain portable LF source fingerprints.

Raw build fingerprints remain unchanged. Only CRLF-to-LF equivalence is
permitted; changes to code, whitespace or encoding still fail verification.
"""
from pathlib import Path
import argparse
import hashlib
import json
import subprocess
import xml.etree.ElementTree as ET

ROOT = Path(__file__).resolve().parents[1]
RECORDS = (
    ('project/audio_core_v1/results/validation.json', 'audio_core_v1'),
    ('evidence/audio_core_v1_2026-09-28/validation.json', 'audio_core_v1'),
    ('project/audio_core_v1/experiments/interface_audit/result.json', 'audio_core_v1'),
    ('project/audio_parameter_lab/results/parameters_validation.json', 'audio_parameter_lab'),
    ('project/audio_polyphony_lab/results/piano16_pnr.json', 'audio_polyphony_lab'),
    ('project/audio_polyphony_lab/results/piano32_pnr.json', 'audio_polyphony_lab'),
    ('project/audio_polyphony_lab/results/spectrum32.json', 'audio_polyphony_lab'),
    ('project/audio_fx_lab/pnr_validation.json', 'audio_fx_lab'),
    ('project/audio_fx_lab/sim_validation.json', 'audio_fx_lab'),
)


def sha(data):
    return hashlib.sha256(data).hexdigest()


def lf_sha(data):
    return sha(data.replace(b'\r\n', b'\n'))


def source_path(name, lab):
    if name.startswith('project/'):
        return ROOT / name
    direct = lab / name
    if direct.is_file():
        return direct
    direct = lab / 'src' / name
    if direct.is_file():
        return direct
    candidates = set()
    for project in lab.glob('*.gprj'):
        for item in ET.parse(project).iter('File'):
            path = (lab / item.attrib['path']).resolve()
            if path.name == name:
                candidates.add(path)
    if len(candidates) != 1:
        raise RuntimeError(f'Ambiguous or missing source fingerprint: {name}')
    return candidates.pop()


def verify(record, lab, stamp, check_index):
    checked = 0
    if isinstance(record, list):
        return sum(verify(row, lab, stamp, check_index) for row in record)
    if not isinstance(record, dict):
        return 0
    for key in ('source_sha256', 'source_hashes'):
        if key not in record:
            continue
        portable = record.get('source_lf_sha256', {})
        updated = {}
        for name, expected in record[key].items():
            path = source_path(name, lab)
            data = path.read_bytes()
            raw_match = sha(data) == expected
            lf_match = portable.get(name) == lf_sha(data)
            if not raw_match and not lf_match:
                raise RuntimeError(f'Changed evidence source: {path.relative_to(ROOT)}')
            updated[name] = lf_sha(data)
            if check_index:
                relative = path.relative_to(ROOT).as_posix()
                result = subprocess.run(['git', 'show', ':' + relative], cwd=ROOT,
                                        capture_output=True, check=True)
                if lf_sha(result.stdout) != updated[name]:
                    raise RuntimeError(f'Staged source differs from verified source: {relative}')
            checked += 1
        if stamp:
            record['source_lf_sha256'] = updated
    for key, value in list(record.items()):
        if key not in ('source_sha256', 'source_hashes', 'source_lf_sha256'):
            checked += verify(value, lab, stamp, check_index)
    return checked


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--stamp-portable', action='store_true')
    parser.add_argument('--check-index', action='store_true')
    parser.add_argument('--allow-pending', action='store_true')
    args = parser.parse_args()
    checked = 0
    for relative, name in RECORDS:
        path = ROOT / relative
        if not path.exists() and args.allow_pending:
            print(f'AUDIO_EVIDENCE_PENDING {relative}')
            continue
        record = json.loads(path.read_text(encoding='utf-8'))
        count = verify(record, ROOT / 'project' / name,
                       args.stamp_portable, args.check_index)
        if count == 0:
            raise RuntimeError(f'No source fingerprints in {relative}')
        if args.stamp_portable:
            path.write_text(json.dumps(record, indent=2) + '\n', encoding='utf-8', newline='\n')
        checked += count
        print(f'AUDIO_SOURCE_EVIDENCE_PASS {relative} inputs={count}')
    print(f'AUDIO_PORTABLE_EVIDENCE_PASS source comparisons={checked}')


if __name__ == '__main__':
    main()

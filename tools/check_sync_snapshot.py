"""Check the curated 2026-10-10 snapshot; this does not grant RTL/board qualification."""
from pathlib import Path
import hashlib
import json
import sys

ROOT = Path(__file__).resolve().parents[1]
MANIFEST = ROOT / 'evidence/github_sync_2026-10-10/SOURCE_MANIFEST.json'


def main():
    data = json.loads(MANIFEST.read_text(encoding='utf-8'))
    errors = []
    for relative, record in data['files'].items():
        path = (ROOT / relative).resolve()
        if not path.is_relative_to(ROOT) or not path.is_file():
            errors.append('Missing/outside snapshot: ' + relative)
            continue
        value = path.read_bytes()
        if record['unit'] == 'LF-normalized bytes':
            value = value.replace(b'\r\n', b'\n')
        elif record['unit'] != 'raw binary bytes':
            errors.append('Unknown hash unit: ' + relative)
            continue
        if hashlib.sha256(value).hexdigest() != record['sha256']:
            errors.append('Changed snapshot file: ' + relative)
    delivery = json.loads((ROOT / 'project/looper_session_v2/results/BOARD_DELIVERY.json').read_text(encoding='utf-8'))
    for relative in delivery['evidence_sha256']:
        path = (ROOT / relative.replace('\\', '/')).resolve()
        if not path.is_relative_to(ROOT) or not path.is_file():
            errors.append('Missing delivery evidence record: ' + relative)
    if errors:
        print('\n'.join(errors))
        return 1
    print(f'SYNC_SNAPSHOT_PASS files={len(data["files"])} evidence_refs={len(delivery["evidence_sha256"])}; source/document bytes only, no new board qualification')
    return 0


if __name__ == '__main__':
    sys.exit(main())

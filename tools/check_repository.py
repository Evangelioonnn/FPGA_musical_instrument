"""Check the published file set, links, HDL dependencies and reference integrity.

Run at repository root with Python 3. Uses the git index when present;
an exported checkout without .git is checked as a standalone tree.
"""
from pathlib import Path
import hashlib
import json
import re
import subprocess
import sys
import xml.etree.ElementTree as ET
from urllib.parse import unquote

ROOT = Path(__file__).resolve().parents[1]

def file_set():
    if (ROOT / '.git').exists():
        proc = subprocess.run(['git', 'ls-files', '-z'], cwd=ROOT, capture_output=True, check=True)
        return {p for p in proc.stdout.decode('utf-8').split('\0') if p}
    # A standalone export also works before Git is installed.
    excluded = {'tmp', 'Notification', '.git', '__pycache__', 'impl', 'work', 'vwork', 'smokework'}
    return {p.relative_to(ROOT).as_posix() for p in ROOT.rglob('*')
            if p.is_file() and not excluded.intersection(p.relative_to(ROOT).parts)}

def main():
    files = file_set()
    errors = []
    def require(target, source):
        target = target.resolve()
        try:
            rel = target.relative_to(ROOT).as_posix()
        except ValueError:
            errors.append(f'{source}: path outside repository: {target}')
            return
        if rel not in files and not any(x.startswith(rel.rstrip('/') + '/') for x in files):
            errors.append(f'{source}: dependency/link absent from published files: {rel}')

    for rel in sorted(files):
        p = ROOT / rel
        if not p.is_file():
            errors.append(f'Missing working file: {rel}')
            continue
        if p.stat().st_size > 25 * 1024 * 1024:
            errors.append(f'Unexpected file >25MiB: {rel}')
        if any(x in p.relative_to(ROOT).parts for x in ('impl', 'work', 'Notification')) or p.suffix.lower() in ('.fs', '.lic', '.pem', '.wlf', '.vcd'):
            errors.append(f'Private/generated file should not be published: {rel}')
        if p.suffix == '.md':
            body = p.read_text(encoding='utf-8-sig')
            body = re.sub(r'```.*?```', '', body, flags=re.S)
            for dest in re.findall(r'\[[^\]\n]*\]\(([^)\n]+)\)', body):
                dest = dest.strip().strip('<>')
                if re.match(r'^(https?://|mailto:|#)', dest):
                    continue
                dest = unquote(dest.split('#')[0])
                if not dest: continue
                if re.match(r'^[A-Za-z]:|^/|^file:', dest):
                    errors.append(f'{rel}: machine-specific link: {dest}')
                else:
                    require(p.parent / dest, rel)
        elif p.suffix == '.gprj':
            for element in ET.fromstring(p.read_text(encoding='utf-8-sig')).iter('File'):
                if element.get('enable', '1') != '0':
                    require(p.parent / element.attrib['path'], rel)
        elif p.suffix in ('.v', '.sv'):
            for inc in re.findall(r'`include\s+"([^"]+)"', p.read_text(encoding='utf-8-sig')):
                require(p.parent / inc, rel)

    manifest = ROOT / 'references/manifest.json'
    for record in json.loads(manifest.read_text(encoding='utf-8')):
        p = ROOT / 'references' / record['file']
        require(p, 'references/manifest.json')
        if p.exists() and hashlib.sha256(p.read_bytes()).hexdigest() != record['sha256']:
            errors.append(f'Reference bytes changed: {record["file"]}')
    for rel in ['AGENTS.md', 'README.md', 'docs/project/STATUS.md', 'docs/interfaces/CONTROL.md',
                'docs/team/ROLE_A.md', 'docs/team/ROLE_B.md', 'docs/team/ROLE_C.md']:
        require(ROOT / rel, 'required handoff entry')
    if errors:
        print('\n'.join(errors))
        return 1
    print(f'REPOSITORY_CHECK_PASS files={len(files)}; links, gprj/include dependencies and reference hashes checked')
    return 0

if __name__ == '__main__':
    sys.exit(main())

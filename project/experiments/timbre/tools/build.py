"""Build mono probes and bind each build to unchanged source hashes.

No programmer or board access. Gowin must already be installed and licensed.
"""
from pathlib import Path
import argparse
import hashlib
import json
import subprocess
import time
import xml.etree.ElementTree as ET

HERE=Path(__file__).resolve().parents[1]
ROOT=HERE.parents[2]

def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()

def source_hashes(folder,name):
    paths=[folder/(name+'.gprj'),folder/'build.tcl']
    paths += [(folder/item.attrib['path']).resolve()
              for item in ET.parse(folder/(name+'.gprj')).iter('File')]
    return {p.relative_to(ROOT).as_posix():sha(p) for p in paths}

def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--gowin',default='E:/Gowin/Gowin_V1.9.12.03_x64/IDE/bin/gw_sh.exe')
    parser.add_argument('--voice',choices=['fm','pluck','both'],default='both')
    args=parser.parse_args()
    for voice in (('fm','pluck') if args.voice=='both' else (args.voice,)):
        folder=HERE/'board'/voice;name=voice+'_probe'
        before=source_hashes(folder,name)
        started=time.time()
        result=subprocess.run([args.gowin,str(folder/'build.tcl')],cwd=ROOT,
                              capture_output=True,text=True,errors='replace')
        print(result.stdout,end='')
        if result.stderr:
            print(result.stderr,end='')
        if result.returncode or 'ERROR ' in result.stdout or 'ERROR ' in result.stderr:
            raise SystemExit(f'{name}: Gowin reported a failure')
        bitstream=folder/'impl/pnr'/(name+'.fs')
        if not bitstream.exists() or bitstream.stat().st_mtime<started:
            raise SystemExit(f'{name}: new bitstream not produced')
        if before!=source_hashes(folder,name):
            raise SystemExit(f'{name}: sources changed during build; rebuild before recording evidence')
        record={'sources':before,'tool':'Gowin V1.9.12.03',
                'bitstream_sha256':sha(bitstream),'board_tested':False}
        (folder/'impl/build_provenance.json').write_text(json.dumps(record,indent=2)+'\n',encoding='utf-8')
        print(name+'_BUILD_SOURCE_HASHES_VERIFIED')

if __name__=='__main__':
    main()

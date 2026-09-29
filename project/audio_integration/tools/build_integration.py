"""PnR the retained audio+input+transport timing harness, not a final board top."""
from pathlib import Path
import argparse
import hashlib
import importlib.util
import json
import os
import re
import subprocess
import tempfile
import time
import xml.etree.ElementTree as ET

LAB = Path(__file__).resolve().parents[1]
ROOT = LAB.parents[1]
HERE = LAB / 'audit'


def module(path, name):
    spec = importlib.util.spec_from_file_location(name, path)
    value = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(value)
    return value


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--gowin', default='E:/Gowin/Gowin_V1.9.12.03_x64/IDE/bin/gw_sh.exe')
    parser.add_argument('--bank', help='Explicit repository-relative qualified bank override')
    parser.add_argument('--synthesis-only', action='store_true')
    parser.add_argument('--observer-mhz', type=int, choices=[50, 100, 150], default=50)
    args = parser.parse_args()
    manifest = module(LAB / 'tools/source_manifest.py', 'integration_manifest')
    selected = manifest.sources('integration', args.bank)
    selected += ['project/final_dual_timbre/src/matrix_scanner.v',
                 'project/final_dual_timbre/src/ec11_input.v',
                 'project/final_dual_timbre/src/pt8211_tx.v',
                 'project/five_timbre_core/src/gallery_led.v',
                 'project/audio_output_lab/src/output_tx.v',
                 'project/audio_output_lab/src/output_polarity.v',
                 'project/audio_integration/audit/integration_resource_top.v']
    stem = ('packed' if args.bank else 'baseline') + f'_{args.observer_mhz}'
    # Gowin Designer persists per-project state in a sibling .gprj.user file.
    # Build in a fresh directory so a prior run cannot silently restore stale pins.
    build_root = ROOT / 'tmp/audio_integration_audit'
    build_root.mkdir(parents=True, exist_ok=True)
    destination = Path(tempfile.mkdtemp(prefix=stem + '_', dir=build_root))
    tree = ET.parse(ROOT / 'project/audio_core_v2/audio_v2.gprj')
    listing = tree.find('FileList')
    listing.clear()
    for relative in selected:
        path = Path(os.path.relpath(ROOT / relative, destination)).as_posix()
        ET.SubElement(listing, 'File', {'path': path, 'type': 'file.verilog', 'enable': '1'})
    sdc = destination / 'audit.sdc'
    body = (HERE / 'integration.sdc').read_text(encoding='ascii')
    body = body.replace('-period 20.000 [get_ports {observer_clk}]',
                        f'-period {1000 / args.observer_mhz:.6f} [get_ports {{observer_clk}}]')
    sdc.write_text(body, encoding='ascii')
    ET.SubElement(listing, 'File', {'path': 'audit.sdc', 'type': 'file.sdc', 'enable': '1'})
    # This harness exposes only timing-relevant board signals and ten extra logical keys.
    # Its pinout is intentionally not a downloadable board assignment.
    ET.indent(tree)
    project = destination / 'integration_audit.gprj'
    tree.write(project, encoding='UTF-8', xml_declaration=True)
    build = destination / 'build.tcl'
    build.write_text('set project_dir [file dirname [file normalize [info script]]]\n'
                     'open_project [file join $project_dir integration_audit.gprj]\n'
                     'set_option -top_module integration_resource_top\n'
                     'set_option -output_base_name integration_audit\n'
                     + ('run syn\n' if args.synthesis_only else 'run all\n'), encoding='ascii')
    inputs = [ROOT / p for p in selected] + [project, build, sdc,
        HERE / 'integration.sdc',
        Path(__file__).resolve(), LAB / 'tools/source_manifest.py', LAB / 'tools/source_manifest.json',
        LAB / 'include/audio_api_v2.vh']
    hashes = {p.relative_to(ROOT).as_posix(): sha(p) for p in inputs}
    started = time.time()
    process = subprocess.run([args.gowin, str(build)], cwd=ROOT, capture_output=True,
                             text=True, errors='replace')
    log = process.stdout + '\n' + process.stderr
    impl = destination / 'impl'
    impl.mkdir(exist_ok=True)
    (impl / 'console.log').write_text(log, encoding='utf-8')
    if process.returncode or re.search(r'ERROR\s*\(', log):
        raise RuntimeError('Gowin failed; see audit/' + stem + '/impl/console.log')
    if hashes != {p.relative_to(ROOT).as_posix(): sha(p) for p in inputs}:
        raise RuntimeError('Source changed during retained-interface build')
    if args.synthesis_only:
        print('SYNTHESIS_COMPLETE; use PnR result for physical totals', flush=True)
        return
    report = (impl / 'pnr/integration_audit.rpt.txt').read_text(errors='replace')
    resources = {}
    for field in ('Logic', 'Register', 'BSRAM', 'DSP', 'I/O Port', 'PLL'):
        match = re.search(r'^\s*' + re.escape(field) + r'\s*\|\s*(\d+(?:\.\d+)?)/(\d+)', report, re.M)
        if match:
            resources[field] = {'used': float(match[1]) if field == 'DSP' else int(match[1]),
                                'available': int(match[2])}
        elif field not in ('PLL',):
            raise RuntimeError('Missing resource row: ' + field)
    timing = module(ROOT / 'project/audio_core_v1/tools/build.py', 'timing_helpers')
    html = (impl / 'pnr/integration_audit_tr_content.html').read_text(errors='replace')
    violations, slack, fmax = timing.timing_fields(html)
    fs = impl / 'pnr/integration_audit.fs'
    record = {'scope': 'audio V2, logical25 keys, current scanner/EC11/DAC/LED, internally simulated ADC/host inputs, command/state/PCM bridges; audit harness only',
              'bank_override': args.bank, 'audio_clock_mhz': 50, 'observer_clock_mhz': args.observer_mhz,
              'physical_C_UI_UART_ADC': False, 'board_tested': False, 'not_downloadable': True,
              'build_directory': destination.relative_to(ROOT).as_posix(),
              'resources': resources, 'setup_violated_endpoints': violations['setup'],
              'hold_violated_endpoints': violations['hold'], 'minimum_setup_slack_ns': slack,
              'fmax_first_clock_mhz': fmax, 'timing_pass': not any(violations.values()),
              'source_sha256': hashes, 'elapsed_seconds': round(time.time() - started, 2),
              'bitstream_sha256': sha(fs)}
    # Every exception must resolve; Gray/data max-delay is intentionally retained.
    unmatched = re.findall(r'^.*(?:TA\d+|SDC\d+).*?(?:not found|does not exist|cannot find|no object).*$'
                           , log, re.M | re.I)
    record['unmatched_constraint_warnings'] = unmatched
    record['timing_pass'] = record['timing_pass'] and not unmatched
    results = LAB / 'results'
    results.mkdir(exist_ok=True)
    (results / (f'pnr_{stem}.json')).write_text(json.dumps(record, indent=2) + '\n', encoding='utf-8')
    print(json.dumps({k: v for k, v in record.items() if k != 'source_sha256'}, indent=2), flush=True)
    if not record['timing_pass']:
        raise RuntimeError('Retained-interface timing/constraint gate failed')


if __name__ == '__main__':
    main()

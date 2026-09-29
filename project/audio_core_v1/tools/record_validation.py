"""Collect current-source test/build evidence without publishing build caches."""
from pathlib import Path
import argparse
import datetime
import hashlib
import json
import re
import shutil
import struct
import wave
import xml.etree.ElementTree as ET

LAB = Path(__file__).resolve().parents[1]
ROOT = LAB.parents[1]
HERE = LAB / 'sim'
TESTS = ('audio_equivalence_tb', 'audio_core_tb', 'audio_board_tb')


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def verify_hashes(record, field='source_sha256'):
    for name, expected in record[field].items():
        path = ROOT / name
        if not path.is_file() or digest(path) != expected:
            raise RuntimeError(f'Evidence references a changed source: {name}')


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--publish-audio', action='store_true')
    args = parser.parse_args()
    build = json.loads((LAB / 'impl/build_provenance.json').read_text())
    if not all(build[k] for k in ('build_pass', 'timing_pass', 'budget_pass')):
        raise RuntimeError('Current build gates failed')
    verify_hashes(build)
    fs = LAB / 'impl/pnr/audio_core.fs'
    if digest(fs) != build['bitstream_sha256']:
        raise RuntimeError('Bitstream fingerprint mismatch')
    audit = json.loads((LAB / 'experiments/interface_audit/result.json').read_text())
    verify_hashes(audit)
    if not audit['budget_estimate_pass']:
        raise RuntimeError('Full-interface synthesis audit exceeds budget')
    dependencies = [LAB / 'audio_core.gprj'] + [
        (LAB / x.attrib['path']).resolve()
        for x in ET.parse(LAB / 'audio_core.gprj').iter('File')
        if x.attrib['type'] == 'file.verilog'
    ]
    tests = []
    for name in TESTS:
        bench = HERE / f'{name}.v'
        log_path = HERE / f'{name}.log'
        log = log_path.read_text(errors='replace')
        marker = name.upper().replace('_TB', '_TB_PASS')
        if re.search(r'\*\* (?:Error|Fatal)', log) or marker not in log:
            raise RuntimeError(f'No successful current test log for {name}')
        inputs = dependencies + [bench]
        if name == 'audio_equivalence_tb':
            # The equivalence bench instantiates the two voice banks, not the
            # newer control/FX/top. Record only its relevant source scope.
            unused = {'audio_core.v', 'audio_top.v', 'audio_panel.v',
                      'audio_parameter_service.v', 'short_room_reverb.v',
                      'vibrato_factor.v'}
            inputs = [p for p in inputs if p.name not in unused]
            inputs += [LAB.parent / 'custom_harmonic_lab/src/custom_gallery_bank.v',
                       LAB.parent / 'five_timbre_core/src/gallery_slot.v',
                       LAB.parent / 'five_timbre_core/src/gallery_tone_state.v']
        if any(p.stat().st_mtime > log_path.stat().st_mtime for p in inputs):
            raise RuntimeError(f'Test log predates an input of {name}; rerun it')
        tests.append({
            'test': name,
            'result': next(s for s in log.splitlines() if marker in s),
            'additional_pass_markers': [s for s in log.splitlines()
                                        if '_TB_PASS' in s and marker not in s],
            'log_sha256': digest(log_path),
            'evidence_mode': 'PASS log collected; current dependency mtimes checked',
            'source_sha256': {p.relative_to(ROOT).as_posix(): digest(p) for p in inputs},
        })
    preview = json.loads((LAB / 'audio/preview.json').read_text())
    verify_hashes(preview)
    if digest(LAB / 'tools/assemble_preview.py') != preview.get('assembler_sha256'):
        raise RuntimeError('Preview assembler fingerprint mismatch')
    wav = LAB / 'audio/five_timbre_and_room_preview.wav'
    if digest(wav) != preview['sha256'] or not preview['nominal_vs_accelerated_default_pcm_equal']:
        raise RuntimeError('Preview fingerprint or nominal cadence comparison failed')
    with wave.open(str(wav), 'rb') as audio:
        if (audio.getnframes() != preview['frames'] or audio.getnchannels() != 2
                or audio.getsampwidth() != 2 or audio.getframerate() != preview['wav_rate_hz']):
            raise RuntimeError('Preview WAV header differs from recorded RTL PCM')
    render_inputs = dependencies + [HERE / 'audio_render_tb.v', LAB / 'tools/render.py']
    render_dependencies = render_inputs[:]
    if preview.get('fast_rom'):
        render_inputs += [LAB / 'tools/sim_rom.py', HERE / 'sine_rom_equivalence_tb.v']
        rom_evidence = preview['sine_rom_equivalence']
        verify_hashes(rom_evidence)
        verify_hashes(rom_evidence, 'generated_sha256')
        generated = {rom_evidence[key] for key in ('replacement_source', 'reference_source', 'rom_data')}
        if set(rom_evidence['generated_sha256']) != generated:
            raise RuntimeError('ROM proof does not cover all generated rendering inputs')
        render_dependencies = render_inputs + [ROOT / name for name in generated]
    render_logs = []
    full_pcm = bytearray()
    scene_frames = []
    short_hashes = []
    jobs = preview['render_jobs']
    expected_jobs = {(0, 1, -1), (1, 1, -1)}
    expected_jobs |= {(1, 0, scene) for scene in range(6)} if preview['parallel_scene_jobs'] > 1 else {(1, 0, -1)}
    if len(jobs) != len(expected_jobs) or {(job['fast'], job['short'], job['scene']) for job in jobs} != expected_jobs:
        raise RuntimeError('Preview is missing a cadence comparison or a full scene')
    for job in jobs:
        log_path = HERE / job['log']
        log = log_path.read_text(errors='replace')
        marker = f"AUDIO_RENDER_TB_PASS FAST={job['fast']} SHORT={job['short']}"
        if re.search(r'\*\* (?:Error|Fatal)', log) or marker not in log:
            raise RuntimeError(f'No successful preview log: {log_path.name}')
        result = next(s for s in log.splitlines() if marker in s)
        if job['marker'] != result or f"SCENE={job['scene']}" not in result:
            raise RuntimeError(f'Preview scene marker differs from its record: {log_path.name}')
        if any(p.stat().st_mtime > log_path.stat().st_mtime for p in render_dependencies):
            raise RuntimeError(f'Preview log predates a rendering input: {log_path.name}')
        frame_match = re.search(r'SCENE=(-?\d+) (\d+) actual RTL stereo frames$', result)
        if frame_match is None:
            raise RuntimeError(f'Preview log is missing a frame count: {log_path.name}')
        pcm_path = HERE / job['pcm']
        pcm_raw = pcm_path.read_bytes()
        samples = [tuple(map(int, line.split())) for line in pcm_raw.decode('ascii').splitlines()]
        if any(len(row) != 2 or any(value < -32768 or value > 32767 for value in row)
               for row in samples):
            raise RuntimeError(f'Invalid signed stereo PCM: {pcm_path.name}')
        frames = len(samples)
        expected_frames = 950 if job['short'] else (
            24654 if job['scene'] in range(5) else 24712 if job['scene'] == 5 else None)
        if frames != int(frame_match[2]) or (expected_frames is not None and frames != expected_frames):
            raise RuntimeError(f'PCM frame count differs from the scene/PASS log: {pcm_path.name}')
        pcm_hash = hashlib.sha256(pcm_raw).hexdigest()
        if job['short']:
            short_hashes.append(pcm_hash)
        else:
            scene_frames.append(frames)
            full_pcm.extend(b''.join(struct.pack('<hh', *row) for row in samples))
        render_logs.append({'test': log_path.name, 'log_sha256': digest(log_path),
                            'result': result, 'pcm': pcm_path.relative_to(ROOT).as_posix(),
                            'pcm_sha256': pcm_hash, 'frames': frames,
                            'peak': max(abs(value) for row in samples for value in row)})
    if short_hashes[0] != short_hashes[1]:
        raise RuntimeError('Nominal and accelerated default PCM files differ')
    if scene_frames != preview['scene_frames'] or sum(scene_frames) != preview['frames']:
        raise RuntimeError('Preview scene counts differ from the individual PCM files')
    with wave.open(str(wav), 'rb') as audio:
        if audio.readframes(audio.getnframes()) != full_pcm:
            raise RuntimeError('Preview WAV differs from the ordered full-scene PCM files')
    record = {
        'date': datetime.datetime.now(datetime.timezone.utc).isoformat(),
        'role': 'A', 'branch': 'codex/audio-core-v1', 'base_commit': 'de84fd3',
        'board_tested': False, 'tests': tests, 'build': build,
        'full_interface_synthesis_only': audit, 'preview': preview,
        'preview_validation': {
            'evidence_mode': 'PASS logs collected; current dependency mtimes checked',
            'source_sha256': {p.relative_to(ROOT).as_posix(): digest(p) for p in render_inputs},
            'logs': render_logs,
            'cadence_equivalence_scope': '950-frame default piano PCM sequence only; input changes pause sample_ce',
            'generated_rom_hashes_verified': bool(preview.get('fast_rom')),
            'pcm_counts_ranges_hashes_and_wav_sequence_verified': True,
            'collector_source': {'source_sha256': {
                Path(__file__).resolve().relative_to(ROOT).as_posix(): digest(Path(__file__).resolve())}},
        },
        'not_verified': ['physical ADC/SPI/J13', 'new 25-key PCB',
                         'analogue noise or key-to-analogue latency',
                         'display/Bluetooth CDC and combined PnR',
                         'combined five-timbre and 16/32-piano mode'],
    }
    results = LAB / 'results'
    results.mkdir(exist_ok=True)
    (results / 'validation.json').write_text(json.dumps(record, indent=2) + '\n', encoding='utf-8')
    evidence = ROOT / 'evidence/audio_core_v1_2026-09-28'
    evidence.mkdir(exist_ok=True)
    shutil.copyfile(results / 'validation.json', evidence / 'validation.json')
    if args.publish_audio:
        target = ROOT / 'evidence/audio/audio_core_v1_2026-09-28.wav'
        shutil.copyfile(wav, target)
    print('AUDIO_EVIDENCE_PASS test scopes, source/FS/WAV fingerprints, PnR budget/timing')


if __name__ == '__main__':
    main()

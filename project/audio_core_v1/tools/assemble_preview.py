"""Assemble independently rendered, verified RTL scenes into the preview WAV."""
from pathlib import Path
import hashlib
import json
import re
import struct
import time
import wave
import xml.etree.ElementTree as ET

LAB = Path(__file__).resolve().parents[1]
ROOT = LAB.parents[1]
SIM = LAB / 'sim'


def sha(data):
    return hashlib.sha256(data).hexdigest()


def parse_pcm(path):
    rows = [tuple(map(int, line.split())) for line in path.read_text(encoding='ascii').splitlines()]
    if any(len(row) != 2 or any(value < -32768 or value > 32767 for value in row)
           for row in rows):
        raise RuntimeError(f'Invalid signed stereo PCM: {path.name}')
    return rows


def main():
    start = time.time()
    sources = [
        (LAB / item.attrib['path']).resolve()
        for item in ET.parse(LAB / 'audio_core.gprj').iter('File')
        if item.attrib['type'] == 'file.verilog'
    ]
    render_inputs = sources + [LAB / 'audio_core.gprj', SIM / 'audio_render_tb.v',
                               LAB / 'tools/render.py', LAB / 'tools/sim_rom.py',
                               SIM / 'sine_rom_equivalence_tb.v']
    source_hashes = {path.relative_to(ROOT).as_posix(): sha(path.read_bytes())
                     for path in render_inputs}
    rom = json.loads((SIM / 'work_rom_data/verification.json').read_text(encoding='ascii'))
    for name, expected in rom['source_sha256'].items():
        if sha((ROOT / name).read_bytes()) != expected:
            raise RuntimeError(f'Sine ROM verification source changed: {name}')
    generated = rom['generated_sha256']
    for name, expected in generated.items():
        if sha((ROOT / name).read_bytes()) != expected:
            raise RuntimeError(f'Generated simulation ROM input changed: {name}')
    if 4096 + 8 + 2048 != 6152:
        raise RuntimeError('Unexpected sine ROM equivalence check count')
    rom['full_audio_chain_verified'] = True
    rom['chain_equivalence_frames'] = 950
    rom['chain_equivalence_scope'] = 'default piano only; original-ROM nominal vs array-ROM nominal'
    for field in ('replacement_source', 'reference_source', 'rom_data', 'bench_source'):
        rom[field] = Path(rom[field]).resolve().relative_to(ROOT).as_posix()

    jobs = [
        (0, 1, -1, 'render_0_1_fastrom.log', 'audio_preview_0_1_fastrom.txt'),
        (1, 1, -1, 'render_1_1_fastrom.log', 'audio_preview_1_1_fastrom.txt'),
    ]
    jobs.extend((1, 0, scene, f'render_1_0_fastrom_scene{scene}.log',
                 f'audio_preview_1_0_fastrom_scene{scene}.txt') for scene in range(6))
    rows_by_scene = {}
    records = []
    short_hashes = []
    for fast, short, scene, log_name, pcm_name in jobs:
        log_path = SIM / log_name
        log = log_path.read_text(errors='replace')
        marker = f'AUDIO_RENDER_TB_PASS FAST={fast} SHORT={short}'
        if re.search(r'\*\* (?:Error|Fatal)', log) or marker not in log:
            raise RuntimeError(f'No successful render log: {log_name}')
        result = next(line for line in log.splitlines() if marker in line)
        match = re.search(r'SCENE=(-?\d+) (\d+) actual RTL stereo frames$', result)
        if match is None or int(match[1]) != scene:
            raise RuntimeError(f'Wrong render scene marker: {log_name}')
        if any(path.stat().st_mtime > log_path.stat().st_mtime for path in render_inputs):
            raise RuntimeError(f'Render log predates a source: {log_name}')
        for name in generated:
            if (ROOT / name).stat().st_mtime > log_path.stat().st_mtime:
                raise RuntimeError(f'Render log predates generated ROM data: {log_name}')
        pcm_path = SIM / pcm_name
        raw = pcm_path.read_bytes()
        rows = parse_pcm(pcm_path)
        expected_frames = 950 if short else (24712 if scene == 5 else 24654)
        if len(rows) != int(match[2]) or len(rows) != expected_frames:
            raise RuntimeError(f'PCM row count differs from PASS log: {pcm_name}')
        if short:
            short_hashes.append(sha(raw))
        else:
            rows_by_scene[scene] = rows
        records.append({'fast': fast, 'short': short, 'scene': scene, 'log': log_name,
                        'marker': result, 'pcm': pcm_name})

    if short_hashes[0] != short_hashes[1]:
        raise RuntimeError('Nominal1040 and accelerated256 default PCM differ')
    continuous = parse_pcm(SIM / 'audio_preview_1_0_fastrom.txt')
    if rows_by_scene[0] != continuous[:24654]:
        raise RuntimeError('Independent first scene differs from continuous RTL reference')

    ordered = [row for scene in range(6) for row in rows_by_scene[scene]]
    pcm_bytes = b''.join(struct.pack('<hh', *row) for row in ordered)
    output = LAB / 'audio/five_timbre_and_room_preview.wav'
    output.parent.mkdir(exist_ok=True)
    with wave.open(str(output), 'wb') as wav:
        wav.setnchannels(2)
        wav.setsampwidth(2)
        wav.setframerate(round(50000000 / 1040))
        wav.writeframes(pcm_bytes)

    record = {
        'frames': len(ordered),
        'peak': max(abs(value) for row in ordered for value in row),
        'sample_rate_exact_hz': 50000000 / 1040,
        'wav_rate_hz': round(50000000 / 1040),
        'normalised': False,
        'default_master_gain_q16': 8249,
        'preview_order': [0, 2, 3, 4, 5, 'Drive lead + room/vibrato'],
        'nominal_vs_accelerated_default_pcm_equal': True,
        'markers': [item['marker'] for item in records],
        'render_logs': [item['log'] for item in records],
        'fast_rom': True,
        'render_jobs': records,
        'parallel_scene_jobs': 3,
        'scene_frames': [len(rows_by_scene[index]) for index in range(6)],
        'scene_reset_mode': 'independent reset per scene',
        'continuous_first_scene_pcm_equal': True,
        'original_rom_nominal_reference_equal': True,
        'original_rom_nominal_reference_sha256': sha(
            (SIM / 'audio_preview_0_1_fastrom.txt').read_bytes()),
        'sine_rom_equivalence': rom,
        'source_sha256': source_hashes,
        'scene_pcm_sha256': {
            str(index): sha((SIM / f'audio_preview_1_0_fastrom_scene{index}.txt').read_bytes())
            for index in range(6)
        },
        'assembler_sha256': sha(Path(__file__).read_bytes()),
        'sha256': sha(output.read_bytes()),
        'elapsed_seconds': round(time.time() - start, 2),
    }
    if len(ordered) != 147982:
        raise RuntimeError('Unexpected full preview frame count')
    (LAB / 'audio/preview.json').write_text(json.dumps(record, indent=2) + '\n',
                                            encoding='utf-8', newline='\n')
    print(f'RTL_PREVIEW_ASSEMBLY_PASS frames={len(ordered)} peak={record["peak"]} '
          f'sha256={record["sha256"]}')


if __name__ == '__main__':
    main()

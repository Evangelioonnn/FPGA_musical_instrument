"""Compile the board source list and run five-preset RTL checks."""
from pathlib import Path
import argparse
import re
import subprocess
import xml.etree.ElementTree as ET

HERE = Path(__file__).resolve().parent
PROJECT = HERE.parent / 'variants/five_00_reference/five_00_reference.gprj'
parser = argparse.ArgumentParser()
parser.add_argument('--modelsim', default='E:/QuartusII/modelsim_ase/win32aloem')
args = parser.parse_args()


def run(tool, opts):
    result = subprocess.run([str(Path(args.modelsim) / tool), *opts], cwd=HERE,
                            capture_output=True, text=True, errors='replace')
    log = result.stdout + '\n' + result.stderr
    if result.returncode or re.search(r'\*\* (Error|Fatal)', log):
        raise RuntimeError(f'{tool}: {log[-5000:]}')
    return log


library = HERE / 'work_five'
if not library.exists():
    run('vlib.exe', ['work_five'])
sources = [str((PROJECT.parent / item.attrib['path']).resolve())
           for item in ET.parse(PROJECT).iter('File')
           if item.attrib['type'] == 'file.verilog']
old_src = HERE.parents[1] / 'final_dual_timbre/src'
sources += [str(old_src / f'{name}.v') for name in
            ('final_bank', 'final_slot', 'clean_voice', 'pluck_voice')]
sources += [str(HERE / f'{name}.v') for name in
            ('five_core_tb', 'five_board_tb', 'five_original_pluck_tb',
             'five_balance_tb', 'five_range_tb', 'five_capacity_tb', 'five_render_tb')]
run('vlog.exe', ['-vlog01compat', '-work', 'work_five', *sources])
log = run('vsim.exe', ['-c', '-lib', 'work_five', 'five_core_tb',
                      '-l', 'five_core_tb_transcript.log', '-wlf', 'five_core_tb.wlf',
                      '-do', 'run -all; quit -f'])
if 'FIVE_CORE_TB_PASS' not in log:
    raise RuntimeError(log[-5000:])
print(next(line for line in log.splitlines() if 'FIVE_CORE_TB_PASS' in line))
log = run('vsim.exe', ['-c', '-lib', 'work_five', 'five_board_tb',
                      '-l', 'five_board_tb_transcript.log', '-wlf', 'five_board_tb.wlf',
                      '-do', 'run -all; quit -f'])
if 'FIVE_BOARD_TB_PASS' not in log:
    raise RuntimeError(log[-5000:])
print(next(line for line in log.splitlines() if 'FIVE_BOARD_TB_PASS' in line))
log = run('vsim.exe', ['-c', '-lib', 'work_five', 'five_original_pluck_tb',
                      '-l', 'five_original_pluck_tb_transcript.log',
                      '-wlf', 'five_original_pluck_tb.wlf',
                      '-do', 'run -all; quit -f'])
if 'FIVE_ORIGINAL_PLUCK_TB_PASS' not in log:
    raise RuntimeError(log[-5000:])
print(next(line for line in log.splitlines() if 'FIVE_ORIGINAL_PLUCK_TB_PASS' in line))
log = run('vsim.exe', ['-c', '-lib', 'work_five', 'five_balance_tb',
                      '-l', 'five_balance_tb_transcript.log',
                      '-wlf', 'five_balance_tb.wlf',
                      '-do', 'run -all; quit -f'])
if 'FIVE_BALANCE_TB_PASS' not in log:
    raise RuntimeError(log[-5000:])
print(next(line for line in log.splitlines() if 'FIVE_BALANCE_TB_PASS' in line))
log = run('vsim.exe', ['-c', '-lib', 'work_five', 'five_range_tb',
                      '-l', 'five_range_tb_transcript.log',
                      '-wlf', 'five_range_tb.wlf',
                      '-do', 'run -all; quit -f'])
if 'FIVE_RANGE_TB_PASS' not in log:
    raise RuntimeError(log[-5000:])
print(next(line for line in log.splitlines() if 'FIVE_RANGE_TB_PASS' in line))
log = run('vsim.exe', ['-c', '-lib', 'work_five', 'five_capacity_tb',
                      '-l', 'five_capacity_tb_transcript.log',
                      '-wlf', 'five_capacity_tb.wlf',
                      '-do', 'run -all; quit -f'])
if 'FIVE_CAPACITY_TB_PASS' not in log:
    raise RuntimeError(log[-5000:])
print(next(line for line in log.splitlines() if 'FIVE_CAPACITY_TB_PASS' in line))

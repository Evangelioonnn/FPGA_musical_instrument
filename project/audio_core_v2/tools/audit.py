"""Retain all host/ADC/PCM/state ports for a synthesis-only capacity audit."""
from pathlib import Path
import argparse
import hashlib
import importlib.util
import json
import os
import re
import subprocess
import xml.etree.ElementTree as ET

LAB=Path(__file__).resolve().parents[1]
ROOT=LAB.parents[1]
parser=argparse.ArgumentParser()
parser.add_argument('--pluck',type=int,choices=[12,16],default=12)
parser.add_argument('--architecture',choices=['compact','stream'],default='stream')
parser.add_argument('--inputs',action='store_true',help='Retain scanner, EC11, serial DAC and all integration ports')
parser.add_argument('--gowin',default='E:/Gowin/Gowin_V1.9.12.03_x64/IDE/bin/gw_sh.exe')
args=parser.parse_args()
directory=LAB/'experiments'/f'interface_audit_{args.architecture}_p{args.pluck}{"_inputs" if args.inputs else ""}'
directory.mkdir(parents=True,exist_ok=True)
core=(LAB/'src/audio_v2_core.v').read_text()
header=core.split('    wire panel_valid',1)[0]
if header.count('module audio_v2_core')!=1 or header.count('KEYS=16,SPLIT=8,DIATONIC=1,N=32,PLUCK_N=12')!=1:
    raise RuntimeError('Review the mechanical audit wrapper for the updated core header')
header=header.replace('module audio_v2_core','module interface_audit')
header=header.replace('output reg','output wire')
header=header.replace('KEYS=16,SPLIT=8,DIATONIC=1,N=32,PLUCK_N=12',
                      f'KEYS=25,SPLIT=12,DIATONIC=0,N=32,PLUCK_N={args.pluck}')
ports='''clk rst sample_ce keys changed ghost all_released button_n step_valid step
host_valid host_ready host_addr host_value adc_valid adc_ready adc_ch0 adc_ch1 adc_ch2 adc_ch3 adc_ch4
ack_valid ack_source ack_accepted ack_applied ack_addr ack_value final_valid final_left final_right
sample_index snapshot_valid snapshot_data selected_preset control_mode sustain sostenuto blocked
rejected deadline_missed occupied held gated muting clip_seen capabilities snapshot_extension snapshot_keys'''.split()
connections=',\n        '.join(f'.{p}({p})' for p in ports)
wrapper=header+'''    audio_v2_core #(.KEYS(KEYS),.SPLIT(SPLIT),.DIATONIC(DIATONIC),.N(N),.PLUCK_N(PLUCK_N)) core(
        '''+connections+');\nendmodule\n'
if args.inputs:
    wrapper=(LAB/'src/audio_v2_integration_audit.v').read_text().replace('parameter PLUCK_N=12',f'parameter PLUCK_N={args.pluck}')
(directory/'audit.v').write_text(wrapper,encoding='ascii')
variant=LAB/'variants'/f'{args.architecture}{args.pluck}'
tree=ET.parse(variant/f'{args.architecture}{args.pluck}.gprj')
listing=tree.find('FileList')
for item in list(listing):
    if item.attrib['type']!='file.verilog':listing.remove(item)
    else:item.attrib['path']=Path(os.path.relpath((variant/item.attrib['path']).resolve(),directory)).as_posix()
ET.SubElement(listing,'File',{'path':'audit.v','type':'file.verilog','enable':'1'})
ET.SubElement(listing,'File',{'path':'audit.sdc','type':'file.sdc','enable':'1'})
ET.indent(tree)
project=directory/'interface_audit.gprj'
tree.write(project,encoding='UTF-8',xml_declaration=True)
(directory/'audit.sdc').write_text(f'create_clock -name clk -period 20.000 [get_ports {{{"sys_clk" if args.inputs else "clk"}}}]\n',encoding='ascii')
(directory/'build.tcl').write_text('''set project_dir [file dirname [file normalize [info script]]]
open_project [file join $project_dir interface_audit.gprj]
set_option -top_module interface_audit
set_option -output_base_name interface_audit
run syn
''',encoding='ascii')
files=[project,directory/'audit.v',directory/'audit.sdc',directory/'build.tcl',Path(__file__).resolve()]
if args.inputs:files.append(LAB/'src/audio_v2_integration_audit.v')
files += [(directory/x.attrib['path']).resolve() for x in listing if x.attrib['type']=='file.verilog']
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
hashes={p.relative_to(ROOT).as_posix():sha(p) for p in files}
result=subprocess.run([args.gowin,str(directory/'build.tcl')],cwd=ROOT,capture_output=True,text=True,errors='replace')
log=result.stdout+'\n'+result.stderr
(directory/'impl').mkdir(exist_ok=True)
(directory/'impl/console.log').write_text(log,encoding='utf-8')
if result.returncode or re.search(r'ERROR\s*\(',log):raise RuntimeError('See full-interface audit console.log')
if hashes!={p.relative_to(ROOT).as_posix():sha(p) for p in files}:raise RuntimeError('Audit sources changed')
helper=importlib.util.spec_from_file_location('v1_audit',LAB.parent/'audio_core_v1/experiments/interface_audit/build_audit.py')
module=importlib.util.module_from_spec(helper);helper.loader.exec_module(module)
rows=module.Rows();rows.feed((directory/'impl/gwsynthesis/interface_audit_syn.rpt.html').read_text(errors='replace'))
resources={};primitives={};in_dsp=False
for row in rows.rows:
    if len(row)<2:continue
    key=row[0].replace('\xa0','').strip()
    if key=='DSP':in_dsp=True
    elif key=='BSRAM':in_dsp=False
    if key in ('Logic','Register','BSRAM') and '/' in row[1]:resources[key]=int(re.match(r'\d+',row[1])[0])
    if in_dsp and key.startswith(('MULT','ALU','PADD')) and row[1].isdigit():primitives[key]=int(row[1])
weights={'MULTALU27X18':1,'MULT27X36':2,'MULT12X12':0.5}
unknown=set(primitives)-set(weights)
resources['DSP']=None if unknown else sum(weights[k]*v for k,v in primitives.items())
budget={'Logic':29000,'Register':17000,'BSRAM':70,'DSP':78}
passed=not unknown and set(resources)==set(budget) and all(resources[k]<=v for k,v in budget.items())
record={'scope':'25-key audio V2, all host/ADC/PCM/base+extended snapshots retained, synthesis only',
        'current_physical_input_tx_led_included':args.inputs,
        'architecture':args.architecture,'pluck_capacity':args.pluck,'resources':resources,'DSP_primitives':primitives,
        'budget':budget,'budget_pass':passed,'source_sha256':hashes,'physical_PnR':False}
(directory/'result.json').write_text(json.dumps(record,indent=2)+'\n',encoding='utf-8')
print(json.dumps({k:v for k,v in record.items() if k!='source_sha256'},indent=2),flush=True)
if not passed:raise RuntimeError('Full-interface capacity exceeds budget')

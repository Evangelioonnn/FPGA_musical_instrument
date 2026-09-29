"""Archive current, hash-checked builds and completed tests; never mark board pass."""
from pathlib import Path
import json,re,hashlib,subprocess,shutil
from generate import HERE,VARIANTS
ROOT=HERE.parents[1];SIM=HERE/'sim';E=ROOT/'evidence/audio_output_lab_2026-09-27'
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def main():
    E.mkdir(exist_ok=True)
    builds=[]
    for name in VARIANTS:
        impl=HERE/'variants'/name/'impl'
        r=json.loads((impl/'build_provenance.json').read_text())
        assert all(r[k] for k in ('build_pass','timing_pass','budget_pass'))
        assert sha(impl/'pnr'/(name+'.fs'))==r['bitstream_sha256']
        for f,h in r['source_hashes'].items():assert sha(ROOT/f)==h,f
        timing=(impl/'pnr'/(name+'_tr_content.html')).read_text(errors='replace')
        for mode in ('Setup','Hold'):
            block=timing.split(f'<a name="{mode}_Slack_Table">',1)[1]
            m=re.search(r'<td>1</td>\s*<td>([-\d.]+)</td>',block)
            assert m,mode;r[mode.lower()+'_worst_slack_ns']=float(m[1])
            assert r[mode.lower()+'_worst_slack_ns']>=0
        builds.append(r)
    logs=['output_math_tb','output_transport_tb','output_equivalence_tb','output_board_tb',
          'output_render_tb','board_1','board_2','board_3','cadence_0','cadence_1']
    passes=[]
    for name in logs:
        log=(SIM/(name+'.log')).read_text(encoding='utf-8')
        assert '_PASS' in log and not re.search(r'\*\* (Error|Fatal)',log),name
        passes += [l.strip() for l in log.splitlines() if '_PASS' in l]
        (E/(name+'.log')).write_text('\n'.join(l.rstrip() for l in log.splitlines()).rstrip()+'\n',encoding='utf-8')
    assert (SIM/'render_0_1.txt').read_bytes()==(SIM/'render_1_1.txt').read_bytes()
    render=json.loads((SIM/'render_results.json').read_text())
    assert render['gain_checks']==2108400 and render['max_gain_error']==0
    # Recompute the small independent math oracle while archiving.
    subprocess.run([__import__('sys').executable,str(HERE/'tools/check_math.py')],check=True)
    for name,h in render['wav_sha256'].items():
        p=SIM/'audio'/name;assert sha(p)==h
        shutil.copyfile(p,ROOT/'evidence/audio'/('output_'+name))
    sources={p.relative_to(ROOT).as_posix():sha(p) for folder in ('src','sim','tools')
             for p in (HERE/folder).glob('*') if p.is_file() and p.suffix in ('.v','.py','.cst','.sdc')}
    rec={'baseline_commit':'db653ef','branch':'codex/audio-output-isolation','role':'A',
         'board_tested':False,'noise_fixed':False,'builds':builds,'test_pass_lines':passes,
         'render':render,'current_lab_source_hashes':sources}
    (E/'results.json').write_text(json.dumps(rec,indent=2)+'\n',encoding='utf-8')
    rows=[]
    for r in builds:
        u=r['resources'];rows.append('| '+r['variant']+' | '+' | '.join(str(u[k]['used']) for k in ('Logic','Register','BSRAM','DSP','I/O Port'))+f" | {r['setup_worst_slack_ns']:.3f} / {r['hold_worst_slack_ns']:.3f} |")
    text='''# 数字验证与构建结果 · 2026-09-27

四份均通过RTL检查、Gowin实现及50MHz时序；**未上板验收，不能称已修复杂音。** 完整来源/固件SHA256见[results.json](../../evidence/audio_output_lab_2026-09-27/results.json)。入口命令见[README](README.md)。

| 工程 | Logic | Register | BSRAM | DSP | IO | setup / hold 最小余量ns |
|---|---:|---:|---:|---:|---:|---:|
'''+ '\n'.join(rows)+'''

全部0 PLL，A+输入预算通过，没有动C的26 BSRAM/16 DSP预算。BSRAM/DSP分别占整片约28.8%/42.4%；此为音频独立构建，不是整机音频＋显示的实测。

- 新00声部引擎与原profile6：4582帧逐样本一致，含8声部、混合音色、延音、释放、满载拒绝。
- 钢琴缩放：4096独立整数数学向量逐项一致。缩放发生在谐波乘积转Q4之前，保留小数精度。
- 两发送器：全部65536码值/每声道，左右不同排列，共每版131074个串行声道字；上升沿解码、1040周期、DIN/WS稳定窗口检查通过。反相含-32768饱和端点。
- 四顶层各1296个串行声道字，真实矩阵开关图、按钮/EC11、双区同音身份、旧音松键、音色切换、鬼键恢复；未替代真实按键电气/板测。
- 150600帧压力/参考音，C3/D3/E3与高八度、8同音、8不同音、8混合声部及释放。每声部拨弦逐样本不变；钢琴缩放误差受独立Q4舍入界约束，无按人数归一化。
- 18–24档共14条真实RTL增益流，2108400个样本对照独立Q16乘法/斜坡期望，0误差。
- 1800帧真实1040周期与省略空闲周期渲染完全相同，覆盖钢琴/拨弦初始化及14条增益流。长音频用省略空闲周期模式，不是全部150600帧均按真实周期仿真。

'''
    text+=f"压力序列混音峰值：对照{render['peak_control']} PCM，降低钢琴版{render['peak_headroom']} PCM；无削顶、未知PCM、deadline违例。\n"
    text+='''

## 算术界与结论边界

profile6钢琴系数绝对值和184，16位正弦最大32767，包络最大65535；包含Q4舍入，单声部绝对值小于2944 PCM。柔和拨弦是16位原始样本的[1,2,1]/4输出平滑再除32，单声部上界约1024 PCM。8声部混合绝对和小于23552 PCM，20位Q4/32位求和/34位音量乘法均有余量。因此在当前参数和正确RTL执行下，普通16位满幅混音削顶不能解释已报告门槛。未据此排除板上实际数字错误或模拟链路异常。

PR1014通用时钟路由警告仍在，时序报告setup/hold均通过；已有EX3791位宽截断与优化移除提示仍保留，数学/范围/等价测试覆盖当前使用参数。未做门级时序仿真或板上电气测量。02的220/180ns是内部RTL采样间隔，不是探头测得的引脚setup/hold。

01钢琴约-18.06dB，拨弦不变；更小声的“干净”不能自动等同同响度改善。02保持PCM；03除负满幅饱和例外仅改变极性。02/03若没有效果，本轮只得到降低电平的可用缓解候选，不能标记根因解决。
'''
    (HERE/'VALIDATION.md').write_text(text,encoding='utf-8')
    (E/'README.md').write_text('# 输出链路隔离证据\n\n参见[验证说明](../../project/audio_output_lab/VALIDATION.md)和[验收步骤](../../project/audio_output_lab/BOARD_TEST.md)。本包是数字仿真/PnR和电脑参考音，板测等待用户，杂音是否改善未知。results.json保存四份fs哈希和源文件哈希；不把生成文件提交Git。\n',encoding='utf-8')
    print('OUTPUT_VALIDATION_ARCHIVE_PASS source/FS hashes, logs, audio, budgets and timing; board pending')
if __name__=='__main__':main()

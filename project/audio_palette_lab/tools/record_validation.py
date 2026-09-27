"""Collect only completed, source-matched evidence; never marks board acceptance."""
from pathlib import Path
import hashlib,json,re,shutil,subprocess
from generate import HERE,VARIANTS
ROOT=HERE.parents[1]
EVIDENCE=ROOT/'evidence/audio_palette_lab_2026-09-26'
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def main():
    EVIDENCE.mkdir(parents=True,exist_ok=True)
    results=[]
    for name in VARIANTS:
        p=HERE/'variants'/name/'impl';rec=json.loads((p/'build_provenance.json').read_text())
        assert all(rec.get(k) for k in ('build_pass','timing_pass','budget_pass'))
        for rel,digest in rec['source_hashes'].items():assert sha(ROOT/rel)==digest,rel
        assert sha(p/'pnr'/(name+'.fs'))==rec['bitstream_sha256']
        timing=(p/'pnr'/(name+'_tr_content.html')).read_text(errors='replace')
        for mode in ('Setup','Hold'):
            section=timing[timing.index('name="'+mode+'_Analysis"'):]
            m=re.search(r'<td class="label">Slack</td>\s*<td>([-.\d]+)</td>',section)
            assert m
            rec[mode.lower()+'_worst_slack_ns']=float(m[1])
        report=(p/'pnr'/(name+'.rpt.txt')).read_text(errors='replace')
        rec['ram_types']={kind:int(re.search(r'--'+kind+r'\s*\|\s*(\d+)',report)[1]) for kind in ('SDPB','pROM')}
        rec['warnings']=re.findall(r'^.*WARN\s+.*$',(p/'build_console.log').read_text(),re.M)
        results.append(rec)
    benches=['equivalence','keys','scheduler','controls','math','range','board']
    tests=[]
    for b in benches:
        path=HERE/'sim'/('palette_'+b+'_tb.log');log=path.read_text()
        marker='PALETTE_'+b.upper()+'_TB_PASS'
        assert marker in log and not re.search(r'\*\* (Fatal|Error)',log)
        line=next(l.strip('# ') for l in log.splitlines() if marker in l)
        tests.append(line)
        # Preserve messages; normalize only trailing log whitespace for Git.
        clean_log='\n'.join(s.rstrip() for s in log.splitlines()).rstrip()+'\n'
        (EVIDENCE/path.name).write_text(clean_log,encoding='utf-8')
    for p in (0,2,5,6):
        a=HERE/'sim'/f'cadence_{p}_0.txt';b=HERE/'sim'/f'cadence_{p}_1.txt'
        assert a.read_bytes()==b.read_bytes()
    math_result=json.loads((HERE/'sim/math_results.json').read_text())
    render_result=json.loads((HERE/'sim/render_results.json').read_text())
    for result in render_result:
        p=VARIANTS.index(result['variant'])
        log=(HERE/'sim'/f'render_{p}_1_0.log').read_text()
        assert 'PALETTE_RENDER_TB_PASS' in log and not re.search(r'\*\* (Fatal|Error)',log)
        for suffix in ('','_matched'):
            name=result['variant']+suffix+'.wav';src=HERE/'sim/audio'/name
            target=ROOT/'evidence/audio'/('palette_'+name);shutil.copyfile(src,target)
            result['wav'+suffix+'_sha256']=sha(target)
    payload={'base_commit':'d5ee69f','branch':'codex/audio-clean-zones','role':'A',
             'board_tested':False,'tests':tests,'cadence_profiles_1000_samples_each':[0,2,5,6],
             'math':math_result,'render':render_result,'builds':results}
    payload['test_source_hashes']={f.relative_to(ROOT).as_posix():sha(f) for f in (HERE/'sim').glob('*.v')}
    (EVIDENCE/'results.json').write_text(json.dumps(payload,indent=2,ensure_ascii=False)+'\n',encoding='utf-8')
    rows=['| 候选 | Logic | Register | BSRAM | DSP | IO | Setup / Hold余量(ns) |',
          '|---|---:|---:|---:|---:|---:|---|',
          '| 旧final_dual_timbre（已板测） | 12723 | 5459 | 80 | 57 | 19 | 3.473 / 0.191 |']
    for r in results:
        counts=' | '.join(str(r['resources'][k]['used']) for k in ('Logic','Register','BSRAM','DSP','I/O Port'))
        rows.append(f"| {r['variant']} | {counts} | {r['setup_worst_slack_ns']:.3f} / {r['hold_worst_slack_ns']:.3f} |")
    audio_rows=['| 候选 | 原电平RTL参考 | 首C4 RMS匹配参考 | 峰值 / 首C4 RMS(PCM) |', '|---|---|---|---|']
    for r in render_result:
        n=r['variant'];audio_rows.append(f"| {n} | [WAV](../../evidence/audio/palette_{n}.wav) | [WAV](../../evidence/audio/palette_{n}_matched.wav) | {r['peak']} / {r['first_C4_rms']:.1f} |")
    hashes=['| 固件 | SHA256 |','|---|---|']+[f"| {r['variant']}.fs | `{r['bitstream_sha256']}` |" for r in results]
    old=ROOT/'project/final_dual_timbre/impl/pnr/final_dual_timbre.fs'
    if old.exists():hashes.append(f'| 回退final_dual_timbre.fs | `{sha(old)}` |')
    body='''# 本轮验证 · 2026-09-26任务（9月27日收尾）

分支`codex/audio-clean-zones`，角色A，起点`d5ee69f`。七份均完成纯RTL仿真、综合及Gowin 50MHz PnR，setup/hold违例均为0。**本轮七份尚未用户上板验收。** 源码/固件哈希与原始测试摘要在[证据包](../../evidence/audio_palette_lab_2026-09-26/results.json)。

## 资源：采用最终PnR计数

'''+ '\n'.join(rows)+'''

00的BSRAM由80降到22（减少58块、72.5%），其中16块是独立拨弦状态RAM，6块是共享ROM；DDS精度候选按所需谐波使用更多表，最多34块。四通道/八槽调度和起音参数共享都已经进入可下载顶层。寄存器略增加是相位/包络快照、Q4路径及区配置锁存的代价。

全部保持八槽、两音色和19IO，PLL为0。对照声音在4582帧中逐样本相等；输入可接收窗口和计算完成时刻有变化，不主张逐fabric拍接口完全等价。1040拍音频周期内，八槽混音104拍（2.08µs）完成；这不是物理按键到模拟声音的总延迟。

A+输入预算70 BSRAM/78 DSP，本轮最多34/51，C的26 BSRAM/16 DSP仍完整保留。预算不因此扩大，最终音频+显示还需重新PnR，不能把两个独立报告相加当整机实测。

## 数字证据

'''+ '\n'.join('- '+t for t in tests)+'''
- 渲染加速对照：0/2/5/6四种数值路径各1000样本，跳过空闲fabric拍与真实1040拍的PCM逐样本相等；初始化保留实际节奏。
- 每份RTL参考151300样本，检查逐帧有效/未知值/溢出/截止；初始静音为精确零。七份真实RTL WAV与匹配参考见下表。保留所有原始样本，不把WAV送回FPGA播放。
- 数学独立参考14336组：整数结果全等；相对连续正弦的抽测最大误差，00约16.93 PCM最低位、01约4.17。是数字查表误差改善，不是板卡噪声测量；没有由此宣布噪声消除。

ModelSim使用纯RTL，不包含器件布局延迟或模拟DAC。`palette_board_tb`模拟无二极管矩阵的连通关系和串行接收；测试bench中的去抖时间缩短以加速，真实下载参数仍为原有值。全49音域测试验证接收、初始化和非零输出，不代替49个音高的实测听感/音准验收。

## 参考音频

'''+ '\n'.join(audio_rows)+'''

匹配文件按首个C4的RMS只做衰减：00–04的DDS为一组，05/06拨弦为另一组，用于组内近似同响度比较，不跨组等响；各音色其他音域/和弦的峰值并不保证一样。每声部固定标定，不随活跃数量减小已有音量。05/06去掉原槽的9bit限幅且延后量化，声音可能更响或更有高频细节，需听辨后选择；06的三点滤波会改变高频，不保证比05更好听。

## 构建指纹与复现

'''+ '\n'.join(hashes)+'''

构建器要求新FS时间戳、返回码成功、源文件在构建前后哈希相同、时序/资源通过；证据收集再次核对当前源码和FS。复现命令见[README](README.md)。源码通过相对路径复用，不依赖A的绝对目录。

## 留存的限制

- 原50MHz输入路径仍有Gowin PR1014普通布线时钟告警，本轮各候选setup/hold均通过；最终整合应复查时钟路由与实物表现。EX3791位宽缩减中，原拨弦截位保留，新增Q4/谐波缩位已由独立数值参考覆盖；不以“无错误”冒充“无告警”。
- 当前16个实体键是两组白键缩略；完整24/25实体交互、B控制板、压力输入、黑键手感尚未在本轮完成。
- 仍是8槽且满载拒绝新音，不截断旧尾音。没有新增选择性延音/滑音、32声部或吉他效果器。04是干声持续合成音，不冒称真实电吉他模型。
- 不宣称耳机/音箱噪声根因已经定位，原版及所有新音色都需用户试听。未修改旧已板测工程、烧写Flash或合并显示/蓝牙。
'''
    (HERE/'VALIDATION.md').write_text(body,encoding='utf-8')
    (EVIDENCE/'README.md').write_text('# 双区/音色实验数字证据\n\n结论见[工程验证](../../project/audio_palette_lab/VALIDATION.md)，结构化数据在[results.json](results.json)。七份均是待用户试听的新候选，不能覆盖旧final已板测事实。\n',encoding='utf-8')
    print('Evidence collected; source hashes, seven FS, seven bench logs and audio checked.')
if __name__=='__main__':main()

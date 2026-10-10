# Looper、鼓组与全局节拍器 · 2026-10-07 修复候选

> 2026-10-10更新：本页保留原轮次的对照／操作。最新鼓组和C接口改用[looper_session_v2](../looper_session_v2/README.md)；旧“待板测／主验收”描述按日期理解。固件与参考音由脚本本机重建，GitHub不包含本地acceptance里的FS/WAV。

独立实验工程，**数字验证与PnR完成后供用户上板验收，不替代已认可的audio_core_v2**。旧缩减版问题和撤回结论见[复查记录](REVIEW_2026-10-07.md)，旧固件不能用于验收当前功能。

本轮分支 `codex/looper-drum-night-20261007`；修复起点 `f0edf55`；角色A。任务范围为本实验和必要的进度/预算/证据文档。原V2 RTL、原V2约束及回退工程保持原样。

## 唯一可下载入口

| 项目 | 当前入口 |
|---|---|
| Designer工程 | `looper_lab.gprj` |
| Top Module | `looper_top`，19个实物IO |
| 当前构建固件 | `impl/pnr/looper_lab.fs` |
| 操作与板测 | [BOARD_TEST](BOARD_TEST.md) |
| 功能、单位、容量 | [SPEC](SPEC.md) |
| 数字/时序/资源/固件哈希 | [VALIDATION](VALIDATION.md) · `results/final/BUILD.json` |
| C后续接入内部状态 | [INTEGRATION](INTEGRATION.md) |

本机工作树为 `D:\uestc\SCM\GowinFPGA-looper-20261007`，以下命令从此工作树根目录运行。不要在旧工作树打开同名旧固件。本任务只准备SRAM下载，没有改写Flash。

## 候选功能

- 五个既有音色ID **0钢琴、2 Warm pluck、3 Metallic bell、4 Drive lead、5自定义四谐波**，新增ID6鼓组；一次固件切换，ID1继续退役。
- 旋律32共享槽，Warm pluck物理池12且计入32；鼓另外8击打槽。循环和现场共享旋律容量，满载拒收，不偷音。
- 四轨×四层×128事件；在每次实际开始录音时冻结音色/系数/包络。新叠录可选另一音色；四轨分别静音、调相对音量，现场不受轨音量影响。
- 一小节预备拍、1～4小节循环、关闭/1/8/1/16/1/32量化、边界叠录、撤销最后一层、清空选中轨、录音中停止取消当前take。
- 全局节拍器可单独使用；40～240 BPM、每格1 BPM、默认120；2/4、3/4、4/4；重/普通拍不同点击、独立点击音量。关闭声音不打断循环时钟。
- 现有矩阵、EC11 A/B和三个板载键完成演奏/Looper/混音/节拍器/自定义五页操作，不假定旋钮按压有效。

## 复现

```powershell
python project/looper_lab/sim/regress.py --modelsim E:/QuartusII/modelsim_ase/win32aloem --jobs 3
python project/looper_lab/sim/preview.py
python project/looper_lab/build_delivery.py --gowin E:/Gowin/Gowin_V1.9.12.03_x64/IDE/bin/gw_sh.exe
```

仿真带源指纹；构建确认输入运行期间没有变化。WAV位于 `sim/audio`，由RTL生成，不回灌FPGA。预览是单声部、干声、主音量前PCM，每文件固定试听增益；加速预览不是1040时钟截止证明，满载和实际音频周期另测。

## 范围与后续

实体板听感、手感、模拟杂音/SNR/延迟尚未验收。鼓组是FPGA合成候选，未直接移植开源鼓源码，不声称采样鼓的还原程度。持续推子/踏板/弯音自动化不录入；循环层自定义参数固定，现场参数仍可调。无TF持久化、ADC实体、蓝牙、显示；25键需换适配器。

本候选与C预留一起核对[预算](../../docs/team/RESOURCE_BUDGET_V1.md)。标量容量有余量不能证明合并后的放置/时序；本候选上板验收后再讨论替换集成基线。

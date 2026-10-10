# 三轮Looper工程与待验收入口

> 2026-10-10更新：本页保留原轮次的对照／操作。最新鼓组和C接口改用[looper_session_v2](../looper_session_v2/README.md)；旧“待板测／主验收”描述按日期理解。固件与参考音由脚本本机重建，GitHub不包含本地acceptance里的FS/WAV。

三个工程直接位于原工作区 `project/` 下，共用已有音频/输入依赖，不含重复仓库。

| 用途 | Designer工程 | 固件（本目录acceptance下） |
|---|---|---|
| **主验收：改进版** | [looper_refinement_lab.gprj](../looper_refinement_lab/looper_refinement_lab.gprj) | 02_refinement_20261008.fs |
| 优化对照：未晋升 | [looper_convergence_lab.gprj](looper_convergence_lab.gprj) | 01_convergence_20261009.fs |
| 原版对照 | [looper_lab.gprj](../looper_lab/looper_lab.gprj) | 03_original_looper_metronome.fs |
| 已认可演奏回退 | [audio_v2.gprj](../audio_core_v2/audio_v2.gprj) | 04_accepted_audio_v2_fallback.fs |

[完整验收指导](../../docs/project/LOOPER_TOTAL_ACCEPTANCE_2026-10-09.md) · [固件及参考音](acceptance/) · [反馈表](ACCEPTANCE_FEEDBACK.md)

仅SRAM下载。旧4×4矩阵、EC11、三板载用户键；尚未适配新控制板。保留独立候选与整机失败的原验证边界。

---

# Looper收敛与总验收

角色A；分支`codex/looper-convergence-20261009`，固定比较`9d28244`。
原Looper和改进版尚未板测，本目录继续做无需试听反馈的运算/传输/物理收敛，旧目录不改。
任务范围见[WORK_PLAN](WORK_PLAN.md)；明日实物操作统一读[总验收指导](../../docs/project/LOOPER_TOTAL_ACCEPTANCE_2026-10-09.md)。

唯一可下载工程：`looper_convergence_lab.gprj` / `looper_convergence_top` / 19 IO。
本轮整体面积/时序未优于上轮，尚未晋升；明日主验收仍选包内`02_refinement_20261008.fs`。
`audit`、`audit_pll`均是接口审计占位顶层，不能下载。实体ADC、25键、C显示/蓝牙不在板级候选里。

保留32共享旋律（其中Warm pluck物理12）、8鼓、4轨×4层×128事件、五音色固定ID0/2/3/4/5＋鼓6。
主时钟50MHz，Fs=50MHz/1040，不偷音、不按活跃声部数归一化；默认Q8谐波[256,64,32,16]及
全满总系数368保持。运算截断使用独立除法oracle，默认PCM对照原V2；状态分级复制保持LR1完整字段。

## 重建与检查

在仓库根运行；工具参数可按本机覆盖。构建不烧录、测试不推送。

```powershell
python -X utf8 project/looper_convergence_lab/sim/regress.py --jobs 2 --resume
python -X utf8 project/looper_convergence_lab/sim/preview.py --resume
python -X utf8 project/looper_convergence_lab/audit_pll/sim/run_clock_model.py
python -X utf8 project/looper_convergence_lab/build_delivery.py --stage final_50mhz
python -X utf8 project/looper_convergence_lab/build_audit.py --variant pll --stage registered_ready_50mhz
python -X utf8 project/looper_convergence_lab/tools/reset_constraints.py --profile board --verify
python -X utf8 project/looper_convergence_lab/tools/reset_constraints.py --profile pll --verify
python -X utf8 project/looper_convergence_lab/collect_evidence.py --audit-stage registered_ready_50mhz
```

完整接口失败时严格collector会拒绝；只授予独立固件资格须显式`--board-only`，保留失败证据。
通过和失败都按当前源指纹核对，不复制旧PASS作为本轮结果。
清单[ACCEPTANCE_PACKAGE](results/ACCEPTANCE_PACKAGE.json)记录本机统一包、四份FS和各自SHA；
[反馈表](ACCEPTANCE_FEEDBACK.md)可直接复制回对话。
结果和限制详见[VALIDATION](VALIDATION.md)，本轮不保证1ns余量或整机通过。
逻辑导入、54字状态字段、PCM/ACK与五推子语义见[LR1接入契约](INTEGRATION.md)。

内部LOCAL_CLOCK约束覆盖12个独立物理拨弦复位，并非一个基础复位的任意工具副本。
`tools/reset_constraints.py`从已生成的综合网表逐实例提取对应别名，不能直接套旧数字后缀。
修改RTL或换Gowin版本后先完成综合，再用`--profile board/pll --apply`重新生成本目录约束，
然后重建并`--verify`；既有外设针位保持。旧阶段的“副本”推断只作历史记录，当前证据按该工具和验证页。

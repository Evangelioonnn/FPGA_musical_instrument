# Looper session V2 · 新鼓组与 C 接口

独立新候选，2026-10-10。所有文件直接位于 `project/looper_session_v2`；源码、复现脚本及证据摘要纳入[本次开发同步](../../docs/project/GITHUB_SYNC_2026-10-10.md)，FS/WAV在本机重建。

这一版按[实物反馈](../../evidence/looper_refinement_2026-10-08/BOARD_LISTENING_2026-10-09.md)重排鼓组，并提供可直接操作的 Looper 命令、真实 LU1 状态和 PCM 接口。五旋律音色 ID **0/2/3/4/5**、32 总旋律槽（含12 Warm pluck池）、另8鼓槽、2048事件保持。C 的屏幕、PLL、TMDS、蓝牙本轮未接入。

| 用途 | 入口 |
|---|---|
| 上板试听新鼓组 | `looper_session_v2.gprj`，Top **looper_session_top**，19 IO；[验收](BOARD_TEST.md) |
| C 接真实音频/Looper | [C_HANDOFF](C_HANDOFF.md) → [LU1/命令契约](UI_CONTRACT.md) → `rtl/session_link.v` |
| C 独立先做画面 | `examples/session_ui_mock.v` → `rtl/session_ui_unpacker.v` → `examples/session_ui_view.v` |
| 精确鼓映射与调音依据 | [DRUM_SPEC](DRUM_SPEC.md)，不是旧16鼓表 |
| 本轮验证、资源与限制 | [VALIDATION](VALIDATION.md)，结果来自本目录当前源；不继承旧 PASS |
| 复制源码而不漏依赖 | `results/SOURCE_MANIFEST.json`，跨工程依赖均在原仓库；[打包检查](tools/check_delivery.py) |

本轮物理下载入口仅19针 `looper_session_top`。`session_link` 是逻辑集成模块，`audit/session_audit_top` 是资源审计顶层；**二者均不可直接烧录**。新控制板25键/6×6矩阵、三编码器及LED未适配进本固件，不能拿4×4 CST接新板。

复现（在仓库根目录，Python 与 ModelSim 路径可以按本机指定）：

```powershell
python -X utf8 project/looper_session_v2/sim/regress.py --resume --jobs 3
python -X utf8 project/looper_session_v2/tools/check_drum_math.py
python -X utf8 project/looper_session_v2/tools/check_ui_examples.py
python -X utf8 project/looper_session_v2/sim/preview.py --resume
python -X utf8 project/looper_session_v2/build_delivery.py --stage rebuilt
python -X utf8 project/looper_session_v2/tools/check_delivery.py
```

`--resume` 只复用源指纹仍完全匹配的本轮结果。保留旧 refinement、convergence 和已认可 V2；旧 Looper菜单困难不等于音频失败，也不把新的接口仿真称为屏幕实测。

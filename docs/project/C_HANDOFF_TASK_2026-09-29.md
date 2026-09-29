# C交接与文档清理任务 · 2026-09-29

- 角色：A，提供C设计目标及共享文档维护。
- 分支：沿用`codex/audio-integration-pack`完成本次交接；起点`e500e30`。
- 用户授权：生成给C的交接、规划屏幕交互/比赛拓展、核对GitHub冗余旧说明并整理。同步此分支；不合并main，不代发队友消息。
- 范围：README、docs、C角色/目录说明、旧音频说明中的过期板测文字；不改RTL/CST/SDC/IP/固件。
- 验收：当前接口不推荐SYSTEM_V0；当前事实不混入旧待测/网络失败；C目标区分已有与待实现，子预算不超总额，引用和依赖检查通过，远端分支提交一致。

## 核对与交付

1. Fetch确认GitHub main仍为4ada74e，交接分支为e500e30起点；明确README/WORKFLOW选分支，未覆盖main或删除历史分支。
2. 重读官方PDF第15～16页；C目标覆盖实时波形/频谱/李萨如/LED与脱机指引，蓝牙曲谱/任意映射/PCM回传分阶段争取。
3. 对照V2/V1继承字段、参数服务SPEC、现有BOARD_TEST和精简解包RTL，标出短按键事件、任意映射、推子位置等未提供项。
4. 新[C交接规划](../team/C_HANDOFF_AND_DISPLAY_PLAN.md)含快速入口、三套界面方向、音色适用控制、交互、资源/带宽算术、两周目标；不冻结具体实现。
5. 长STATUS/旧要求表/旧排期/旧显示接口原文归档；原路径改为当前入口，旧CONTROL/EVENTS/SYSTEM等保留但加历史标签。
6. 只做文档与算术/链接核查；不重跑未改的音频RTL/PnR，不新增板测声明。完整核心ModelSim复跑停滞的边界继续保留。

## 本轮检查结果

- `python tools/check_repository.py`：`REPOSITORY_CHECK_PASS files=1238`；仓库链接、工程/include依赖及参考资料哈希通过。
- `git diff --cached --check`：通过；提交范围为30份Markdown/历史文本，无RTL、约束、IP或构建脚本变更。
- 独立算术核对：C子项合计13000 Logic/10000 Register/26 BSRAM/16 DSP；帧缓存、FFT存储理论块数及PCM带宽计算通过。它们是设计估算，不是新增综合/PnR结果。
- 同步目标：`origin/codex/audio-integration-pack`；main不合并，C应从交接分支最新文档开工。

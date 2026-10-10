# 2026-10-10 开发同步证据

用户授权筛选上传，此包保留复现与交接所需文件。[范围与入口](../../docs/project/GITHUB_SYNC_2026-10-10.md)区分最新候选、历史对照和控制板；排除本机固件、仿真库、构建输出、EDA备份及未定型草稿。

[SOURCE_MANIFEST](SOURCE_MANIFEST.json)记录本次选定文件和明确的LF／二进制SHA单位，`tools/check_sync_snapshot.py`核对；[CHECKS](CHECKS.json)记录当前源资格、干净导出检查及最小接口复现的结果。精确上传数量／大小以manifest为准，不把本地所有未跟踪文件当成发布包。

本轮是同步／可复现性检查，没有新增音色板测、模拟测量或整机PnR。48项回归／9WAV和19针50MHz资格来自对应Looper session V2验证；未合格的全接口审计仍保留失败范围。硬件仅上传R3对应可编辑源及审查，制造／实物状态按BOARD_CURRENT。

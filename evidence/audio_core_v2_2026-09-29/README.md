# 音频V2证据

本轮Owner A，分支codex/audio-core-v2，基线615cb94。
验证入口：[完整报告](../../project/audio_core_v2/VALIDATION.md)；
[板测说明](../../project/audio_core_v2/BOARD_TEST.md)；
[接口](../../docs/interfaces/AUDIO_CORE_V2.md)。
机读 `validation.json` 在全部门槛通过后由tools/record.py生成，包含当前源码指纹与LF可移植指纹。

19针音频PnR、完整接口+输入仅综合、数字仿真、RTL参考音、用户实物反馈是不同证据。
本目录不会把V1的用户认可转成V2板测完成，也不把容量证明转成模拟频谱/SNR。
旧架构失败边界记录在audio_core_v2/experiments，不作为验收固件。

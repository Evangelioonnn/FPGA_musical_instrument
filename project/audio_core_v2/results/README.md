# 证据入口

正式汇总为 `validation.json`，由tools/record.py在全部八项PASS、最终根入口PnR、
完整接口+输入综合和七段WAV完成后生成。其source_sha256/source_lf_sha256核对当前实现。

本轮正式测试文件为 `*_stream_p12_m0.json` 与 `headroom.json`。
`*_pool_*`、`*_compact_*`、`*_stream_p16_*`属于架构探索历史，
其中保存的源指纹可能与后续改进不一致，不用于宣称当前固件通过。
原始ModelSim日志留在sim，原始PnR留在impl，不提交工具库或缓存。

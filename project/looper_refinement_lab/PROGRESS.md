# 本轮状态与接续

工作树D:/uestc/SCM/GowinFPGA，分支codex/looper-refinement-20261007。比较commit0199ed7，原V2与旧looper工作树未改。

功能/接口源已冻结：quarter sine；每层踏板/有界弯音；串行录音身份；寄存时间戳合并；geometry寄存；MCP3208/五推子模式；LR1状态/PCM/ACK与owner仲裁。40槽、tap/细分未采纳，原因看WORK_PLAN。

最新19IO板顶层final_50mhz已通过：33466Logic/17075Reg/23673CLS/75BSRAM/31.5DSP，20ns setup/hold0/0，余量0.018ns，Fmax50.044MHz。时序余量很薄，不能当合C已经收敛。18ns guard失败-0.466ns记录保留。

40项必需测试（含SERIAL_NOTES实际容量2048）已全部当前源PASS，最后regress.py --jobs 1 --resume逐项核对指纹。2预览bench最终均PASS；9 WAV生成并回读原PCM通过。首次长预览/干声各在2400/1800秒超时，不算PASS；合格长预览使用CE256离线加速，干声CE64。

18ns接口审计失败300网；实际20ns默认审计失败333网；基础voice_rst的LOCAL_CLOCK候选失败272网。最终audit_pll复用已板测显示PLL、配置50MHz→150MHz及lock复位，仍失败3402网：41005Logic/22760Reg/26449CLS/79RAM/31.5DSP/1PLLA；PRIMARY/LW各8/8。四份FAILURE.json均保留，未得到接口STA/可用FS，不能把未布网减少或行为模型通过当整机通过。

收尾结果：严格完整collect已按预期拒绝失败接口审计；--board-only核对当前40项必测＋2预览＋PLL wrapper行为模型、9 WAV/PCM及源/FS指纹，生成BOARD_DELIVERY.json。独立板候选合格，接口物理/整机未合格。文档、资源预算和验收入口按此分层，代码仅本地任务分支提交。

后续先按BOARD_TEST实物验收；取得C固定源码后，优化声部状态访问/快照选择、实际release→pluck关键路径及复位/使能分发，再最小整机PnR。实体ADC/25键/C最新UI/蓝牙/模拟SNR延迟未验收，40槽/tap/细分继续延后。

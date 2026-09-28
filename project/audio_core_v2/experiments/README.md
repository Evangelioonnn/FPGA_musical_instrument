# 架构探索历史

这里和相邻 `variants/` 是本轮中间验证，**均不是最终下载入口**。
正式工程只用上一级 `audio_v2.gprj` / `audio_v2_top`。

| 尝试 | 已观察到的边界 | 决定 |
|---|---|---|
| 静态复制32声部状态 | 综合63353 Logic，超器件 | 不采用 |
| 共享波形、全寄存器状态 | PnR32080 Logic/18614 Reg，setup -3.195ns | 不采用 |
| 16拨弦仅共享释放 | 综合33416 Logic/17660 Reg/59 BSRAM/75.5 DSP | 不采用 |
| pool16共享全部拨弦乘法，批量声部渲染 | PnR32858/17292/66/28.5，setup -4.717ns | 不采用 |
| compact16取消渲染器批量状态拷贝 | PnR32377/15050/70/28.5，setup +0.194ns；全接口Logic36372 | 超预算，不采用 |
| stream16逐声部渲染 | PnR28307/12757/74/28.5，setup +0.004ns；全接口Logic32343 | BSRAM、完整Logic和时序余量不合适，不采用 |
| stream12 | 容量与全接口审计通过 | 选入正式工程；最终数以VALIDATION为准 |

这些数字对应当时保存的实现，不与之后的源码更改混用。
`src/audio_v2_bank.v`、`*_ram.v`、`*_pool.v`、`*_compact.v`及旧slot/state是负例复核材料，
旧 `run_pool.py` / `run_compact.py` 为历史测试入口；它们不构成本轮通过证据。
`prepare.py` / `prepare_tests.py` 是首次派生辅助，不要拿来覆盖现有主工程。
`variants.py`结构化重建候选工程，可能使用已改进的公共算子；重建结果不自动等于历史表。
正式证据只收取当前stream12根入口、当前测试源及当前完整输入综合。

带几千个端口的 `interface_audit*` 仅综合，禁止作为板级顶层PnR或下载。
比特流、impl和ModelSim库不提交Git。负例有参考价值，不假装它们通过最终预算。

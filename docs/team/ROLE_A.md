# A：音频核心与系统集成

A是当前持板成员及项目用户。负责实时声音生成、选定效果、音质定位、共享接口、整机顶层/CST/SDC、资源时序和最终验证。B/C的内部实现无需逐行等A批准；跨子系统改变通过PR说明影响并合并。

## 当前最有价值的工作

9月28日用户选定五音色作为后续音频核心：Precision harmonic piano、原拨弦、Warm pluck、Metallic bell、Drive lead。新[五音色工程](../../project/five_timbre_core/README.md)用于音区响度、主奏表达、普通/选择性延音和资源实验；源码及固定编号见其SPEC，数字/PnR及板测边界见VALIDATION。与B/C整合时以五音色编号作为新接口提案，尚未实物试听前保持final_dual_timbre为已认可的回退固件。下条9月26日记载保留其当时范围。

9月26日当前基准是已获用户板测认可的[final_dual_timbre](../../project/final_dual_timbre/README.md)，harmonic_piano/pluck与矩阵/旋钮/板载键为第一版完整音频演示；显示彩条另已板测，尚未整合。按[团队预算V1](RESOURCE_BUDGET_V1.md)优化音频至68块BSRAM额度内，新增第三音色、选择性延音/滑音、完整ADSR及适量数字效果器；拨弦自然衰减。A负责真实状态/PCM/配置适配，先做音频+显示最小整合，再扩展。预算是目标，当前音频仍为80块BSRAM。

下列9月19–22日工作描述保留为历史参考，旧“待到货/未验收”不覆盖当前状态。

夜间候选已新增输入链路、真实状态、独立CDC、配置仲裁与诊断工程；交接见[MORNING_REVIEW](../project/MORNING_REVIEW.md)。下面的“增加/建立”任务可复用这些模块，先检查[SYSTEM_V0](../interfaces/SYSTEM_V0.md)和已知限制，避免重新写一套。

9月20日的[旋钮候选验收](../project/KNOB_REVIEW_2026-09-20.md)保留为历史复现入口：EC11旧持续变调已板测，五份旋钮固件已收到首次功能与杂音反馈，详见STATUS。外部按键的身份/松键接口本轮在matrix_playable候选实现，仍需正式集成；旧定时接口边界见[KNOB_CANDIDATE](../interfaces/KNOB_CANDIDATE.md)。

1. 用原固定音色完成[模拟链路定位](../../project/audio_quality/NOISE_DIAGNOSIS.md)，保存实际.fs哈希、耳机/电源和测量条件。不要把问题转交B/C盲调。
2. 9月20日器件到货后与B逐项核对电气，再建立扫描/去抖→事件→8声部的最小可演奏链路。矩阵扫描、EC11、ADC适配的RTL归属逐项写入任务，不能含糊地认为“画板的人全包”。
3. 将自动demo与真实输入适配分开；保留演示回归。冻结第一版共享契约和能力表，明确未生效配置、不同输入源仲裁、断连/队列满处理。
4. 为C提供可靠的状态快照和波形抽取接口；现有baseline的meter固定0，不能直接给C当实时电平使用。

## 合入标准

音频模块提交testbench、数值边界、资源/时序；交互接入需多键/重复音/移调松键/去抖延迟测试；通信显示必须证明不会阻塞音频。每次整机合并保留基准音色回归和未解决缺陷，端到端延迟需要真实输入到输出测量。

默认试听见[AUDIO_TEST_BASELINE](../project/AUDIO_TEST_BASELINE.md)。新音色及32声部探索单独分支，不能为做效果同时改动故障排查基准。先按[路线](../project/ROADMAP.md)完成可用乐器，再用测量选择扩展。

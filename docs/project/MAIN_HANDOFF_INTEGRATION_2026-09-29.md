# 完整交接汇总入main · 2026-09-29

- 角色：A，总集成与仓库交接。
- 用户目标：解决完整交接成果未进入默认main的问题，让队友直接拉取main即可开工。
- 任务分支：`codex/main-handoff-integration`；成果来源`codex/audio-integration-pack`，起点`156f12f`；目标main起点`b8efb43`。
- 范围：汇总此前44个提交的音频、输入/音色实验、独立显示、资料/证据及文档；本轮处理README冲突、统一main入口，并修正证据检查器对已审阅仿真包装脚本变更的处理，没有编写新的音频/显示/无线RTL。
- 验收：源分支成果完整保留；README冲突解决；源码/约束/IP与156f12f一致；依赖、证据指纹和接入包检查通过；PR通过普通merge进入main且远端树一致。

## 包含的主要成果

1. 当前audio_core_v2五音色及32共享槽/12拨弦池，V1/final回退和历次诊断/实验。
2. 音频接入包：源码清单、状态/PCM/命令CDC、精简UI解包、mock、保留接口PnR及拒绝的优化候选证据。
3. 独立1080p彩条、板卡资料/J13说明、比赛要求、B/C角色、资源预算与C屏幕/蓝牙设计目标。
4. 区分当前事实、历史基准、数字/PnR/参考音/用户反馈；不带impl、比特流、许可证或个人凭据。

## 合并处理与边界

main自初次交接后的独有变更是首页PR #3，与交接分支只在README冲突。本轮保留完整当前入口并改为main内相对链接；STATUS、WORKFLOW、C交接和目录入口同步以origin/main为开发起点。已有B/C任务分支先提交本地成果再合并origin/main；此次使用普通merge保留历史，便于同步。

仓库main是可复现且限制有记录的开发基线，不是比赛正式发布，也不是音频/显示/蓝牙/实体ADC已完成整机接入。原0.076ns保留接口审计时序余量和完整核心ModelSim复跑停滞的边界继续保留，不因合并获得新的PASS。

## 本轮验证

已记录的音频仿真/PnR/板测范围按各原证据解读；本轮没有改RTL，不能宣称重新完成全部历史实验或模拟端验收。

证据核查首次失败于sim_rom.py：615cb94的原记录使用旧包装脚本，f5dcfe8为了隔离ModelSim库改为临时目录。差异不涉及ROM解析、生成内容或RTL测试。重新执行ROM等价检查通过6152项，三个生成文件指纹与历史记录相同。新增[精确变更审阅](../../evidence/harness_review_2026-09-29.json)，检查器只识别该Python文件的确切旧/新哈希对，保留旧音频证据的原始指纹并单列历史包装提示；其它修改仍报错，不能视为新的完整音频回归。

- `python tools/check_audio_evidence.py --check-index`：11份证据记录、1440次源码比较通过，单列1个已审阅历史包装脚本，不改写原记录。
- `python project/audio_integration/tools/package_check.py --modelsim-bin E:/QuartusII/modelsim_ase/win32aloem`：四种源码profile的干净导出/编译/顶层展开、精简状态和mock两个消费者测试通过；profile源数20/4/25/6。
- `python project/audio_core_v1/tools/sim_rom.py --modelsim E:/QuartusII/modelsim_ase/win32aloem`：6152项ROM比较通过，原始与生成文件指纹被核对。
- `python -m unittest discover -s tools/tests -p test_audio_evidence.py`：4项通过，包括保留历史指纹、拒绝进一步包装修改/非审阅旧哈希/RTL修改。
- 以156f12f为来源核对：没有RTL、CST/SDC、IP配置、gprj变更。冲突仅README；既有证据数据不改写。

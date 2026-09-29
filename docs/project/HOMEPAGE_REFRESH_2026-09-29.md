# GitHub默认首页修正 · 2026-09-29

- 角色：A，维护仓库交接入口。
- 用户目标：刷新仓库主页仍显示旧README，修正默认main首页，使队友直接找到最新进度和交接。
- 首页任务分支：`codex/homepage-refresh`；起点`4ada74e`，README提交`ab2ce4d`。
- 范围：仅更新main的README，通过[PR #3](https://github.com/Evangelioonnn/FPGA_musical_instrument/pull/3)合入；整批音频/接口成果仍在交接分支，不随本PR合入。
- 后续记录：在`codex/audio-integration-pack`、起点`05b2d75`更新README/STATUS/WORKFLOW/C交接中的main描述及本记录。

## 结果和核对

1. 默认分支确认为main，原README仍描述矩阵/EC11未接入并推荐旧expression演示。
2. 新首页显示五音色、32共享槽/12拨弦池、已有操控、独立显示板测及未验收范围；所有交接链接指向当前分支，显著提示main旧源码尚未整体更新。
3. `python tools/check_repository.py`通过（首页PR范围221文件）；`git diff --check`通过；13个GitHub交接文件链接逐一核对远端交接分支对象存在。
4. PR #3仅含README一项变更；合并成功，main提交为`b8efb436aa7e08749050349d00cedc025d0efb35`。
5. GitHub API读回main README，完整正文与本轮提交内容一致，文件对象为`90bb1c4d2a313a98007e0c79e647d7b19b9c5e69`。

没有新增RTL、固件、板测或整机通过结论；没有发送队友消息或改写板卡Flash。后续完整交接通过独立PR合入main后，再统一将首页入口改为main。

## 后续可读性核查

用户要求从新队员接手角度复查其它值得明确之处。角色A，分支`codex/audio-integration-pack`，起点`643552b`；范围为历史音色基准/开发方法、证据入口与索引、工程索引及预算中的验收措辞，验收为当前/历史不矛盾、链接检查通过，不改RTL或整批合入main。

查出并修正：旧正弦规则仍称当前默认，证据索引V2仍写待板测，证据首页仍把旧16秒baseline称当前演示，预算笼统写V2已验收。现在明确五音色基线、总体听感反馈和仍待模拟/满载/整机验证的边界。主要结构性待办仍是完整交接PR合入main；本轮不扩大为代码合并。旧分支及未合并历史PR保留，不能因名称旧就推断可删除。

核查结果：`python tools/check_repository.py`通过（1239文件）；`python project/audio_integration/tools/package_check.py --static-only`通过（core20/transport4/integration25/consumer6源清单）；`git diff --check`通过。只修改8份文档，未重跑未改变的音频仿真/PnR。

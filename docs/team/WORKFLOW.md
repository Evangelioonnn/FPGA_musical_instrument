# 三台电脑、一块板卡的协作方法

远端仓库：[FPGA_musical_instrument](https://github.com/Evangelioonnn/FPGA_musical_instrument)。公开可读不代表任何人能push；所有者需在Settings→Collaborators邀请B/C的各自GitHub账号。本次整理不代发邀请。

## 第一次接手

1. 安装GitHub Desktop并登录自己的账号，File→Clone repository→URL。选择本机固定目录，避免云盘实时同步这个目录。
2. 在main执行Fetch origin / Pull origin。阅读README、AGENTS、STATUS、REQUIREMENTS和自己的角色文档。
3. 安装Gowin Designer/Programmer，按[板卡说明](../board/BOARD.md)选GW5AT-60B。ModelSim或兼容Verilog仿真器用于RTL；当前脚本为Windows ModelSim。纯RTL能跑不代表Gowin IP模型已配置。
4. 安装Python 3，运行`python tools/check_repository.py`；需要音频仿真时，运行README的baseline脚本并指定自己的ModelSim路径。baseline Python分析仅用标准库；部分历史工程需要NumPy。
5. 新建短期分支，首个任务采用角色入口给出的交付。B可先提交文档/原理图，C可先提交协议/显示仿真，无需借板才能开始。

## 每天的工作循环

main上Fetch/Pull → Branch→New branch（如`feat/b-control-io`）→修改自己的目录→运行相关检查→查看Changes是否混入缓存/个人资料→填写明确commit→Push origin→Create Pull Request→说明改动、接口影响、验证与待测项→评审合并→切main并Pull。

每项功能一个分支；三个人不要共同写一个长寿命分支。刚开始只用main＋任务分支，不增加develop层。main是“可复现且缺陷有记录”的集成基线，不宣称每个拓展已完成。

CLI等价起步（有未提交改动先保存/提交，再切分支）：

```powershell
git switch main
git pull --ff-only
git switch -c feat/b-control-io
# 修改并检查后，只选择本任务文件提交
git add hardware/interaction docs/team/ROLE_B.md
git commit -m "docs: propose interaction layout and IO needs"
git push -u origin feat/b-control-io
```

任务进行期间main前进：提交当前工作，再`git fetch origin`、`git merge origin/main`，解决冲突并重测，不用force push覆盖队友。共享接口、CST、顶层冲突由相关人一起核对语义，不能只选“全保留我的”。必要时用revert回退有问题提交，不重写大家已拉取的main。

## 评审与执行边界

- A负责共享契约和最终顶层/CST/SDC整合；B/C提出改动和影响。接口/电压/引脚变化先形成PR供核对，日常内部开发可继续。
- A的音频或集成改动也交给队友复核，至少核对需求和验证结果；不要求B/C为没学过的算法背书。
- 仓库规则不代替用户授权。采购、PCB投板、改写Flash、正式发布及消息发送不由普通编码任务自动授权。
- 推荐在三人均有访问权限后设置main保护和至少1人评审；当前未代改仓库设置。若启用保护，首个交接提交之后都走PR。
- 客户端/工程默认路径示例不是固定安装位置；脚本参数优先。拉取gprj更新后重开Designer，并确认顶层为expression_baseline_top，避免旧窗口再次以expression_core综合成859个IO。

## 单板卡验收

每次预约写：分支/commit、构建命令、.fs哈希、接线图、是否SRAM、预期现象、退出/回退方案、板测负责人。优先A组织整机刷写，B/C提交可单独运行的验证顶层、TB与清单。交接照片、波形、测量数据和结论写入`evidence/`，至少标明commit与实际固件哈希。

未上板模块可以带“仿真已过/待板测”合入文档清楚的main，但不能冒充硬件已验收。合并多个模块后必须重新综合/PnR、重新做整机测试，不能拼接各模块报告代替。

## 给各自Codex的开工文本

使用[任务模板](../../templates/TASK_HANDOFF.md)，明确“我是B/C、当前分支、负责目录、目标、验收、不得擅改的共享接口”。先让它读仓库现状再实现；其它人的聊天不自动共享。会话结束把决策、接口、测试和阻塞写回PR/文档，下一人不必重猜。

提交源码、约束、IP配置/必要生成文件、素材生成脚本与来源。不要提交impl、ModelSim库、安装包、许可证、凭据或私人绝对路径。`.gitignore`是当前工程的规则；新IP如果确实需要被忽略的数据扩展名，应精确加例外，不能导致干净克隆缺输入。

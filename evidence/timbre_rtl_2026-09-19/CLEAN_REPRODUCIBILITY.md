# 干净导出复现 · 2026-09-19

从本轮Git暂存区用`git checkout-index --all --prefix=...`导出到新的本地目录。没有复制impl、ModelSim工作库、旧样本或个人工程设置。原工作区最终Gowin已完成源码哈希核对，干净副本不重复PnR。

使用ModelSim ALTERA 10.1d和已安装NumPy的Python，分别运行`fm/sim/run.ps1`、`pluck/sim/run.ps1`和共享`sim/run.ps1`；入口均相对于`project/experiments/timbre`。5个bench及两个独立数学分析全部通过，原始样本数量与主工作区相同。仓库依赖/链接/参考资料哈希检查通过。

干净副本重新生成的FM和拨弦WAV与本轮发布试听逐字节相同，各721204字节、360580个16位样本。哈希见[复现数据](clean_reproducibility.json)。这项检查证明当前脚本不依赖未提交的初始化文件或历史样本，不代表其他工具版本或操作系统已经验证。

没有下载开发板、没有模拟采集、没有真实外部输入；新RTL音色和模拟杂音仍等待用户板测。导出后只补充本复现说明及FM振荡器计数说明，未修改RTL或测试逻辑。

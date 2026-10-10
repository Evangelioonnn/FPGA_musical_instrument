# 2026-10-10 开发同步

用户授权筛选并上传此前必要的未同步成果。本次以远端main的`e70e4db`为起点，在`codex/github-sync-20261010`分支分项提交，通过PR同步开发main；不替C合并显示／蓝牙分支，也不发布比赛成品。

## 保留的内容

| 范围 | 为什么保留 | 使用方式 |
|---|---|---|
| [looper_session_v2](../../project/looper_session_v2/README.md) | 最新鼓组、直接操作命令、LU1真实状态、PCM与C示例 | 当前试听及C后续整合入口 |
| [looper_refinement_lab](../../project/looper_refinement_lab/README.md) | 首轮基本循环反馈、表达录放，以及最新鼓回归所需的冻结参考 | 历史回退／对照，不沿用旧鼓映射 |
| [looper_lab](../../project/looper_lab/README.md) | 原始事件循环、全局节拍器、测试和比较基准 | 原始对照 |
| [looper_convergence_lab](../../project/looper_convergence_lab/README.md) | 资源优化与失败边界、统一验收／重建脚本 | 未晋升的历史实验，不作为默认候选 |
| [BOARD_CURRENT](../../hardware/interaction/BOARD_CURRENT.md)与[KEYBOARD_V2.eprj](../../BOARD/KEYBOARD_V2.eprj) | 当前控制板可编辑源、真实针序、ADC通道与RGB装配方向 | A/B接入前的唯一硬件入口 |
| R2／R3、器件手册和必要审查图／JSON | 说明反贴灯方向及整改闭环，避免重复踩坑 | 最终结论以R3为准；静态审查不等于上电验收 |
| README、角色入口、预算、契约、板测反馈 | 让队友直接找到最新接口，分清候选与已验证范围 | 日期较旧的记录保留原范围 |

每个工程保留手写RTL、CST／SDC、GPRJ、IP引用、构建／仿真脚本、独立testbench和小型结果摘要。没有仅因实验失败就删除它的事实记录，也没有把中间日志都上传。

## 留在本机的内容

`impl`、ModelSim库、FS、生成WAV／PCM、构建日志／HTML／详细时序输出、未完成回归记录、原始搬迁日志，以及EDA自动备份、重复ZIP／EPRO导出和未定型的其他EPRJ草稿。只上传当前`BOARD/KEYBOARD_V2.eprj`，不上传整个BOARD目录。

固件与参考音按各lab README本机重建；旧acceptance清单是原本机交付的哈希记录，不是GitHub下载链接。若新构建产生不同固件哈希，另记新结果，不改写原板测所对应的冻结证据。控制板源保持SHA256：

`9fef757ce0cdec04cb2dcaac7497c8e602ddf12374eae4b157a233c8adb9850d`

## 检查与证据

```powershell
python tools/check_repository.py
python tools/check_sync_snapshot.py
python project/audio_integration/tools/package_check.py --static-only
```

仓库检查涵盖发布文件集、Markdown链接、GPRJ／include依赖及官方参考资料指纹；同步清单另外核对本次源码／文档和二进制源，见[同步证据](../../evidence/github_sync_2026-10-10/README.md)。在本机先核对最新48项回归与19针固件的当前源，再对干净Git导出做静态检查和最小接口复现；没有为上传重复全量PnR，也不增加板测资格。

Git会按仓库规则规范化文本换行。历史结果中的原始字节SHA按原轮次保留；本次[SOURCE_MANIFEST](../../evidence/github_sync_2026-10-10/SOURCE_MANIFEST.json)对文本按LF计算、二进制按原始字节计算，供其他电脑检查相同源码。此校验不表示本机旧PASS可以直接替代新源码仿真；更新RTL或工具后仍按相应脚本重跑。

旧实验比较提交可能只存在A的本地历史；本次上传冻结比较源码和必要结果，不要求队友切换这些历史SHA，也不上传旧工作区的重复仓库。

## 当前边界

独立`looper_session_top`的50MHz PnR通过，75 BSRAM／32.5 DSP、setup／hold 0／0、余量1.117ns。保留全接口的50／150MHz审计仍有41个setup违例、最差−0.368ns；它不能下载，也不能称整机通过。C显示／蓝牙、实体6×6控制板／ADC和模拟SNR／延迟尚需各自接入、联合PnR与实测。

新鼓组尚待用户试听；首轮五音色和基本循环反馈见[原实物记录](../../evidence/looper_refinement_2026-10-08/BOARD_LISTENING_2026-10-09.md)。没有因同步改变制造／到货／焊接状态、写Flash或发送队友消息。

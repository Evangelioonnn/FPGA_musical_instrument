# C交付：演奏主屏与真实双声道波形

本目录是目前交付的独立 Gowin 工程，纯 HDL 绘制非触控屏幕。用户已反馈主屏可用，并确认 SCOPE AUTO V2 波形实现可用。完整责任边界、接口和后续协作见 [HANDOFF_ZH.md](HANDOFF_ZH.md)。

| 入口 | 内容 |
|---|---|
| `instrument_ui_redesign.gprj` | 唯一工程，顶层 `instrument_ui_top` |
| `build.tcl` | 设置顶层/输出名，运行综合与布局布线 |
| [DOWNLOAD_ZH.md](DOWNLOAD_ZH.md) | 从完整仓库打开、编译、检查与 SRAM 下载 |
| [BOARD_TEST_ZH.md](BOARD_TEST_ZH.md) | 页面、按键和用户板测范围 |
| [validation/routed_build.json](validation/routed_build.json) | 实际资源、时序、源码指纹及固件 SHA-256 |
| [validation/wave_results.json](validation/wave_results.json) | 六项 RTL 测试及用户反馈范围 |

演奏主屏显示真实音色、音量、旋钮模式、延音/释放、房间参数、声部和琴键状态。波形页观察 `audio_v2_core.final_valid/final_left/final_right` 的 DAC 前真实 PCM，每窗512对连续16位样本，约10.65ms；先求本窗双声道共同峰值，再选择1～256倍显示增益。原始PCM和耳机音量不受影响。干声L=R时两条波形一致。

当前硬件输入仍是4×4矩阵16键、EC11和三板载按键。底部25键图形代表两八度加高Do，不表示实体25键已接入。USER2短按松手切音色，长按约0.8秒在主屏/波形页切换；本工程临时替换其长按恢复参数功能。其他操作见板测说明。

当前仅实现两个页面。FFT、李萨如、曲库/曲目引导、蓝牙、屏幕参数编辑以及队友的新Looper尚未接入。音频基线 `e70e4dbe7de1a61edb8a4f3ea2c7f361bfcce6d2`，29项共享源/头文件与交付时远端main已核对相同。工程通过相对路径复用仓库源码和PLL，不要只拷贝这个文件夹。

复现：先运行 `python tools/verify_delivery.py` 核对来源；运行 `sim/run_v2.ps1` 和 `sim/run_wave.ps1`（可用 `-VivadoBin` 指定XSim目录）执行六项测试。Gowin运行 `build.tcl` 后执行 `python check_build.py`，只有实际时序、针位、新鲜度检查通过才下载。编译不需要Python字体生成步骤；现成字模HDL已包含。修改中文标签时才使用 `tools/generate_ui_roms.py`（Pillow及本机字体路径），并重新仿真/编译。

本次仅发布当前有效源码、约束、工程、测试与证据。旧UI、旧波形、电脑草稿、失败尝试、回退目录、impl、仿真工作库、字体安装包和`.fs`均不进入Git。构建报告为某一次实际结果，其他版本或机器重编译须重新记录，不能仅因生成固件便视为时序通过。

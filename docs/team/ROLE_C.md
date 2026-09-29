# C：显示与蓝牙 · 当前开工入口

你负责FPGA可视化、蓝牙扩展、必要客户端、曲谱/LED引导和素材；具体首屏、模式与实现顺序由你设计。你还没有开始最终模块，直接基于A提供的[音频接入包](../../project/audio_integration/README.md)开工，不必从SYSTEM_V0或旧final重新发明音频适配。

**先读这四份：** [STATUS](../project/STATUS.md)、[最新资源预算](RESOURCE_BUDGET_V1.md)、[导入规则](../interfaces/AUDIO_IMPORT_V1.md)、[传输契约](../interfaces/AUDIO_TRANSPORT_V1.md)。字段/单位详见[音频V2](../interfaces/AUDIO_CORE_V2.md)及其引用的V1位布局。

## 可以直接复用

| 需要 | 模块/入口 |
|---|---|
| 导入真实32槽/12 Warm pluck音频，避免重复RTL | 接入包源码清单与Tcl导入；只有一份同名bank |
| 完整状态跨到像素/消费时钟 | `audio_snapshot_bridge`：46个64bit字/记录，含能力表、序号、全部声部、扩展和25键 |
| 少量字段驱动首屏 | `audio_state_view`：完整记录后原子提交精简UI字段 |
| 无板做渲染/协议验证 | `audio_observer_mock`及独立测试 |
| 实际DAC前PCM用于波形/FFT | `audio_pcm_bridge`：全速有符号16bit L/R、32bit序号、session/gap |
| 远端提交参数并得到实际ACK | `audio_command_bridge`：单未完成事务，地址/值/tag、接受/应用和规范目标读回 |

观察端暂停只影响观察，不能停音频；完整状态可丢中间记录，PCM缺口必须丢弃不连续FFT窗口。桥需要所有相关域共同异步置复位、各域同步释放；panic不等于复位传输链。显示在帧边界接纳状态，不能逐位同步宽总线，也不要接收半包就刷新画面。

这是**内部FPGA接口**，不是冻结的UART帧格式；C仍需设计版本、包长、CRC、序号/重试、断连恢复和模块选型。桥不做无线重复包去重。参数服务ACK表示目标提交，不等于平滑已经完成；音量/系数实际值从状态读回。既有历史baseline的“接受但忽略”能力不适用于新V2，也不要拿旧832bit或229bit解析器直接解新状态。

## 资源与硬件

C保留 **13000 Logic / 10000 Register / 26 BSRAM / 16 DSP / 1 PLL**，包含自己的UI/字体、FFT、曲谱、UART队列及新增缓存。A提供的公共传输桥按最新总账单独计入A，C不重复加一次；更多FIFO/帧缓冲仍须计入C。

独立[TMDS彩条](../../project/visual/dvi_colorbar_probe/README.md)已在普通HDMI显示器稳定显示1920×1080、61Hz，使用J14/H14、J15/H15、K17/J17、G15/G16。这是DVI/TMDS视频，不含HDMI音频/EDID。细节见[显示事实](../board/DISPLAY.md)，整合须处理Y12用途、Bank5实际电气与时钟，不能拼两套CST或使用另一套未测映射。

首版程序绘制/字模可避免1080p全帧6.22MB缓存。FFT用全速PCM，正确加窗/定标，不能将未滤波抽取流作全频频谱；默认干声L=R，房间效果才可能提供真实立体声相图。蓝牙预留2–4根PMOD信号，电平/供电和确切模块尚未冻结；不用软核CPU代替显示/音频核心。

## 首轮工作

1. 独立复现彩条，用mock设计键区高亮、音量/踏板/音色和波形首屏；验证帧边界更新，生成可检查的图像或截图。
2. 先接精简状态，再接PCM；FFT独立用已知频率/幅值输入测试。状态序号回绕、坏/截断记录、PCM缺口和共同复位都有测试入口可参考。
3. 蓝牙先做参数/状态协议；PC/手机只作客户端，无线离线不影响本地演奏。通信测试覆盖分包、粘包、错误CRC/长度、重复增量命令、满队列与重连。
4. 脱机引导由FPGA自行计时/点灯，C定义逻辑key_id灯帧，B提供面板灯和物理驱动；手机实时点灯不代替脱机。事件记录也不等于PCM录音回传。

工作目录：[visual](../../project/visual/README.md)、[communication](../../project/communication/README.md)、[host](../../host/README.md)、[assets](../../assets/README.md)。提交独立顶层、测试/图像、IP配置、资源时序与待板测项；整合由A统一CST/顶层，无须先等控制板完工。旧角色说明已归为[历史快照](../history/ROLE_C_BEFORE_INTEGRATION_2026-09-29.txt)。

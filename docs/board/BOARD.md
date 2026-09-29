# 板卡事实与上板经验

原始资料入口：[references](../../references/README.md)。这里区分用户实物确认、资料/工程设置和未核对项。

| 项目 | 状态 |
|---|---|
| 套餐/底板 | 用户确认60K基础套餐，Tang Mega NEO Dock；接口位置与商品资料一致 |
| 核心板 | 散热固定件遮挡；未拆开独立读完整料号/版本。工程及JTAG按GW5AT-60B、PBGA484A、GW5AT-LV60PG484AC1/I0配置成功 |
| 实物PCB版本 | 未确认。不能把某PDF或iBOM版本直接认作实物版本 |
| 已有接口 | 3.5mm耳机、两个扬声器口、两组PMOD、ADC、DEBUG-USB2、12V DC及外屏资源；存在接口不等于全部验收 |
| 附件 | USB A–C线、USB-C母口转圆口12V PD触发头、两组8线分线配件、PMOD-LEDx8；线序不能凭颜色认定 |
| 外部输入 | 9月19日EC11模块已到；用户接3.3V/GND、A=T18、B=R17、C悬空，耳机板测确认双向、快慢旋转均稳定且每格一音高变化。C/按压用途仍未确认；4×4/FSR尚未记录到货 |
| 电源 | 用户140W充电器列有12V/3A档，配PD触发头；USB单线也能运行当前演示。额定140W不是强制向板卡灌入140W |
| 电池 | 未确认安装电池；Battery-Indicator亮/闪不证明有内置电池 |

## 下载与已有实测

DEBUG-USB2曾出现设备描述符错误/代码43，插着USB重启后恢复；Windows出现USB Serial Converter A/B，Programmer识别USB Debugger A，JTAG发现一个器件。之后SRAM下载、PMOD点灯和耳机发声均成功。当前验证采用SRAM，断电后不保证保留；不把Flash改写作为日常协作默认动作。

核心板POWER/READY/DONE是状态指示，不能当作任意用户LED。test工程的T18通过PMOD-LEDx8点亮L2；不插模块自然没有对应可见现象。PMOD是2×6，8个信号另加电源地；4×4的一排8针需按已确认线序分线，不能整排硬插。

## 音频已核对配置

50MHz时钟V22；PT8211 BCK=Y17、WS=AB17、DIN=AA16；PA_EN=AB16且0使能。四个音频输出按3.3V约束。见[instrument约束](../../project/instrument/src/instrument.cst)。现有发送器为16位二补码LSBJ，MSB先发、BCK上升沿采样；WS低右高左，每声道20时钟（4个前导0＋16数据），BCK=50MHz/26，Fs=50MHz/1040≈48076.923Hz。

图纸链路：PT8211→LMV321低通→NS4263→隔直电容→耳机。耳机插拔会改变放大器工作模式。左右当前数字内容相同；声道均衡不等于立体声效果已实现。

PR1014普通时钟路由警告仍存在；现有内部时序通过，但不等于完成外设引脚setup/hold验证。没有板图依据不能把V22随意改为另一全局时钟引脚。

## 使用资料时的边界

NEO Dock图纸、核心板图纸、全引脚CST、iBOM必须交叉核对。DK_START_GW5AT是另一块官方开发板，138K资料也不能直接套用。ADC通道与允许模拟输入范围未确认前，不把FSR分压直接接到“ADC”丝印口；数字GPIO的3.3V也不是ADC量程。

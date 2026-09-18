# PMOD点灯基线

最初Designer教学验证工程，顶层`test_top`，50MHz V22驱动分频，`led`约0.5秒翻转，输出在T18。用户已接PMOD-LEDx8确认L2闪烁；核心板POWER/READY/DONE不是本工程控制的用户灯。

用Gowin打开test.gprj，确认GW5AT-60B和顶层test_top，综合/布局布线后SRAM下载。保留CST与20ns时钟SDC。仍有PR1014警告，现有50MHz内部时序通过；未为这个简单原始工程额外添加仿真入口。

后续B分配GPIO时不能一边占用T18驱动其它设备，一边继续接LED诊断模块而不核对负载/接线。两排PMOD的电源地与方向以实物为准。

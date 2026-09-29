# C的显示模块

先读docs/board/DISPLAY.md。全引脚CST与图纸有差异且实物版本未确认，不复制猜测针位。可以持续做渲染/时序仿真，不必等待全部硬件问题才开始。

FPGA实现绘图/扫描/输出，不用软核替代；离线MATLAB/Python素材转换可用。新增IP交付配置、来源、仿真依赖和重建说明。

不要把音频所有内部端口引为芯片IO。多位跨域用一致性方案；显示可丢旧帧，不停音频。新集成用audio_core_v2及audio_integration，历史baseline meter占位不可用。V2提供真实PCM与峰值，干声L=R、房间效果才可能不同；示波图、频谱、李萨如必须写真实信号来源。UI目标见docs/team/C_HANDOFF_AND_DISPLAY_PLAN.md。

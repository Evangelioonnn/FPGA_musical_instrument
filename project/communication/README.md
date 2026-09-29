# 通信扩展工作区 · C

> C先读[交接与屏幕/蓝牙设计目标](../../docs/team/C_HANDOFF_AND_DISPLAY_PLAN.md)。当前交接分支是`codex/audio-integration-pack`，main尚未合入；本规划没有新增该目录RTL。

当前无蓝牙/UART实现；A已提供[音频接入包](../audio_integration/README.md)，包含真实命令/ACK跨域桥和完整状态记录。先读[C交接](../../docs/team/ROLE_C.md)、[音频V2](../../docs/interfaces/AUDIO_CORE_V2.md)和[传输契约](../../docs/interfaces/AUDIO_TRANSPORT_V1.md)。首轮交付模块比较和外部协议提案；协议确定后添加`src/`、`sim/`、`tools/`和独立验证顶层。

协议至少定义版本、帧同步/长度、序号、命令、字节序、校验、超时、ACK/错误、能力查询和状态读回。配置命令与音符事件分开；首版建议先调参/状态，不依赖无线进行主键盘演奏。没有冻结UART波特率、接头、电平或具体蓝牙芯片。

配置解码后通过接入包的`client_valid/ready`提交地址、值和事务tag，等待真实`reply`；不要在UART收到包时提前报告音频已经应用。重复无线包由协议层处理，桥不负责去重，尤其不能盲目重试音量增量等非幂等命令。46字状态记录是内部FPGA协议，不是必须原样透传手机的包；C可选择字段与发送频率。

仿真须覆盖坏包/重传、分包/粘包、非法参数、下游暂忙、溢出和断连。模拟字节源可先在无板电脑上工作。手机版或PC客户端放[host](../../host/README.md)，图片/曲谱素材放[assets](../../assets/README.md)并记录来源。

蓝牙模块处理无线栈；音频仍由FPGA逐样本生成。若提出“演奏录音回传”，明确是事件序列、音频PCM还是两者，估算实际无线带宽、存储与丢包策略后再承诺。

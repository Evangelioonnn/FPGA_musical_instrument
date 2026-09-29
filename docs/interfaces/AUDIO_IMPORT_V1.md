# 音频接入包的源码导入 V1

负责人A。此文档说明如何从仓库导入同一份音频RTL，不重新复制一套声音核心。
声音、参数及状态的语义分别见[音频V2](AUDIO_CORE_V2.md)、[继承的字段与单位](AUDIO_CORE_V1.md)和
[观测/命令传输V1](AUDIO_TRANSPORT_V1.md)。资源和时序结论以[当前团队预算](../team/RESOURCE_BUDGET_V1.md)为准。

## 源码清单

唯一清单为[source_manifest.json](../../project/audio_integration/tools/source_manifest.json)。
[source_manifest.py](../../project/audio_integration/tools/source_manifest.py)读取它，
生成相对路径Designer项目或[source_manifest.tcl](../../project/audio_integration/tools/source_manifest.tcl)。
Tcl清单是生成的副本；修改JSON后需重新生成，包检查会拒绝两者不一致。

| Profile | 文件数 | 默认逻辑顶层 | 用途 |
|---|---:|---|---|
| `core` | 20 | `audio_v2_core` | 五音色、32逻辑槽/12路Warm pluck、统一配置、效果、真实PCM与状态 |
| `transport` | 4 | `audio_snapshot_bridge` | 公共复位与状态、PCM、命令三条桥；不引入音频核心 |
| `integration` | 25 | `audio_integration_example` | 20份核心源码＋4份桥源码＋完整逻辑连接例子 |
| `consumer` | 6 | `audio_state_view` | 4份桥源码＋紧凑状态视图＋独立的合成观测mock |

核心的20份依赖来自现有`audio_v2.gprj`，包括条件分支里的状态/ADSR/原正弦表，
以保证不同工具能完整解析。没有导入旧板级顶层、其他同名bank候选、扫描器、DAC发送器、
CST、SDC或整份历史工程。声音RTL仍以其原目录为唯一来源；接入包引用它们，不保留分叉副本。

清单默认bank仍为`project/audio_core_v2/src/audio_v2_bank_stream.v`。
若总集成采用经过等价、资源及PnR验收的优化bank，可显式使用`--bank`或Tcl的第三个参数替换。
替换发生在唯一的`audio_v2_bank`位置，不能同时编译两份同名模块。
路径和替换机制可用不等于某个候选已经通过验收；采用哪份以接入包README及团队预算中的最终结果为准。

## 导入命令

在仓库根目录、已经打开的Gowin源代码工程内运行：

```tcl
source project/audio_integration/tools/import_audio.tcl
# 第三个参数省略时采用清单默认bank。
audio_import::apply core audio_v2_core

# 只取路径清单，供自己的构建脚本/仿真使用：
set audio_sources [audio_import::files integration]
```

将音频嵌入自己的顶层时，先添加自己的顶层文件，再将第二个参数设为自己的顶层名称。
`audio_import::apply`导入显式Verilog源文件并设置顶层，不创建工程、不设置器件、引脚或时钟。
同一工程执行一次即可；不要先导入整份旧GPRJ再重复导入这一清单。
仓库可以位于任意磁盘目录；脚本根据自身位置确定仓库根目录，不依赖A电脑的路径。

也可以先从仓库根目录生成一份仅含源码、使用相对路径的Designer项目：

```powershell
python project/audio_integration/tools/source_manifest.py --profile core --format json
python project/audio_integration/tools/source_manifest.py --profile integration --gprj tmp/imported_audio.gprj
python project/audio_integration/tools/source_manifest.py --write-tcl
```

生成的GPRJ使用本板`GW5AT-60B / GW5AT-LV60PG484AC1/I0`器件，但没有CST/SDC。
打开后须确认Top Module/Entity为命令报告的逻辑顶层。
`audio_v2_core`、`audio_integration_example`、`audio_state_view`和mock均是逻辑接口顶层；
它们暴露大量观察/参数端口，**不应直接布局布线或烧录**。实际板级顶层和统一约束由A集成，
原`audio_v2_top`/19 IO回退入口仍按其工程说明使用。

## B/C如何使用

[audio_integration_example.v](../../project/audio_integration/examples/audio_integration_example.v)
连接25个逻辑键、两个音区、host命令及ACK、ADC模拟扫描、状态桥和PCM桥。
这是可综合的连接示例，不是25键电气扫描器或ADC SPI驱动。
`keys/changed/ghost/all_released`、板载键/旋钮事件、ADC扫描都属于50MHz音频域；
跨域输入先适配成这个域的完整组，再交给核心。

`client_*`请求与`reply_*`响应属于`client_clk`域；客户端保持valid及完整payload到ready握手。
命令桥拥有唯一host端口，实际UART/蓝牙帧解析在C模块内完成。
主音量为无符号Q16、满幅65536；弯音为有符号每格0.25半音；自定义系数为Q8；
效果mix为Q8且上限128。参数合法范围见参数服务SPEC，ACK的applied只表示目标提交。

`state_*`和`pcm_*`属于`observer_clk`域。
状态每份46个64位字，PCM带真实sample_index及gap/session标志；两条观测链路的拥塞都不阻塞音频。
所有桥共用异步高有效`arst`，各域自行同步释放；单边独立复位不在此版本契约内。
`state_drops/pcm_drops/pcm_overflow/command_protocol_error`是音频域诊断，
不能直接在显示或客户端时钟域读取多位计数。状态记录word1已携带一致的状态drop计数，
PCM消费端用索引/gap检测缺口；其他额外诊断若要跨域也需显式适配。

共享常量在[audio_api_v2.vh](../../project/audio_integration/include/audio_api_v2.vh)，
包含固定音色ID `0/2/3/4/5`、参数地址、单位与状态记录位置。
ID1为历史原拨弦，不能重编号成新的第二音色。
常量头不改写现有producer；升级接口时须同时核对文档、头文件、生产者和测试。

## C的紧凑观察视图

[audio_state_view.v](../../project/audio_integration/examples/audio_state_view.v)是可选接收例子：
默认KEYS25，面向当前N32/PLUCK12/2368bit状态格式。
它只保留常用控制、电平、实体键位及逐声部occupied/held/gated/MIDI/preset，
不复制完整2368bit基础快照，也不保留所有token/包络/扩展参数。
若C需要FFT、逐声部包络、ADSR目标等，继续按传输契约解析对应字，不应把省略字段当成零状态。

解码器验证头部、版本、能力表、字序和末字位置；只有收到完整合法末字才原子提交`view_valid`。
截断、乱序、早结束、能力不符的记录不替换上一份视图，`malformed_records`记录拒收。
序号/源drop/音频stream-reset计数变化产生`view_gap`；新链路首份带`view_session_start`。
真正的视频渲染还需在帧边界采用完整视图，避免画面一半使用新状态、一半使用旧状态。

`keys`是实际输入快照，不等于某个occupied声部的held：满载拒收和自然衰减结束后，琴键仍可能按住。
空槽的note/preset可能保留旧值，UI必须先判断occupied。
不同声部可以有不同音色，不用当前selected_preset代替逐声部preset。

[audio_observer_mock.v](../../project/audio_integration/examples/audio_observer_mock.v)提供可预测的三角波PCM、
递增索引和循环按键/状态，用于C没有完整音频工程时启动显示消费者。
它只生成模拟观察数据，不验证真实声音、板卡音频输出或乐器功能；其逻辑端口也不能直接作为烧录顶层。

## 复现与证据边界

```powershell
python project/audio_integration/tools/package_check.py --static-only
python project/audio_integration/tools/package_check.py --modelsim-bin <本机ModelSim目录>
```

包检查验证清单与Tcl一致、无重复模块、在临时干净目录导出源码、四个逻辑顶层编译/展开，
以及紧凑消费者的原子提交/缺口/截断/乱序/复位和mock的独立三角波/状态期望。
生成的`tmp/audio_integration_package_check/result.json`记录源SHA256，
覆盖HDL、共享`.vh`、两份bench、manifest JSON/Python/Tcl、导入脚本、检查器及基线GPRJ，
并在运行结束检查所有依赖未改变。

三桥各自的CDC、压力、命令服务测试另见传输模块的runner和验证记录。
上述导出/仿真通过不是实际显示器、蓝牙、ADC、模拟延迟/SNR或整机PnR通过。
真实实体输入和输出仍需统一电气约束、预算、整机时序和板测。

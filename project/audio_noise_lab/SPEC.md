# audio_noise_lab 规格与验收边界

## 固定接口

| 信号 | FPGA 球号 | 说明 |
|---|---|---|
| `sys_clk` | V22 | 50 MHz，3.3 V |
| `matrix_col_n[3:0]` | AB22, AB21, Y22, Y21 | J8 列输入，内部上拉 |
| `matrix_row_n[3:0]` | AA20, AA21, AA19, AB20 | J8 行扫描，非选中行高阻 |
| `timbre_button_n` | Y12 | USER_BUTTON2，1.5 V、低有效 |
| `hp_bck/ws/din` | Y17, AB17, AA16 | PT8211 串行输出 |
| `pa_en` | AB16 | 保持既有 `0` |
| `status_led` | J16 | WS2812 数据 |

## 变体参数

- `GATE_UNUSED=0/1`：是否只给当前音色的声部发 `sample_ce`。`1` 的 RTL 等价已通过，但当前顶层 PnR 失败。
- `GAIN_SHIFT=0/1/2`：输出样本乘 1/2/4；使用 19 位有符号中间值和 ±32767/−32768 饱和。
- `OSR=1/2/4`：PT8211 帧率相对基线的倍数。合成侧 `render_ce` 仍为约 48.077 kHz；PT8211 BCK 半周期使用 13/OSR 的分数分频序列，避免整数截断改变平均采样率。

## 验收分层

1. RTL 仿真：独立 oracle 和 PASS 标志，检查事件、采样率、串行格式和算术边界。
2. Gowin 综合/PnR：必须有当前源码生成的 `.fs`、15 个 IO、setup/hold 违例为 0。
3. 板测：用户实际下载和试听，记录每个候选的主观结果。板测前不得把任何候选称为噪声修复。

当前没有做模拟采集，也没有把任何候选加入正式 `SYSTEM_V0` 或比赛顶层。

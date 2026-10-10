# 本轮上板验收

打开工程：`D:\uestc\SCM\GowinFPGA\project\looper_session_v2\looper_session_v2.gprj`。

Top必须为 **looper_session_top**，19 IO。固件为 `D:\uestc\SCM\GowinFPGA\project\looper_session_v2\impl\pnr\looper_session_v2.fs`；哈希见 `results/first_pnr/BUILD.json`及最终`results/BOARD_DELIVERY.json`。只SRAM下载，不写Flash。新固件的资格为独立音频测试，不含屏幕。

仍使用既有4×4矩阵、一个EC11 A/B和三板载用户键；不是新操控板6×6固件。旧[接线](../looper_refinement_lab/BOARD_TEST.md)保持：列AB22/AB21/Y22/Y21，行AA20/AA21/AA19/AB20；旋钮T18/R17；S1/S2/S3=AA13/AB13/Y12。当前EC11 C悬空、不调用按压。

## 这次先验什么

1. 重新SRAM下载后默认演奏页钢琴。短S1依次钢琴→Warm pluck→bell→Drive lead→自定义→鼓组→钢琴；**按5次到鼓组**。先抽查五旋律音色是否保持原效果。
2. 鼓组按下表逐个单击；对照电脑 `sim/audio/drum_kit.wav`（顺序见DRUM_SPEC）。重点反馈四筒由低到高是否顺、两个高筒是否够亮、军鼓是否保持、踩镲是否太响/太弱、两个吊镲是否更亮更长。
3. 开镲key6后立即闭镲key5，检查闭镲能压住开放尾音。有空槽先验，不用一次填满8槽；满池choke切换突变仍是已知边界。
4. key10/11/14/15应静音，且不引发故障快闪。拍手/边击暂留12/13，有意见单独反馈即可。
5. S3任意页长按约1秒切换全局节拍器。Looper未启动也应点击；再关掉点击，鼓与旋律仍可演奏。演奏页模式0下转旋钮调主音量，减到0应连点击一起静音。

| 行/列 | col0 | col1 | col2 | col3 |
|---|---|---|---|---|
| row0 | key0底鼓 | key1军鼓 | key2四筒 | key3三筒 |
| row1 | key4二筒 | key5闭镲 | key6开镲 | key7吊镲1 |
| row2 | key8吊镲2 | key9一筒 | key10禁用 | key11禁用 |
| row3 | key12拍手（暂留） | key13边击（暂留） | key14禁用 | key15禁用 |

## Looper只做少量回归

本地五页操作仍是原方案；没有新增更多盲按菜单。**S3短按换页：演奏→Looper→混音→节拍器→自定义→演奏。退出Looper页只换页，循环继续；停止要在Looper页短S1。**

需要回归时：先钢琴、S3一次到Looper、短S2启动一小节预备拍与录音，弹两个短音，提交后应重复。再短S1停止，允许自然尾音，无卡音；短S1恢复。鼓组可同样录一层。

撤销/清轨/分轨混音/表达编辑已做本轮数字接口验证，**实物综合验收留给你和C接显示后进行**，不用这次再靠记按键次数把所有项目盲验一遍。当前新C接口允许直接切页、选轨、录/停、undo/clear及调轨量；详见C_HANDOFF。后续25键/五推子实体板另做小范围输入适配与验收。

五旋律参考WAV是单槽干声、各文件明确固定试听增益；新鼓串用统一6倍增益保留相对电平，不能据电脑响度推断板上模拟电平。正式报告仍待模拟SNR/延迟、实体控制板和真实显示整合。旧refinement/V2文件没有覆盖，可以回退。

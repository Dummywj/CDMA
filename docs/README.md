# 项目文档索引

## 教程

- [CDMA 无线数据传输项目的时代背景](tutorial/background.md)：说明蜂窝通信的容量压力、模拟与数字通信和多址方式的区别，以及这些问题与当前链路训练的关系。
- [CDMA 无线数据传输项目的实现路线](tutorial/route.md)：说明从规范冻结、浮点链路到定点、RTL 和硬件验证的基本步骤。

## 设计决策

- [帧长度选择](decisions/01-frame-length.md)：规定三个帧的长度信息，避免和简化模型产生冲突。
- [基线载荷定义](decisions/02-baseline-payload.md)：将教学基线业务帧固定为 192 个业务位，无 CRC、无尾零，并说明 BER 扫描约定。

## 设计基线

- [浮点链路基线](design/baseline.md)：规定单径 AWGN、理想同步和单支路接收的第一版验证范围，模型与脚本位于 `matlab/baseline/`。
- [基线仿真参数与序列定义](design/baseline-param.md)：记录业务、同步与导频序列的生成方式，以及 Walsh 码、卷积码、功率分配和 I/Q 短 PN 的默认参数与复现样例。
- [基线仿真结果](design/baseline-results.md)：平铺 Simulink 模型的 BER 结果和验证边界，仿真产物位于 `matlab/results/baseline/`。

## 图示

- [CDMA 通信链路图](pic/cdma-link.svg)：展示项目的发端、无线信道、同步、两径 Rake 收端和验证路径。

## 参考材料

- [材料索引](../material/README.md)：按文档整理的 Markdown、原件和图片。

# MATLAB / Simulink 仿真

主模型为 [baseline.slx](baseline/baseline.slx)，所有链路模块平铺在顶层。

在项目根目录执行：

```matlab
addpath('matlab/baseline');
init_baseline;
open_system('baseline');
```

点击 Run 可运行默认 10 批数据，查看 BER 标量。需要 MATLAB R2025b、Simulink、Communications Toolbox；其他版本尚未验证。

```matlab
verify_baseline;
results = run_baseline(1000);
```

以上命令检查关键编码约定并运行噪声扫点。当前 v2 定义为每 20 ms 帧 192 个业务位，无 CRC、无尾零；四帧组成一个 80 ms 批次，每批 768 位，Rb=9600 bit/s。`results/baseline/` 保存 `ber.csv`、`ber.png`、`diagnostic.mat` 和 `model.png`。默认扫描 `-4:0.25:6`，每点 1000 批，另执行独立无噪声检查；零误码点记录为未观测到错误，不替换成 `0.5/N`。

- [基线设计与参数](../docs/design/baseline.md)
- [仿真结果](../docs/design/baseline-results.md)
- `baseline/init_baseline.m`：参数初始化。
- `baseline/baseline_step.m`：顶层模块同名算法分支；模型运行依赖此文件。
- `baseline/plot_baseline_ber.m`：只根据实测 BER 绘图，可独立重新生成曲线。
- `baseline/short_pn.m`：标准 I/Q 短 PN 序列。
- `baseline/build_baseline.m`：重新生成模型，会覆盖已保存的 baseline.slx；正常使用无需执行。
- `test/bit_mapping_demo.slx`：原有练习模型，未修改。

当前实现是 v2 教学业务、物理测试同步分支和连续导频的理想同步浮点基线，不包含同步捕获、Rake、长码扰码、功控和成形滤波。所有 `.m` 辅助文件需与模型保留在同一目录。

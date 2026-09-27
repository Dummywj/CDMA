# MATLAB / Simulink 仿真

主模型为 [baseline.slx](baseline/baseline.slx)，所有链路模块平铺在顶层。

在项目根目录执行：

```matlab
addpath('matlab/baseline');
init_baseline;
open_system('baseline');
```

点击 Run 可运行默认 10 批数据，查看当前批次 BER/FER。需要 MATLAB R2025b、Simulink、Communications Toolbox；其他版本尚未验证。

```matlab
verify_baseline;
results = run_baseline(100);
```

以上命令检查关键编码约定并运行噪声扫点。`results/baseline/` 保存统计表、曲线和单批中间数据。

- [基线设计与参数](../docs/design/baseline.md)
- [仿真结果](../docs/design/baseline-results.md)
- `baseline/init_baseline.m`：参数初始化。
- `baseline/baseline_step.m`：顶层模块同名算法分支；模型运行依赖此文件。
- `baseline/short_pn.m`：标准 I/Q 短 PN 序列。
- `baseline/build_baseline.m`：重新生成模型，会覆盖已保存的 baseline.slx；正常使用无需执行。
- `test/bit_mapping_demo.slx`：原有练习模型，未修改。

当前实现是 RC1 满速业务、物理测试同步分支和连续导频的理想同步浮点基线，不包含同步捕获、Rake、长码扰码、功控和成形滤波。所有 `.m` 辅助文件需与模型保留在同一目录。

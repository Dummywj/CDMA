# Step 3：在理想时钟下实现 PN 捕获（零基础版）

Step 2 已经证明：只要接收端的 PN 起点与发送端完全一致，就能正确解扩。

Step 3 只去掉一个理想条件：

```text
Step 2：接收端已知 PN 从哪一个 chip 开始
Step 3：接收端不知道 PN 起点，需要自己找
```

这个「找到 PN 起点」的过程就叫 **PN 捕获**。

---

## 1. 先说清本步做什么

本步的链路是：

```text
发送数据
-> PN 扩频
-> 人为加入一个未知的整数 chip 延迟
-> 接收端搜索 PN 起点
-> 将本地 PN 对齐
-> 用 Step 2 的方法解扩
-> 恢复数据
```

本步的输出有三个：

| 输出 | 简单含义 |
| --- | --- |
| `LOCK` | 是否确认已经找到 PN |
| `delayChips` | 收到的 PN 相对参考 PN 错开了多少个 chip |
| `alignedPN` | 已调整到正确起点的本地 PN |

---

## 2. 「理想时钟」不等于「起点已知」

这是本步最容易混淆的地方。

理想时钟只表示：

```text
发送端每个 chip 的时间 = 接收端每个 chip 的时间
```

本项目的码片率是 `1.2288 Mchip/s`，因此：

```text
一个 chip 的时间
= 1 / 1.2288e6
= 0.813802 us
```

发送端和接收端都认为一个 chip 持续 `0.813802 us`，且这个时间不会慢慢漂移。

但接收端仍然不知道：

```text
我现在收到的这个 chip，
对应 PN 周期中的第几个 chip？
```

这就是 Step 3 要解决的问题。

本步仍然不解决：

- 小于 1 chip 的分数延迟。
- 发送和接收时钟速度不一致。
- 运行过程中的连续漂移。
- 多径中的多个 PN 峰。

时钟漂移在 Step 5 处理，多径搜索在 Step 7 处理。

---

## 3. 什么是 PN 相位

这里的「相位」不是 QPSK 星座图上的角度，而是 **PN 序列的位置**。

假设一条 PN 是：

```text
参考 PN：[+1, +1, +1, -1, +1, -1, -1]
索引：       0   1   2   3   4   5   6
```

如果收到的数据从索引 2 对应的位置开始，我们就说它的 PN 相位或者 PN 偏移是 2 chip。

编程时必须冻结一个无歧义的约定。本教学约定：

```text
rx = circshift(referencePN, delayChips)
```

MATLAB 中正的 `delayChips` 表示数组向下或向后移动。后面搜索出来的结果也使用同一约定。

---

## 4. 用手算理解「相关」

捕获的基本办法是：

```text
把本地 PN 依次移动 0、1、2、... 个 chip，
每移动一次，就与收到的 PN 比较一次。
```

这种「逐个相乘，再全部相加」的比较叫相关。

使用前面的 7-chip PN，假设信道将它延迟了 2 chip：

```text
参考 PN：[+1, +1, +1, -1, +1, -1, -1]
收到 PN：[-1, -1, +1, +1, +1, -1, +1]
```

先用未移动的本地 PN 比较：

```text
逐个乘积：[-1, -1, +1, -1, +1, +1, -1]
全部相加：-1
```

再将本地 PN 移动 2 chip：

```text
本地 PN：[-1, -1, +1, +1, +1, -1, +1]
收到 PN：[-1, -1, +1, +1, +1, -1, +1]

逐个乘积：[+1, +1, +1, +1, +1, +1, +1]
全部相加：7
```

当偏移正确时，每一个 chip 都匹配，所以全部向同一方向累加，得到明显的大数。

当偏移错误时，一部分乘积是 `+1`，另一部分是 `-1`，会互相抵消。

---

## 5. 把所有候选位置都比较一次

对前面的 7-chip 例子，把本地 PN 依次移动 0 到 6 chip，得到：

| 候选偏移 | 0 | 1 | 2 | 3 | 4 | 5 | 6 |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| 相关结果 | -1 | -1 | 7 | -1 | -1 | -1 | -1 |

最大值出现在偏移 2，因此：

```text
估计的 PN 延迟 = 2 chip
```

把每个候选偏移的比较结果画成图，会看到偏移 2 处有一根明显高出来的柱子。这根柱子通常叫「相关峰」。

---

## 6. 为什么要看幅度平方

真实接收数据可以是复数，而且可能因为数据正负号或信道方向产生旋转。所以不能只找「最大的正数」。

对每个候选偏移 `tau` 计算：

```text
C[tau] = 对应 chip 相乘后的累加结果
M[tau] = |C[tau]|^2
```

`|C|` 表示复数的大小，`M` 就是用来比较的非负数分数。

最后选择：

```text
delayHat = 使 M[tau] 最大的 tau
```

`delayHat` 是接收机估计出来的 PN 延迟。

---

## 7. 本步的已知量和未知量

| 类别 | Step 3 中的情况 |
| --- | --- |
| 码片率 | 已知，`1.2288 Mchip/s` |
| 每个 chip 的采样时刻 | 已知，理想时钟 |
| PN 生成规则 | 已知 |
| PN 当前起点 | 未知，需要搜索 |
| 信道路径 | 只有一条 |
| 路径延迟 | 未知，但只考虑整数 chip |
| 帧起点 | 本步不搜索 |
| Walsh 信道 | 本步不加入 |
| 时钟频差 | 0 |
| 多径 | 本步不加入 |

---

## 8. 教学 PN 和最终 IS-95 短码

Step 2 使用的 31-chip PN 是教学码。它的好处是：

- 只有 31 个候选位置，容易穷举。
- 可以快速检查每一个偏移。
- 出错时可以直接打印全部结果。

在 `1.2288 Mchip/s` 下，31 chip 持续：

```text
31 / 1.2288e6 = 25.228 us
```

最终 IS-95 短码的周期是 32768 chip，持续：

```text
32768 / 1.2288e6 = 26.6667 ms
```

因此切换到最终短码时，接收端需要在 32768 个可能的整数 chip 位置中搜索。

但要特别注意：

```text
32768 是 PN 序列的周期，
不是一个信息 bit 对应的 chip 数。
```

最终的 PN-I、PN-Q 多项式、初态、移位方向和补零规则必须以课程规范和参考向量为准。不能把 31-chip 教学码直接改名为 IS-95 短码。

---

## 9. 为什么先用一段已知数据

如果发送的数据在搜索期间不断变号，它可能让本来应该累加的 PN 相关结果互相抵消。

所以初版捕获器先使用一段已知的训练数据，例如连续发送固定符号 `+1`：

```text
已知训练符号 -> 乘 PN -> 接收机搜索
```

这个训练段只是 Step 3 的仿真工具，不是 Step 4 将要加入的完整导频逻辑信道。

如果训练符号是一个固定的复数 `a`，正确偏移处的结果会变成 `a` 乘以一个大数。虽然方向可能改变，但幅度仍然很大，所以使用 `|C|^2` 仍能找到正确峰值。

---

## 10. 第一个 MATLAB 捕获实验

先使用前面手算过的 7-chip PN：

```matlab
clear; clc; close all;

referencePN = [1; 1; 1; -1; 1; -1; -1];
trueDelay = 2;

% 仿真注入 2 chip 的循环偏移。
rx = circshift(referencePN, trueDelay);

nPhases = numel(referencePN);
correlation = zeros(nPhases, 1);
metric = zeros(nPhases, 1);

for tau = 0:nPhases-1
    candidatePN = circshift(referencePN, tau);
    correlation(tau + 1) = sum(rx .* candidatePN);
    metric(tau + 1) = abs(correlation(tau + 1))^2;
end

[peakValue, peakIndex] = max(metric);
estimatedDelay = peakIndex - 1;

disp(correlation.');
disp(metric.');
fprintf('True delay      = %d chip\n', trueDelay);
fprintf('Estimated delay = %d chip\n', estimatedDelay);

stem(0:nPhases-1, metric, 'filled');
grid on;
xlabel('Candidate PN delay (chip)');
ylabel('Correlation magnitude squared');
title('PN acquisition metric');
```

预期结果是：

```text
correlation = [-1, -1, 7, -1, -1, -1, -1]
metric      = [ 1,  1,49,  1,  1,  1,  1]
estimatedDelay = 2 chip
```

这段代码不是通过偷看 `trueDelay` 得到答案。`trueDelay` 只负责生成测试数据，捕获器只能看到 `rx` 和 `referencePN`。

### 10.1 `circshift` 只是单元测试工具

`circshift` 会把数组末尾的数据绕回开头，很适合测试周期 PN 的所有相位。

真实传播延迟不会把末尾数据绕回开头。后续处理连续数据流时，应使用接收缓存区、读地址或本地 PN 的加载相位完成对齐，而不是将真实数据循环移动。

---

## 11. 将搜索写成独立函数

```matlab
function result = acquire_pn(rxBlock, referencePN)
    rxBlock = rxBlock(:);
    referencePN = referencePN(:);

    if numel(rxBlock) ~= numel(referencePN)
        error('rxBlock and referencePN must have equal lengths.');
    end

    nPhases = numel(referencePN);
    metric = zeros(nPhases, 1);

    for tau = 0:nPhases-1
        candidatePN = circshift(referencePN, tau);
        c = sum(rxBlock .* conj(candidatePN));
        metric(tau + 1) = abs(c)^2;
    end

    [peakValue, peakIndex] = max(metric);
    floorValue = median(metric);

    result.delayChips = peakIndex - 1;
    result.peakValue = peakValue;
    result.floorValue = floorValue;
    result.peakToFloor = peakValue / max(floorValue, eps);
    result.metric = metric;
end
```

这个函数的输入是：

| 输入 | 含义 |
| --- | --- |
| `rxBlock` | 收到的一段 PN 数据 |
| `referencePN` | 从约定零相位开始的本地 PN |

输出 `result.delayChips` 是最可能的偏移，`result.metric` 保存所有候选位置的分数。

`peakToFloor` 表示最高峰相对一般背景有多突出：

```text
peakToFloor = 最高峰 / 所有分数的中位数
```

中位数是把所有分数排序后处在中间的数。它比平均值更不容易被最高峰拉高。

---

## 12. 先穷举所有 PN 相位

捕获器不能只在一个延迟上正确。使用教学用 31-chip PN，依次注入 0 到 30 chip 的所有偏移：

```matlab
nPhases = numel(referencePN);

for trueDelay = 0:nPhases-1
    rx = circshift(referencePN, trueDelay);
    result = acquire_pn(rx, referencePN);

    assert(result.delayChips == trueDelay, ...
        'Acquisition failed at delay %d.', trueDelay);
end

disp('All PN phases passed.');
```

这是 Step 3 最重要的无噪声测试。只在偏移 0 上测试通过，不能证明捕获器正确。

---

## 13. 从实 PN 切换到复 PN

Step 2 已经构造了复 PN：

```text
complexPN = (PN-I + j * PN-Q) / sqrt(2)
```

捕获函数不需要改变搜索方法，只需要保证相乘时使用候选 PN 的共轭：

```matlab
c = sum(rxBlock .* conj(candidatePN));
metric = abs(c)^2;
```

测试时可以使用一个固定的已知复符号：

```matlab
trainingSymbol = (1 + 1j) / sqrt(2);
trueDelay = 9;

rx = trainingSymbol * circshift(complexPN, trueDelay);
result = acquire_pn(rx, complexPN);

assert(result.delayChips == trueDelay);
```

这里 `trainingSymbol` 会让相关结果发生旋转，但 `abs(c)^2` 不会因为旋转而改变峰值位置。

---

## 14. 加入噪声后，不能只取最大值

即使输入里只有噪声，在所有候选分数中也一定能找到一个「最大值」。如果看到最大值就输出 `LOCK=1`，接收机会经常在纯噪声下误判。

所以需要再问一个问题：

```text
最高峰是否比普通背景高得足够明显？
```

一个简单指标是：

```text
peakToFloor = 最高峰 / 背景中位数
```

然后判断：

```matlab
threshold = 8;  % 只是起始调试值，不是 IS-95 标准门限
hasCandidate = result.peakToFloor > threshold;
```

`8` 只用于开始调试。最终门限必须通过大量「有信号」和「只有噪声」实验确定，不能把示例数字直接写进最终规范。

---

## 15. 为什么还要连续确认

某一块噪声可能偶然出现一个高峰。为了减少误判，第一次找到候选位置后，不要立即输出 `LOCK`，而是再检查后面几块数据。

在本步的理想时钟下，真实 PN 峰应该一直留在同一个 chip 位置。

可以使用以下规则：

```text
第 1 块：找到候选峰
第 2 块：峰仍在同一位置
第 3 块：峰仍在同一位置
三块都超过门限：输出 LOCK
```

如果任意一块失败，就回到搜索状态。

---

## 16. 用状态机组织捕获流程

状态机可以理解为「接收机当前正在做哪件事」。

```text
IDLE -> SEARCH -> VERIFY -> LOCK
          ^          |
          +--失败---+
```

| 状态 | 简单含义 |
| --- | --- |
| `IDLE` | 还没有开始 |
| `SEARCH` | 搜索所有候选 PN 相位 |
| `VERIFY` | 连续几块确认候选峰不是偶然噪声 |
| `LOCK` | 确认已捕获，将 PN 相位交给解扩器 |

Step 3 中进入 `LOCK` 后，可以一直保持该相位，因为本步假设没有时钟漂移。Step 5 加入时钟频差后，才需要在 `LOCK` 之后持续跟踪。

---

## 17. 数据符号会变时怎么办

最简单方法是使用已知训练段。如果必须在多个会变号的短数据块上捕获，不要先将复相关结果直接相加，否则不同块可能互相抵消。

可以对每个短块先计算幅度平方，再将分数相加：

```text
第 m 块在偏移 tau 的相关结果：C_m[tau]

总分数：
M[tau] = |C_1[tau]|^2 + |C_2[tau]|^2 + ...
```

这种方法的人话解释是：

```text
先看每一块在某个位置有多像，
再把各块的「像似程度」加起来。
```

这种先取幅度平方再累加的方法常叫「非相干累加」。名字可以后记，先理解操作顺序。

---

## 18. 捕获后怎样交给 Step 2 解扩

假设捕获器输出：

```text
delayHat = 9 chip
```

这表示接收 PN 相对参考 PN 向后移动了 9 chip。最直接的向量测试方法是生成同样偏移的本地 PN：

```matlab
alignedLocalPN = circshift(referencePN, result.delayChips);
despreadChips = rxData .* conj(alignedLocalPN);
```

然后按 Step 2 已经验证的规则，将每个符号对应的 chip 累加。

对连续数据流来说，不应每次都对整个数组调用 `circshift`。更合理的实现是：

```text
捕获器输出 delayHat
-> 在统一的时钟边界将本地 PN 发生器装载到对应相位
-> 之后本地 PN 每个 chip 正常前进
```

捕获器只负责告诉本地 PN 发生器「应该从哪里开始」，不会改变业务数据的内容。

---

## 19. 三种延迟不能混在一起

| 名字 | 它来自哪里 |
| --- | --- |
| 传播延迟 | 信号从发送端到接收端所用的时间 |
| 峰值索引 | 相关图上最高峰的数组位置 |
| 程序或硬件延迟 | 缓存、累加器和流水线造成的固定延迟 |

在前面的 MATLAB 向量单元测试中，我们人为约定：

```text
程序延迟 = 0
峰值索引 - 1 = 注入的循环偏移
```

后续加入流水线或 RTL（寄存器传输级硬件代码）后，必须用无噪声固定向量测出相关器的固定延迟，并在公式中明确减掉。不能通过手工删掉几个数据，直到 BER 变成 0 来完成对齐。

---

## 20. 在噪声中怎样测试

捕获实验先使用「每个复 chip 样值的 SNR」加噪，不要在这个实验中混用 Step 1 的 `Eb/N0` 标签。

SNR 在这里表示：

```text
SNR = 训练 chip 平均功率 / 噪声平均功率
```

MATLAB 示例：

```matlab
snrDb = -8;
snrLinear = 10^(snrDb/10);

cleanRx = trainingSymbol * circshift(complexPN, trueDelay);
signalPower = mean(abs(cleanRx).^2);
noisePower = signalPower / snrLinear;

noise = sqrt(noisePower/2) * ...
    (randn(size(cleanRx)) + 1j*randn(size(cleanRx)));

rx = cleanRx + noise;
result = acquire_pn(rx, complexPN);
```

固定随机种子可以重现一次实验，但捕获性能不能只用一次噪声结果下结论。每个 SNR 点需要运行很多次独立实验。

---

## 21. 两个必须统计的指标

### 21.1 正确捕获概率

发送信号存在时，捕获器既输出 `LOCK`，又找到正确偏移，才算一次正确捕获。

```text
Pd = 正确捕获次数 / 有信号实验总次数
```

`Pd` 可以理解为「有信号时，接收机成功找到它的百分比」。

### 21.2 虚警概率

输入中只有噪声，捕获器却输出 `LOCK`，就是一次虚警。

```text
Pfa = 纯噪声下错误 LOCK 次数 / 纯噪声实验总次数
```

`Pfa` 可以理解为「没有信号时，接收机误以为找到信号的百分比」。

调高门限通常会减少虚警，但也可能错过弱信号。降低门限则相反。因此门限是在 `Pd` 和 `Pfa` 之间取舍，而不是越高越好。

---

## 22. 捕获时间怎样理解

对教学用 31-chip PN，搜索空间是 31 个整数 chip 相位。对最终 IS-95 短码，搜索空间是 32768 个相位。

但「一个 PN 周期为 26.6667 ms」不等于「捕获一定只需 26.6667 ms」。

捕获时间还取决于怎样计算所有候选位置：

| 方法 | 简单理解 | 特点 |
| --- | --- | --- |
| 串行搜索 | 一次只试一个偏移 | 结构简单，最坏要试完所有位置 |
| 并行相关 | 同时或批量计算多个偏移 | 速度快，计算和存储量更大 |
| 快速傅里叶变换（FFT）循环相关 | 用快速算法一次得到所有偏移 | 适合软件加速，但必须先与直接搜索对比 |

本步先实现最容易验证的直接穷举。如果后面加入 FFT 版本，它必须在同一固定输入上输出同样的峰值索引和分数。

---

## 23. 推荐实验顺序

### 实验 1：7-chip 手算和程序对比

使用本文的 7-chip 固定向量和 2-chip 偏移。确认程序输出的相关结果与手算完全一致。

### 实验 2：31 个相位无噪声穷举

对 Step 2 教学 PN 注入 `0:30` 的所有偏移，要求每个偏移都返回正确值。

### 实验 3：复 PN 无噪声穷举

将 PN-I 和 PN-Q 合成复 PN，使用固定已知复符号，再次穷举所有偏移。

### 实验 4：画出有噪声相关图

选择一个固定偏移，分别在高 SNR 和低 SNR 下画出 `metric` 曲线，观察峰值如何逐渐被噪声淹没。

### 实验 5：门限扫描

在多个 SNR 下，分别尝试多个 `peakToFloor` 门限，统计 `Pd` 和 `Pfa`。保存选择门限的依据。

### 实验 6：连续确认

要求连续 3 块在同一位置超过门限后才输出 `LOCK`。注入一块偶然高峰，确认不会立即误锁定。

### 实验 7：接回 Step 2

先注入未知 PN 偏移，再运行捕获，最后用估计相位解扩。无噪声 BER 必须恢复为 0，AWGN BER 应恢复到 Step 2 的理想同步基线。

### 实验 8：切换标准短码

只有在获得课程指定的 IS-95 PN-I/PN-Q 参考向量后，才将 31-chip 教学码替换为最终短码。替换后首先验证参考向量，再测试捕获。

---

## 24. 推荐程序结构

```text
simulation/step3/
  run_step3.m
  acquire_pn.m
  build_complex_pn.m
  test_hand_example.m
  test_all_phases.m
  test_noise_only.m
  test_detection_probability.m
  test_step2_regression.m
  out/
    hand_example_metric.png
    acquisition_metric_high_snr.png
    acquisition_metric_low_snr.png
    pd_pfa_vs_threshold.png
    acquisition_results.mat
```

继续复用 Step 2 已验证的 PN 生成、复 PN 组合和解扩模块。不要在 Step 3 内另写一套初态或映射不同的 PN 发生器。

---

## 25. 验收清单

| 项目 | 通过条件 |
| --- | --- |
| 手算例子 | 7-chip 例子的峰值在 2 chip，手算与程序一致 |
| 所有相位 | 31-chip 教学 PN 的 `0:30` 偏移全部返回正确值 |
| 无噪声误差 | `estimatedDelay == trueDelay` |
| 复 PN | 相关时使用 `conj(candidatePN)` |
| 门限 | 通过 `Pd/Pfa` 实验选择，不把示例值当成标准值 |
| 确认 | 连续若干块稳定后才输出 `LOCK` |
| 纯噪声 | 统计并报告虚警概率 `Pfa` |
| 有信号 | 统计并报告不同 SNR 下的正确捕获概率 `Pd` |
| 捕获时间 | 报告平均和最坏搜索时间，说明搜索结构 |
| Step 2 回归 | 捕获后无噪声 BER 为 0，AWGN BER 恢复 Step 2 基线 |
| 步骤边界 | 不加 Walsh、时钟漂移、分数 chip 跟踪或多径路径搜索器 |

---

## 26. 最容易出错的地方

| 现象 | 可能原因 | 先怎样查 |
| --- | --- | --- |
| 估计偏移总差 1 chip | MATLAB 索引从 1 开始，但延迟从 0 开始 | 检查 `delay = peakIndex - 1` |
| 估计结果等于 `N-delay` | `circshift` 方向和搜索约定相反 | 用 7-chip、2-chip 手算例子固定符号约定 |
| 实 PN 正确，复 PN 失败 | 相关时忘记共轭 | 检查 `rx .* conj(candidatePN)` |
| 无噪声也没有明显峰 | 参考 PN 和发送 PN 不是同一定义 | 先逐 chip 比较零相位参考向量 |
| 有信号却经常不锁定 | 门限过高或累加长度过短 | 画出不同 SNR 下的峰值和背景 |
| 纯噪声经常锁定 | 门限过低或没有连续确认 | 独立运行纯噪声试验统计 `Pfa` |
| 单块正确，多数据块反而变差 | 不同数据符号的复相关结果互相抵消 | 使用已知训练段，或先取 `abs(c)^2` 再跨块累加 |
| 捕获成功但 BER 仍接近 0.5 | 捕获索引没有正确装载到本地 PN，或数据边界错位 | 打印捕获后前 31 个收发 PN 逐 chip 对比 |
| 软件结果对，RTL 差固定 chip | 相关器累加和流水延迟未标定 | 用无噪声固定向量测量固定偏置 |

---

## 27. 本步应保存的结果

1. PN 参数快照和零相位参考向量。
2. 7-chip 手算例子与程序结果。
3. 31 个注入相位的无噪声回归报告。
4. 高、低 SNR 下的相关峰图。
5. 不同门限下的 `Pd` 和 `Pfa` 统计。
6. 平均和最坏捕获时间。
7. 捕获后 Step 2 的 BER 回归结果。

---

## 28. 下一步会加入什么

Step 3 完成后，接收机已能在理想时钟、单路径下找到 PN 起点，并恢复 Step 2 的数据。

Step 4 将加入：

```text
导频信道
同步信道
业务信道
64-chip Walsh 码
三路功率分配与合路
帧同步
```

此时 Walsh 码负责区分三条逻辑信道，PN 短码仍然负责 I/Q 扩频和 PN 相位基准。两者不是同一种码，也不互相替代。

---

## 29. 最后只记住这六句话

1. 理想时钟只表示 chip 速度一致，不表示 PN 起点已知。
2. PN 捕获就是将本地 PN 逐 chip 移动，找到相关峰。
3. 复 PN 相关必须使用候选 PN 的共轭。
4. 最大值永远存在，因此还需要门限和连续确认才能输出 `LOCK`。
5. 捕获后要将估计相位正确装载到本地 PN，再回到 Step 2 解扩。
6. Step 3 只找固定的整数 chip 偏移；时钟漂移和多径分别留给 Step 5 和 Step 7。

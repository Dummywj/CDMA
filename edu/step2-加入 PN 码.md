# Step 2：加入 PN 码，形成单路直接序列扩频链路

本文对应《老师十步法：CDMA 无线数据传输链路设计与实现教学》的第二步。它在 Step 1 的 QPSK + AWGN 基础链路中加入 PN 扩频和理想同步解扩：

```text
随机比特
  -> QPSK 调制
  -> PN 扩频
  -> 理想/AWGN 信道
  -> 同相 PN 解扩
  -> QPSK 解调
  -> BER 统计
```

这一步只解决「PN 码怎样产生、符号怎样变成码片、怎样解扩、能量怎样守恒、数据怎样对齐」。接收端仍然完全知道 PN 的起始相位和码片时钟；PN 捕获属于 Step 3，不在本步实现。

---

## 1. 本阶段目标

Step 2 需要完成以下目标：

| 目标 | 说明 |
| --- | --- |
| 生成可重现的 PN 序列 | 固定递推式、初态、输出位和零相位 |
| 验证 PN 性质 | 检查周期、0/1 数量和周期自相关 |
| 实现复 PN 扩频 | QPSK 符号扩展为 `L` 个复码片 |
| 实现共轭解扩 | 对每组 `L` 个码片相关积分 |
| 统一能量口径 | 使每个扩频符号的总能量等于扩频前符号能量 |
| 对齐 Step 1 基线 | 在相同 `Eb/N0` 下，扩频链路 BER 应与 QPSK 基线一致 |
| 理解处理增益 | 区分固定 `Eb/N0` 和固定 chip SNR 两种实验 |

完成本阶段后，你应该能够回答：

1. PN 序列为什么「看起来随机，但可以完全重现」。
2. QPSK 符号如何被扩展为 `L` 个 chip。
3. 复 PN 解扩为什么必须乘以 PN 的共轭。
4. 为什么公平的纯 AWGN 对比中，扩频不会凭空改善 BER。
5. PN 相位错一个 chip 时，解扩结果为什么会严重恶化。

---

## 2. 本步的边界与继承关系

### 2.1 从 Step 1 直接复用的模块

| Step 1 模块 | Step 2 中的处理 |
| --- | --- |
| 随机比特源 | 原样复用 |
| Gray QPSK 调制 | 原样复用，仍令 `Es = 1` |
| AWGN 模型 | 保留 `Eb/N0 -> N0` 的定义，但噪声加在 chip 上 |
| QPSK 硬判决 | 对解扩后的符号判决 |
| BER 统计 | 原样复用，比较同一原始索引的比特 |
| QPSK 理论 BER | 作为 Step 1/Step 2 共同基线 |

### 2.2 本步新增的模块

```text
pn_generate
complex_pn_build
pn_spread
pn_despread
pn_autocorrelation_test
energy_consistency_test
```

### 2.3 本步明确不做的事

- 不搜索 PN 相位，收发两端从同一零相位开始。
- 不加入收发时钟频差或采样误差。
- 不加入 Walsh 码和多逻辑信道。
- 不加入多径、Rake、FEC、交织和定点化。
- 不将教学用短 m 序列冒充为 IS-95 I/Q 短码。

只有先在理想同步条件下证明扩频和解扩正确，Step 3 的 PN 捕获失败时才能确定错误在「同步」，而不是在基本数据通路。

---

## 3. bit、symbol 和 chip

这三个时间单位必须分清：

| 单位 | 本步含义 | 数量关系 |
| --- | --- | --- |
| bit | QPSK 调制器的输入 | 2 bit/符号 |
| symbol | 一个复 QPSK 点 | `Nbits/2` |
| chip | PN 扩频后的高速样值 | `L` chip/符号 |

若有 `Nbits` 个比特，QPSK 每符号携带 2 bit，扩频因子为 `L`，则：

```text
Nsymbols = Nbits / 2
Nchips   = Nsymbols * L
```

例如 `Nbits = 2000`、`L = 31`：

```text
Nsymbols = 1000
Nchips   = 31000
```

扩频增加了每个数据符号的样值数和占用带宽，但没有增加原始信息量。

---

## 4. PN 序列与 LFSR

### 4.1 PN 是什么

PN 是 pseudo-noise，即伪噪声序列。它具有三个同时存在的特点：

1. 在时域上看起来像随机的 0/1 序列。
2. 它由确定性的逻辑递推生成。
3. 只要生成规则和初始状态相同，收发两端就能产生完全相同的序列。

PN 序列不是加密随机数。在本项目中，它用于扩频和相关同步。

### 4.2 先用明确递推式，避免抽头约定混乱

教学阶段使用 5 级 m 序列，对应多项式：

```text
g(x) = x^5 + x^2 + 1
```

本文不只写「抽头是 5 和 2」，而是直接冻结为无歧义的递推式：

```text
s[n+5] = s[n+2] XOR s[n]
```

以下定义也必须一起冻结：

| 项目 | 本文约定 |
| --- | --- |
| 状态排列 | `[s[n], s[n+1], s[n+2], s[n+3], s[n+4]]` |
| 输出位 | 当前状态的第 1 位 `s[n]` |
| 新输入位 | `s[n] XOR s[n+2]` |
| 移位方向 | 删除第 1 位，新位加到末尾 |
| PN-I 初态 | `[1 1 1 1 1]` |
| PN-Q 初态 | `[1 0 1 0 1]` |
| 全零态 | 禁止 |
| 周期 | `2^5 - 1 = 31` chip |
| 零相位 | 装载指定初态后输出的第 1 个 chip |

全零状态会永远停留在全零，因此不能作为 LFSR 初态。

### 4.3 0/1 到双极性码片的映射

LFSR 输出是 0/1，乘法扩频需要 `+1/-1`。本文固定：

```text
p[n] = 1 - 2*c[n]
```

因此：

| LFSR bit `c[n]` | 双极性 chip `p[n]` |
| --- | --- |
| 0 | +1 |
| 1 | -1 |

使用相反映射未必会让自环链误码，但会让你无法和他人的中间测试向量逐 chip 对比，所以必须明文记录。

### 4.4 为什么先用 31 chip，不直接写 IS-95 短码

31 chip 序列可以快速穷举所有状态、手工检查前若干 chip，也能很快绘制完整的周期自相关。它的作用是验证 LFSR 和扩频通路，不是代替最终标准码。

切换到 IS-95 I/Q 短码时，必须从课程指定标准或老师提供的测试向量冻结：

```text
多项式
移位方向
输出抽头
初始状态
零插入规则
I/Q 码的组合方式
前若干百个 chip 的参考向量
```

「自相关有主峰」只能证明你生成了某种 PN 序列，不能证明它就是指定的 IS-95 短码。

---

## 5. PN 序列的单元测试

不要把 PN 发生器直接接入整条链路后才检查。先完成以下独立测试。

### 5.1 固定向量测试

保存 PN-I 和 PN-Q 的前 31 个 0/1 输出作为本项目的黄金向量。以后修改代码时，必须逐 chip 比较，而不是只看波形大致相似。

### 5.2 周期测试

对于本文的 5 级本原 LFSR：

1. 前 31 个非零状态不应重复。
2. 生成 31 chip 后，状态应回到初态。
3. 第 32 个输出应等于第 1 个输出。

### 5.3 平衡性测试

长度 31 的 m 序列在一个周期内，1 的个数和 0 的个数相差 1。这是健全性检查，不能代替参考向量测试。

### 5.4 周期自相关测试

对双极性 PN `p[n]` 定义归一化周期自相关：

```text
Rpp[tau] = (1/N) * sum(p[n] * p[(n+tau) mod N])
```

对长度 `N = 31` 的 m 序列，预期：

```text
Rpp[0]   = 1
Rpp[tau] = -1/31, tau != 0
```

这个特性说明正确相位的相关值很大，错误相位的相关值很小，它是 Step 3 做 PN 捕获的基础。

---

## 6. 从 QPSK 符号构造复 PN 码

### 6.1 实 PN 扩频

若输入是实 BPSK 符号 `a[k]`，可以使用实双极性 PN `p[n]`：

```text
x[kL+l] = a[k] * p[kL+l] / sqrt(L)
```

### 6.2 复 PN 扩频

Step 1 的输出是复 QPSK 符号，本步使用两条双极性序列构造单位模复 PN：

```text
pc[n] = (pI[n] + j*pQ[n]) / sqrt(2)
```

因为 `pI[n]` 和 `pQ[n]` 只能取 `+1/-1`，所以：

```text
|pc[n]|^2 = (pI[n]^2 + pQ[n]^2) / 2 = 1
```

扩频信号定义为：

```text
x[n] = a[floor(n/L)] * pc[n] / sqrt(L)
```

实现时，先将每个 QPSK 符号重复 `L` 次，再逐 chip 乘以复 PN。「重复」只是用来产生与 PN 等长的符号序列；真正的扩频操作是乘 PN。

### 6.3 一个符号的直观例子

设：

```text
a[0] = (1+j)/sqrt(2)
L = 4
pc = [1, j, -1, -j]
```

则能量守恒的扩频结果为：

```text
x = a[0] * pc / sqrt(4)
```

每个 chip 的幅度只是原符号的 `1/sqrt(L)`，但 `L` 个 chip 的总能量不变。

---

## 7. 能量守恒归一化

### 7.1 本项目的统一规则

Step 1 中 QPSK 平均符号能量为：

```text
Es = E{|a[k]|^2} = 1
```

本步对扩频信号除以 `sqrt(L)`。对任意符号 `a[k]`：

```text
sum(|x[kL+l]|^2, l=0...L-1)
= sum(|a[k]|^2 * |pc[kL+l]|^2 / L)
= |a[k]|^2
```

因此：

| 量 | 预期值 |
| --- | --- |
| 扩频前平均符号能量 | 1 |
| 扩频后平均 chip 能量 | `1/L` |
| 每个符号对应的 `L` chip 总能量 | 1 |
| QPSK 每比特能量 `Eb` | `Es/2 = 1/2` |

### 7.2 另一种规则为什么不能混用

另一种常见实现让每个 chip 幅度保持为 1，解扩时再除以 `L`。它也能正确恢复符号，但此时一个符号的总发射能量增加为 `L` 倍。

两种方法都可用，但不能在扩频、加噪和解扩三处混用两套口径。本教学后续统一使用能量守恒规则。

---

## 8. 理想同步解扩

### 8.1 解扩公式

接收端使用与发送端完全同相的复 PN：

```text
z[k] = sum(r[kL+l] * conj(pc[kL+l]), l=0...L-1) / sqrt(L)
```

在无噪声时，`r = x`：

```text
z[k]
= sum(a[k] * pc * conj(pc) / sqrt(L)) / sqrt(L)
= a[k] * sum(|pc|^2) / L
= a[k]
```

因此解扩输出应在数值精度范围内等于原 QPSK 符号。

### 8.2 为什么必须用共轭

对复数 `pc`：

```text
pc * conj(pc) = |pc|^2 = 1
```

如果误写成 `pc * pc`，结果不再恒等于 1，I/Q 分量会产生相位旋转、符号翻转或相互抵消。只有实值 `+1/-1` PN 时，`p = conj(p)`，这个错误才可能被掩盖。

### 8.3 本步的「理想同步」是什么

理想同步意味着：

```text
接收端第 1 个解扩 chip
= 发送端第 1 个扩频 chip
= 两端 PN 零相位的第 1 个 chip
```

接收端不搜索这个起点，而是由仿真器直接提供。可以主动将接收 PN 循环移位 1 chip 作为反例实验，但不能在本步写搜索器去自动修正它。

---

## 9. AWGN 与 `Eb/N0` 口径

### 9.1 公平的 Step 1/Step 2 对比

QPSK 符号仍然满足：

```text
Es = 1
Eb = Es / 2 = 0.5
gamma_b = 10^(EbN0_dB/10)
N0 = Eb / gamma_b
```

对扩频后的每个复 chip 加入：

```text
n = sqrt(N0/2) * (randn + j*randn)
r = x + n
```

经过能量守恒的相关解扩，输出噪声的复方差仍为 `N0`。所以在同一 `Eb/N0` 下，Step 2 的 BER 应该在统计误差内贴近 Step 1 和理论 Gray QPSK 曲线：

```text
Pb = 0.5 * erfc(sqrt(Eb/N0))
```

这不是 PN 没有作用，而是因为比较时已经把每个信息 bit 的总能量固定了。

### 9.2 不要直接对扩频 chip 调用 `awgn(..., 'measured')`

本步能量守恒归一化后，每 chip 平均功率是 `1/L`。如果把 Step 1 的每符号 SNR 数值原样交给按测得功率加噪的工具，噪声口径很容易被隐式改变。

初次实现建议显式按上式生成复高斯噪声。若以后改用工具箱函数，必须先推导它要求的是 `Eb/N0`、每 chip SNR 还是每符号 `Es/N0`。

---

## 10. 处理增益的正确理解

扩频因子为：

```text
L = Rc / Rs
Gp = 10*log10(L) dB
```

教学用 `L = 31` 时：

```text
Gp = 10*log10(31) ≈ 14.91 dB
```

但「处理增益约为 14.91 dB」不等于「在相同 `Eb/N0` 下，AWGN BER 曲线平移 14.91 dB」。

| 实验固定量 | 扩频后现象 |
| --- | --- |
| 每信息 bit 的 `Eb/N0` | 纯 AWGN 下 BER 与未扩频 QPSK 基本一致 |
| 每 chip 的 SNR | 相关累加后符号 SNR 约提高 `L` 倍 |
| 窄带或非相关宽带干扰功率 | 解扩将干扰能量分散，有用信号相干累加 |

报告中只写「扩频后抗噪声能力更强」是不够的，必须同时写明比较时固定了什么量。

---

## 11. MATLAB 参考实现

下面的代码使用基本 MATLAB 语法完成核心通路，不依赖 PN 或 AWGN 工具箱函数。

### 11.1 PN 发生器

```matlab
function bits = pn5_generate(nChips, initialState)
    state = logical(initialState(:).');

    if numel(state) ~= 5 || ~any(state)
        error('initialState must be a nonzero 5-bit vector.');
    end

    bits = false(nChips, 1);
    for n = 1:nChips
        bits(n) = state(1);
        newBit = xor(state(1), state(3));
        state = [state(2:5), newBit];
    end

    bits = double(bits);
end
```

这段代码直接实现 `s[n+5] = s[n+2] XOR s[n]`。如果你改变状态排列或移位方向，必须同时重新定义递推式和参考向量。

### 11.2 扩频与解扩

```matlab
function [txChips, complexPN] = pn_spread(txSymbols, spreadingFactor)
    nSymbols = numel(txSymbols);
    nChips = nSymbols * spreadingFactor;

    pnIBits = pn5_generate(nChips, [1 1 1 1 1]);
    pnQBits = pn5_generate(nChips, [1 0 1 0 1]);
    pnI = 1 - 2 * pnIBits;
    pnQ = 1 - 2 * pnQBits;
    complexPN = (pnI + 1j * pnQ) / sqrt(2);

    repeatedSymbols = repelem(txSymbols(:), spreadingFactor);
    txChips = repeatedSymbols .* complexPN / sqrt(spreadingFactor);
end

function rxSymbols = pn_despread(rxChips, complexPN, spreadingFactor)
    if numel(rxChips) ~= numel(complexPN)
        error('rxChips and complexPN must have equal lengths.');
    end
    if mod(numel(rxChips), spreadingFactor) ~= 0
        error('Chip count must be divisible by spreadingFactor.');
    end

    correlatedChips = rxChips(:) .* conj(complexPN(:));
    chipMatrix = reshape(correlatedChips, spreadingFactor, []);
    rxSymbols = sum(chipMatrix, 1).' / sqrt(spreadingFactor);
end
```

MATLAB 的 `reshape(..., L, [])` 将每个符号对应的连续 `L` 个 chip 放到同一列，然后按列求和。如果你的数据是行向量，建议先用 `(:)` 统一成列向量，避免隐式扩展生成巨大矩阵。

### 11.3 核心主流程

```matlab
rng(2026);

nBits = 2e5;
L = 31;
ebN0dB = 6;

% Reuse the Step 1 Gray QPSK modulator here.
txBits = randi([0 1], nBits, 1);
txSymbols = qpsk_modulate(txBits);       % Es = 1

[txChips, complexPN] = pn_spread(txSymbols, L);

% Energy checks.
symbolEnergyBefore = mean(abs(txSymbols).^2);
chipMatrix = reshape(txChips, L, []);
symbolEnergyAfter = mean(sum(abs(chipMatrix).^2, 1));
assert(abs(symbolEnergyBefore - symbolEnergyAfter) < 1e-12);

% Explicit Eb/N0-based complex AWGN.
ebN0Linear = 10^(ebN0dB / 10);
Eb = 1/2;
N0 = Eb / ebN0Linear;
noise = sqrt(N0/2) * ...
    (randn(size(txChips)) + 1j*randn(size(txChips)));
rxChips = txChips + noise;

rxSymbols = pn_despread(rxChips, complexPN, L);
rxBits = qpsk_demodulate(rxSymbols);     % Reuse Step 1
ber = mean(txBits ~= rxBits);
```

`qpsk_modulate` 和 `qpsk_demodulate` 应直接复用 Step 1 已通过测试的映射，不要在 Step 2 中另写一套不同的比特顺序。

### 11.4 PN 周期自相关

```matlab
pnBits = pn5_generate(31, [1 1 1 1 1]);
pn = 1 - 2*pnBits;
periodicAutocorrelation = zeros(31, 1);

for delay = 0:30
    periodicAutocorrelation(delay + 1) = ...
        mean(pn .* circshift(pn, -delay));
end

assert(abs(periodicAutocorrelation(1) - 1) < 1e-12);
assert(max(abs(periodicAutocorrelation(2:end) + 1/31)) < 1e-12);
stem(0:30, periodicAutocorrelation, 'filled');
grid on;
xlabel('Cyclic delay (chip)');
ylabel('Normalized periodic autocorrelation');
```

---

## 12. 必做实验

### 实验 1：PN 发生器单元测试

1. 生成 PN-I 和 PN-Q 的前 31 chip。
2. 导出并保存为参考向量。
3. 验证 31 chip 后状态回到初态。
4. 统计 0/1 个数，检查平衡性。
5. 绘制归一化周期自相关。

通过条件：所有断言通过，零延迟相关值为 1，其余延迟为 `-1/31`。

### 实验 2：无噪声符号恢复

使用固定比特序列：

```text
00 01 11 10
```

依次检查：

```text
QPSK 符号
每个符号对应的前几个扩频 chip
解扩符号
解调比特
```

通过条件：

```text
max(abs(rxSymbols - txSymbols)) < 1e-12
BER = 0
```

### 实验 3：能量守恒

对至少 1000 个随机 QPSK 符号，比较：

```text
E_before = mean(abs(txSymbols).^2)
E_after  = mean(sum(abs(chips_per_symbol).^2))
```

通过条件：`E_before` 和 `E_after` 的绝对误差小于 `1e-12`。

### 实验 4：AWGN BER 基线对齐

扫描：

```text
Eb/N0 = 0:1:10 dB
```

在同一幅图绘制：

1. Step 1 未扩频 QPSK 仿真 BER。
2. Step 2 PN 扩频 QPSK 仿真 BER。
3. Gray QPSK 理论 BER。

高信噪比点应使用「达到最小错误数或最大比特数」的停止规则。三条曲线应在统计波动范围内一致，不应出现固定 dB 平移。

### 实验 5：故意注入 PN 相位错误

将接收端 PN 循环移位 `0:30` chip，记录每个偏移下的：

```text
|解扩符号平均幅度|
BER
```

本实验只画出「已知偏移 -> 性能」的曲线，不在接收机中自动搜索最佳偏移。你应观察到偏移为 0 时符号恢复正确，错相时有用相关能量大幅下降。

### 实验 6：处理增益口径对照

分成两组仿真：

| 组别 | 固定条件 | 预期结果 |
| --- | --- | --- |
| A | 固定每 bit `Eb/N0`，使用能量守恒扩频 | 不同 `L` 的 BER 与 QPSK 基线一致 |
| B | 固定每 chip SNR，使用同一 chip 幅度口径 | 解扩后 SNR 随 `L` 约线性增长 |

两组结果不能画在一起却共用同一个 `Eb/N0` 标签，否则结论没有可比性。

---

## 13. 数据对齐与延迟

本文的纯向量 MATLAB 实现没有滤波器和流水线，因此扩频与块解扩的算法延迟可视为 0，第 `k` 个符号固定对应 chip 索引：

```text
(k-1)*L + 1 : k*L
```

但模块接口仍应声明：

| 信号 | 单位 | 长度 | 对齐基准 |
| --- | --- | --- | --- |
| `txBits` | bit | `Nbits` | 原始索引 |
| `txSymbols` | symbol | `Nbits/2` | 每 2 bit 一组 |
| `txChips` | chip | `Nbits*L/2` | 每 `L` chip 一组 |
| `rxSymbols` | symbol | `Nbits/2` | 对应同一发送符号 |
| `rxBits` | bit | `Nbits` | 对应同一原始比特 |

后续加入滤波、缓存或 RTL 流水后，必须用模块的确定性延迟、`valid` 信号或仿真帧序号对齐。不能通过「手工删掉前几个样值，直到 BER 为 0」来调通系统。

---

## 14. 推荐程序结构

```text
simulation/step2/
  run_step2.m
  config_step2.m
  pn5_generate.m
  pn_spread.m
  pn_despread.m
  qpsk_modulate.m
  qpsk_demodulate.m
  test_pn_generator.m
  test_noiseless_roundtrip.m
  test_energy_normalization.m
  compare_ber_with_step1.m
  out/
    pn_reference_vectors.mat
    pn_periodic_autocorrelation.png
    ber_step1_step2_theory.png
    pn_phase_offset_response.png
    results_step2.mat
```

建议在 `config_step2.m` 中集中冻结：

| 参数 | 教学阶段建议值 |
| --- | --- |
| 随机种子 | `2026` |
| QPSK 映射 | 与 Step 1 一致，`Es=1` |
| 扩频因子 | `L=31` |
| PN-I 初态 | `[1 1 1 1 1]` |
| PN-Q 初态 | `[1 0 1 0 1]` |
| PN bit 映射 | `0 -> +1, 1 -> -1` |
| 扩频归一化 | 发送端除以 `sqrt(L)` |
| 解扩归一化 | 相关求和后除以 `sqrt(L)` |
| `Eb/N0` 范围 | `0:1:10 dB` |
| PN 相位 | 0 chip，理想已知 |

---

## 15. 验收标准

| 验收项 | 要求 |
| --- | --- |
| PN 定义 | 递推式、状态顺序、初态、输出位、映射和零相位全部记录 |
| PN 周期 | 31 chip，周期后回到初态 |
| PN 参考向量 | 每次回归测试逐 chip 一致 |
| PN 自相关 | 零延迟为 1，非零延迟为 `-1/31` |
| 复 PN 模值 | `max(abs(abs(complexPN)-1)) < 1e-12` |
| 能量守恒 | 扩频前符号能量等于对应 chip 总能量 |
| 理想解扩 | 无噪声时符号最大误差小于 `1e-12` |
| 无噪声 BER | 0 |
| 复数运算 | 解扩显式使用 `conj(complexPN)` |
| AWGN BER | 在统计置信范围内对齐 Step 1 和理论 QPSK |
| 错相注入 | 0 chip 偏移为唯一正确基线，能观察错相性能恶化 |
| 边界 | 代码中没有隐式 PN 搜索或人工删数据对齐 |

---

## 16. 常见错误与排查

| 现象 | 可能原因 | 检查方法 |
| --- | --- | --- |
| PN 周期不是 31 | 递推抽头、移位方向或初态错误 | 打印每次迭代的 5 bit 状态 |
| PN 全为 0 | 装载了全零初态 | 在函数入口禁止全零态 |
| 自相关没有主峰 | 使用了非周期相关或 0/1 未映射为±1 | 确认使用 `circshift` 和双极性序列 |
| 无噪声解扩不能恢复 | Tx/Rx PN 初态、相位或长度不同 | 逐 chip 比较收发 PN |
| 输出幅度差 `sqrt(L)` 或 `L` | 扩频/解扩归一化混用 | 用一个符号手算总能量和相关和 |
| I/Q 翻转或旋转 | 复 PN 解扩没有取共轭 | 检查是否乘 `conj(complexPN)` |
| BER 接近 0.5 | PN 错相、符号分组错位或 QPSK 映射不一致 | 先回到无噪声固定短向量 |
| Step 2 比 Step 1 好约 `10log10(L)` dB | 无意中增加了每 bit 总能量 | 检查是否忘记在扩频端除以 `sqrt(L)` |
| Step 2 比理论差很多 | chip 噪声方差按错误 SNR 口径计算 | 显式从 `Eb=1/2` 计算 `N0` |
| 程序内存突然很大 | 行/列向量触发了隐式扩展 | 模块入口统一使用 `(:)` |
| BER 对比错位 | 手工截取数据或每符号 chip 分组错误 | 用原始索引和确定长度自动对齐 |

---

## 17. 推荐调试顺序

1. 只运行 PN 发生器，验证参考向量、周期和自相关。
2. 构造复 PN，确认每个 chip 的模为 1。
3. 只发送一个固定 QPSK 符号，手算扩频和解扩。
4. 发送 `00 01 11 10`，无噪声验证逐符号和逐比特一致。
5. 使用随机数据运行能量守恒断言。
6. 加入单一 `Eb/N0`，检查解扩后星座图。
7. 扫描 BER，与 Step 1 和理论曲线对齐。
8. 故意注入 PN 错相，记录相关幅度和 BER 的恶化。
9. 所有测试通过后，再为 Step 3 保留稳定接口。

这个顺序能把问题依次限定在 PN 生成、复数运算、归一化、噪声口径和对齐五个范围内。

---

## 18. 阶段报告建议

```text
1. 本阶段目标与边界
   说明只实现理想同步的单路 PN 扩频，未实现 PN 捕获。

2. PN 码定义
   给出递推式、初态、输出位、双极性映射和零相位。

3. 扩频与解扩模型
   给出复 PN、能量守恒扩频和共轭相关解扩公式。

4. 参数与能量口径
   说明 L、Es、Eb、N0 以及 chip 噪声方差。

5. 单元测试
   展示 PN 参考向量、周期、平衡性和自相关。

6. 端到端仿真
   展示无噪声恢复、能量检查和 BER 曲线。

7. 结果分析
   解释 Step 2 为什么在固定 Eb/N0 下与 Step 1 基线一致。

8. 错相实验与下一步
   用错一 chip 的实验说明 Step 3 为什么需要 PN 捕获。
```

报告应保留实际参数快照和固定随机种子，使结果可重现。

---

## 19. 进入 Step 3 前的交付物

Step 2 完成时应保存：

1. PN 参数快照与前 31 chip 黄金向量。
2. PN 周期自相关图和自动断言结果。
3. 无噪声扩频/解扩逐符号一致性结果。
4. 扩频前后能量对比表。
5. Step 1、Step 2 和理论 QPSK BER 对比曲线。
6. PN 相位偏移对相关幅度与 BER 影响的曲线。
7. 可自动运行的回归测试和结果数据。

本步的核心结论应是：在收发 PN 相位和码片时钟已知时，复 PN 扩频与共轭解扩能够无失真恢复 QPSK 符号；能量守恒归一化下的 AWGN BER 与 Step 1 基线一致。在此基线通过后，Step 3 才开始去掉「PN 相位已知」这一假设，实现 PN 捕获和零相位对齐。

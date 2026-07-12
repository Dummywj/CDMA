# Step 2：加入 PN 码（零基础版）

这一步只做一件事：在 Step 1 的 QPSK 通信链路中加入 PN 码。

在开始前，必须先分清两个容易被都叫成「调制」的操作：

| 操作 | 它做了什么 | 本文使用的名字 |
| --- | --- | --- |
| 把 2 个 bit 变成一个 QPSK 复数 | 只是在计算机中得到 I/Q 数字，还没有变成 800 MHz 无线波 | QPSK 映射 |
| 用 I/Q 波形控制无线载波 | 把基带信号搬到 800 MHz 附近 | 射频调制 |

本步仿真的完整顺序是：

```text
bit
-> QPSK 映射，得到复数符号
-> 乘 PN，得到复数 chip
-> 射频调制，搬到 800 MHz
```

前九步主要做复基带仿真，不真正生成 800 MHz 波形，因此最后一个「射频调制」在程序中被省略。

先不要被「PN 码」、「扩频」和「解扩」这些名字吓到。本步最核心的操作其实只有乘法：

```text
发送端：原信号乘 PN 码
接收端：实 PN 再乘同一条；复 PN 乘它的共轭
```

入门例子先使用只有 `+1` 和 `-1` 的实 PN。正一乘正一等于一，负一乘负一也等于一，所以 PN 的影响可以被消掉。后面使用复 PN 时，接收端需要乘它的共轭。

---

## 1. 本步要做出什么

Step 1 的链路是：

```text
随机比特 -> QPSK 映射 -> 加噪声 -> QPSK 判决 -> 统计错误
```

Step 2 把它变成：

```text
随机比特 -> QPSK 映射 -> 乘 PN -> 加噪声
             -> 再乘同一条 PN -> QPSK 判决 -> 统计错误
```

本步只验证三件事：

1. PN 码能按照固定规则重复生成。
2. 没有噪声时，接收端可以完全恢复原数据。
3. 加入噪声后，结果能与 Step 1 对上。

本步暂时假设接收端已经知道 PN 从哪里开始。怎样找到 PN 的开始位置，是 Step 3 的内容。

---

## 2. 先认识三个单位

| 名字 | 中文 | 简单理解 |
| --- | --- | --- |
| bit | 比特 | 原始的 0 或 1 |
| symbol | 符号 | QPSK 把 2 个 bit 合成的一个复数 |
| chip | 码片 | 一个符号乘 PN 后得到的小片段 |

例如：

```text
100 个 bit -> 50 个 QPSK 符号 -> 200 个 chip
```

这里假设一个 QPSK 符号变成 4 个 chip。一个符号变成多个 chip，就是「扩展」的最直观含义。

---

## 3. PN 码到底是什么

PN 的中文名字是「伪噪声」。「伪」的意思是：它看起来没有规律，但实际上是由程序按照固定规则生成的。

例如，一条很短的示意 PN 可以是：

```text
+1, -1, +1, +1, -1, -1, +1
```

发送端和接收端使用相同的生成规则，就能得到完全相同的 PN。它不是新数据，而是用来改变原信号的样子。

---

## 4. 用手算例子理解扩频

先不考虑 QPSK 复数。假设要发送的原信号是 `+2`，使用的 PN 是：

```text
PN = [+1, -1, +1, -1]
```

先把 `+2` 复制 4 份，再与 PN 逐个相乘：

```text
[+2, +2, +2, +2]
乘
[+1, -1, +1, -1]
等于
[+2, -2, +2, -2]
```

原来只有一个数，现在变成了 4 个 chip。这就是扩频。本例的扩频长度记为 `L = 4`。

---

## 5. 接收端怎样还原

接收端用同一条 PN 再乘一次：

```text
[+2, -2, +2, -2]
乘
[+1, -1, +1, -1]
等于
[+2, +2, +2, +2]
```

然后取平均：`(2 + 2 + 2 + 2) / 4 = 2`。原信号就被恢复了。这个过程叫解扩。

```text
扩频 = 复制原符号，然后乘 PN
解扩 = 再乘同一条 PN，然后相加
```

---

## 6. 如果 PN 用错了

假设接收端错用了 `[+1, +1, -1, -1]`，相乘后得到 `[+2, -2, -2, +2]`，平均值为 0，原信号没有被恢复。

即使 PN 内容正确，但开始位置错了一格，也会解错。Step 2 先保证收发两端使用同一条、同一起点的 PN；Step 3 再学习如何找到正确起点。

---

## 7. QPSK 符号已经是复数，为什么还能乘 PN

Step 1 中，2 个 bit 被映射成一个 QPSK 符号，例如：

```text
a = (1+j)/sqrt(2)
```

它不是「只有虚部的虚数」，而是同时有实部和虚部的复数：

```text
I = 实部 = 1/sqrt(2)
Q = 虚部 = 1/sqrt(2)
```

I 和 Q 可以理解为无线信号的两个数字控制量。它们不是「虚构的电压」，而是用复数方便地合并记录两路真实数字。

如果 PN 是实数 `+1/-1`，乘 PN 的含义很直接：

```text
a * (+1) = a       原样保留
a * (-1) = -a      I 和 Q 同时变号
```

也就是说，PN 为 `+1` 时保留当前 QPSK 点，PN 为 `-1` 时把它翻到星座图的对面。

本教学后面使用两条 PN 构造复 PN：

```text
p = (PN-I + j * PN-Q) / sqrt(2)
```

复数符号乘复 PN，可以理解为「按 PN 的规则改变当前点的方向」。例如：

```text
a = (1+j)/sqrt(2)
p = (1-j)/sqrt(2)

x = a * p = 1
```

原符号 `a` 变成了 chip `x`，但信息没有丢失。接收端乘 `p` 的共轭：

```text
x * conj(p)
= 1 * (1+j)/sqrt(2)
= a
```

于是原来的 QPSK 符号被恢复。所以「复数符号乘 PN」并不是把 bit 再调制一次，而是在复基带中改变每个 chip 的 I/Q 值。

### 7.1 那么到底是先扩频还是先调制

答案取决于「调制」指的是哪一层：

```text
若调制指 QPSK 复数映射：
先 QPSK 映射，再 PN 扩频。

若调制指搬到 800 MHz 无线载波：
先 PN 扩频，再射频调制。
```

因此本步的顺序不是「调制和扩频反了」，而是：

```text
bit -> QPSK 复数映射 -> PN 扩频 -> 射频调制
```

《老师十步法》的第二步明确以「数据符号」作为 PN 扩频的输入，所以本教学先复用 Step 1 生成复数符号，再乘 PN。这是为了逐步验证算法的简化复基带模型，不是完整 IS-95 发射机的全部处理顺序。

---

## 8. 为什么代码中有 `conj`

使用复 PN 时，记住：

```text
发送端：乘 complexPN
接收端：乘 conj(complexPN)
```

`conj` 叫共轭。它只是把复数虚部的正负号反过来：

```text
conj(1 + 2j) = 1 - 2j
```

这样可以把复 PN 引入的变化消掉。如果忘记 `conj`，解出来的 QPSK 点可能旋转或互相抵消。

---

## 9. 为什么要除以 `sqrt(L)`

如果把原符号直接复制成 `L` 份，总能量会变成原来的 `L` 倍。这样 Step 2 和 Step 1 的比较就不公平。

为了让扩频前后总能量不变：

```text
扩频 chip = 原符号 * PN / sqrt(L)
恢复符号 = sum(接收 chip * PN的共轭) / sqrt(L)
```

可以先把它理解为发送端和接收端各负责一半缩放。最后只需检查：扩频前一个符号的能量，等于扩频后它对应的 `L` 个 chip 的总能量。

---

## 10. 噪声和处理增益

处理增益是扩频通信中常见的词。先不要把它理解成「一加 PN，所有噪声就消失」。

解扩时，正确的有用信号会按照同一条 PN 叠加，而与 PN 无关的干扰不容易以相同方式叠加。

如果 Step 1 和 Step 2 都固定每个原始 bit 的总能量，那么在只有 AWGN 噪声的情况下，两者 BER 应该差不多：

```text
无噪声：Step 2 BER = 0
有噪声：Step 2 BER 接近 Step 1 的 QPSK BER
```

如果 Step 2 突然比 Step 1 好非常多，很可能是扩频后总能量变大了。

---

## 11. 第一遍编程：只处理一个符号

先不写 PN 发生器，直接手写一条短 PN：

```matlab
clear; clc;

% Step 1 中的一个 QPSK 符号。
txSymbol = (1 + 1j) / sqrt(2);

% 一个符号变成 4 个 chip。
L = 4;
pn = [1; -1; 1; -1];

% 发送端：复制符号并乘 PN。
repeatedSymbol = repmat(txSymbol, L, 1);
txChips = repeatedSymbol .* pn / sqrt(L);

% 先不加噪声。
rxChips = txChips;

% 接收端：再乘 PN，然后相加。
rxSymbol = sum(rxChips .* conj(pn)) / sqrt(L);

disp(txSymbol);
disp(rxSymbol);
disp(abs(rxSymbol - txSymbol));
```

最后的误差应为 0，或者是非常接近 0 的小数。先确保这个小程序正确，再处理很多符号。

---

## 12. 第二遍编程：处理多个符号

假设 `txSymbols` 是 Step 1 输出的一列 QPSK 符号：

```matlab
L = 31;
nSymbols = numel(txSymbols);
nChips = nSymbols * L;

% 每个符号复制 L 次。
repeatedSymbols = repelem(txSymbols(:), L);

% 生成与所有 chip 等长的 PN。
pnBits = pn5_generate(nChips, [1 1 1 1 1]);
pn = 1 - 2*pnBits;

% 扩频。
txChips = repeatedSymbols .* pn / sqrt(L);

% 无噪声信道。
rxChips = txChips;

% 每 L 个 chip 分为一组，分别相加。
afterPN = rxChips .* conj(pn);
chipGroups = reshape(afterPN, L, []);
rxSymbols = sum(chipGroups, 1).' / sqrt(L);

% 检查恢复误差。
maxSymbolError = max(abs(rxSymbols - txSymbols(:)));
disp(maxSymbolError);
```

`reshape` 在这里只是把一长串 chip 重新分组：

```text
第 1 到 L 个 chip       -> 第 1 个符号
第 L+1 到 2L 个 chip    -> 第 2 个符号
第 2L+1 到 3L 个 chip   -> 第 3 个符号
```

---

## 13. 第三遍编程：改成 I/Q 两条 PN

只用一条 PN 跑通后，再改成 I/Q 两条 PN：

```matlab
pnIBits = pn5_generate(nChips, [1 1 1 1 1]);
pnQBits = pn5_generate(nChips, [1 0 1 0 1]);

pnI = 1 - 2*pnIBits;
pnQ = 1 - 2*pnQBits;
complexPN = (pnI + 1j*pnQ) / sqrt(2);

% 扩频。
txChips = repeatedSymbols .* complexPN / sqrt(L);

% 先不加噪声。
rxChips = txChips;

% 解扩时必须使用 conj。
afterPN = rxChips .* conj(complexPN);
chipGroups = reshape(afterPN, L, []);
rxSymbols = sum(chipGroups, 1).' / sqrt(L);
```

再次检查 `rxSymbols` 和 `txSymbols` 是否相同。这一项通过之前，不要加噪声。

---

## 14. 无噪声正确后再加噪声

Step 1 已经把 QPSK 符号的平均能量设为 1。每个 QPSK 符号携带 2 个 bit，所以每 bit 能量是 `Eb = 1/2`。

```matlab
ebN0dB = 6;
ebN0 = 10^(ebN0dB/10);

Eb = 1/2;
N0 = Eb/ebN0;

noise = sqrt(N0/2) * ...
    (randn(size(txChips)) + 1j*randn(size(txChips)));

rxChips = txChips + noise;
```

这里先简单理解各个名字：

| 名字 | 简单含义 |
| --- | --- |
| `Eb` | 每个原始 bit 的能量 |
| `N0` | 表示噪声强度的量 |
| `Eb/N0` | 有用信号和噪声的相对强弱 |
| `ebN0dB` | 用 dB 表示的 `Eb/N0` |

`Eb/N0` 越大，通常表示信号相对噪声越强，BER 会越低。

---

## 15. 教学用 PN 发生器

先直接使用下面的函数。第一遍学习时，不需要立即弄懂每一行。

```matlab
function bits = pn5_generate(nChips, initialState)
    state = logical(initialState(:).');

    if numel(state) ~= 5 || ~any(state)
        error('Initial state must be a nonzero 5-bit vector.');
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

把它保存为 `pn5_generate.m`。它每次根据前面的 5 个 0/1 算出一个新的 0/1，会产生一条可重复的 PN。

程序中这一行：

```matlab
pn = 1 - 2*pnBits;
```

只是把生成器输出的 0/1 改成扩频需要的 `+1/-1`：

| 原数字 | 改成 |
| --- | --- |
| 0 | +1 |
| 1 | -1 |

本函数会在 31 个 chip 后开始重复。这里的 31 chip PN 只是为了教学和调试方便，不是最终的 IS-95 PN 短码。最终版本要按老师给定的参数和参考数据替换。

---

## 16. 建议的实验顺序

### 实验 1：手算小例子

用 4 个 chip 的手写 PN，确认能从 `[+2, -2, +2, -2]` 恢复出 `+2`。

### 实验 2：只发送一个 QPSK 符号

运行第 11 节的 MATLAB 代码，要求恢复误差接近 0。

### 实验 3：发送固定的四组 bit

使用 Step 1 中的：

```text
00 01 11 10
```

无噪声时，解扩后的 4 个 QPSK 符号必须与发送符号相同，BER 必须为 0。

### 实验 4：检查能量

可以用下面的代码比较扩频前后的能量：

```matlab
chipGroups = reshape(txChips, L, []);
energyBefore = mean(abs(txSymbols).^2);
energyAfter = mean(sum(abs(chipGroups).^2, 1));

disp(energyBefore);
disp(energyAfter);
```

两个结果应该都接近 1。

### 实验 5：加入噪声

先使用 `Eb/N0 = 6 dB`，确认能够得到合理的 BER。然后再扫描 `0:1:10 dB`，画出 Step 2 的 BER 曲线。

### 实验 6：与 Step 1 对比

在同一张图上画出 Step 1 QPSK BER、Step 2 PN 扩频 BER 和 QPSK 理论 BER。三条曲线应基本对齐。

### 实验 7：故意把 PN 错开一格

把接收端的 PN 移动 1 chip，再做解扩。输出应明显变差。这可以帮你理解 Step 3 为什么要找 PN 的正确开始位置。

---

## 17. 最容易出错的地方

| 现象 | 可能原因 | 先怎样查 |
| --- | --- | --- |
| 无噪声也不能恢复 | 发送和接收的 PN 不一样 | 打印前 20 个 PN 逐个对比 |
| 从第 2 个符号开始错 | chip 分组错位 | 检查是否每 `L` 个 chip 一组 |
| 恢复符号大了很多 | 忘记除以 `sqrt(L)` | 检查扩频和解扩两端 |
| QPSK 点发生旋转 | 复 PN 解扩时忘记 `conj` | 检查 `rxChips .* conj(complexPN)` |
| BER 接近 0.5 | PN 起点错了 | 先关掉噪声，用固定短数据测试 |
| Step 2 比 Step 1 好很多 | 扩频后总能量变大 | 检查扩频前后能量 |
| 程序突然占用很多内存 | 行向量和列向量相乘生成大矩阵 | 用 `(:)` 统一转为列向量 |

排错时最重要的原则是：先关掉噪声，再把数据量缩小到可以手工检查。

---

## 18. 验收清单

| 项目 | 通过条件 |
| --- | --- |
| 手算小例子 | 能从 4 个 chip 完全恢复原数 |
| PN 发生器 | 同一初始值总能得到同一条 PN |
| 无噪声符号恢复 | 最大误差小于 `1e-12` |
| 无噪声 BER | 0 |
| 能量 | 扩频前后每符号总能量相同 |
| 复 PN | 接收端使用 `conj(complexPN)` |
| 有噪声 BER | 总体随 `Eb/N0` 增大而下降 |
| Step 1 对比 | Step 2 BER 与 Step 1 基本对齐 |
| PN 错位 | 错开 1 chip 后结果明显变差 |

---

## 19. 最后只记住这六句话

1. PN 码是一串可以重复生成的 `+1/-1`。
2. 扩频就是把一个符号变成多个 chip，并逐个乘 PN。
3. 解扩就是使用同一条 PN 再乘一次，然后把一组 chip 相加。
4. 使用复 PN 时，接收端要使用 `conj`。
5. 为了公平比较，扩频前后每符号的总能量要一样。
6. Step 2 假设 PN 开始位置已知；Step 3 才学习怎样找到它。

本步的目标不是背名词，而是能用短 PN 手算扩频和解扩，并且能用程序在无噪声时完整恢复 Step 1 的 QPSK 数据。

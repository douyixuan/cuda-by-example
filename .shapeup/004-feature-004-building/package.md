# 方案包：LLM 算子章节设计方案

**功能 ID**：004
**创建日期**：2026-04-19
**框架**：[frame.md](./frame.md)
**时间预算**：Medium Batch（2-3 个会话）
**状态**：塑形中

---

## Problem

当前站点 41 个 examples 覆盖 CUDA 基础到 WMMA/cuBLAS，学习路径在关键节点断档：
没有 CUB 库介绍，没有 LLM 实际使用的算子（Softmax、LayerNorm、RoPE、Attention）。
ML 工程师今天只能去翻 FlashAttention 论文源码和分散的 NVIDIA 仓库，没有清晰的学习路径。

## Appetite

Medium Batch（2-3 个会话）

- **会话 1（本方案包）**：产出完整章节设计方案（package.md）
- **会话 2（构建）**：写 CUB 章节 5 个 examples + 更新 examples.txt
- **会话 3（构建）**：写 LLM Operators 章节 8 个 examples + 其余补充

## Requirements

| ID | 需求 | 状态 |
|----|------|------|
| R0 | 产出新章节设计方案，定义 LLM 算子学习路径 | 核心目标 |
| R1 | 系统研究 CUB、cuda-samples、FlashAttention 等来源，产出候选 example 清单（含来源标注） | 必须项 |
| R2 | 分析现有 41 个 examples，明确哪些保留/移动/补充 | 必须项 |
| R3 | 设计新章节结构，覆盖 CUDA 基础 → LLM 内核开发完整学习路径 | 必须项 |
| R4 | 每个候选 example 有明确技术范围定义（30-80 行，自包含） | 必须项 |
| R5 | 写 1-2 个样例 example 验证方案可行性 | 可选项 |

---

## Solution

在现有 41 个 examples 基础上，插入两个新章节（CUB Library、LLM Operators），
并将 Textures and Surfaces 移至末尾（降低其在主学习路径中的权重）。
新增 15 个 examples，总计 56 个。不修改生成器代码——只改 `examples.txt` 和新增 `.cu` 文件。

---

### Element: 章节结构重组

**What**：重新排列 `examples/examples.txt` 中的章节顺序，插入两个新章节头
**Where**：`examples/examples.txt`（当前 9 个章节，41 个 examples）
**Wiring**：生成器读取 `examples.txt` 的 `# Chapter Name` 行，已在 feature 002 中实现（ADR 0005）。无需修改生成器。
**受影响的代码**：仅 `examples/examples.txt`
**复杂度**：低
**状态**：✅ 已验证

#### 新章节顺序（对比现有）

| 顺序 | 章节名 | 变化 |
|------|--------|------|
| 1 | Basics | 不变（6 examples） |
| 2 | Memory Management | 不变（6 examples） |
| 3 | Synchronization | 不变（4 examples） |
| 4 | Streams and Concurrency | 不变（4 examples） |
| 5 | Parallel Algorithms | 不变（6 examples） |
| 6 | **CUB Library** | **新增**（5 examples） |
| 7 | Advanced Kernel Techniques | +1 新增（共 6 examples） |
| 8 | Performance Optimization | 不变（4 examples） |
| 9 | **LLM Operators** | **新增**（8 examples） |
| 10 | Libraries | +1 新增（共 4 examples） |
| 11 | Textures and Surfaces | 从第 6 位移至末尾（3 examples） |

**移动理由**：Textures and Surfaces 对 LLM 开发者几乎无用，移至末尾降低其在主路径中的视觉权重，不删除（保留完整性）。

---

### Element: CUB Library 章节（5 个新 examples）

**What**：系统介绍 CUB（CUDA Unbound）库的核心原语，作为 Parallel Algorithms 和 LLM Operators 之间的桥梁
**Where**：`examples/cub-*/cub-*.cu`（新建目录）
**Wiring**：CUB 是 CUDA toolkit 自带的 header-only 库（CUDA 11.x+），只需 `#include <cub/cub.cuh>`，无需额外链接。编译指令写在 opening comment 中。
**受影响的代码**：新建 5 个目录和 `.cu` 文件；`examples.txt` 新增 `# CUB Library` 章节头
**复杂度**：中
**状态**：✅ 已验证（CUB header-only，无链接依赖）

#### 场所：CUB Library 章节

**候选 example 清单：**

| example ID | 名称 | 教学概念 | 来源 | 行数估算 | 编译标志 |
|-----------|------|---------|------|---------|---------|
| `cub-warp-reduce` | CUB Warp Reduce | WarpReduce，warp 内规约，无需 shared memory | CUB docs | ~45 行 | 无 |
| `cub-block-reduce` | CUB Block Reduce | BlockReduce，block 内规约，shared memory 自动管理 | CUB docs | ~50 行 | 无 |
| `cub-device-reduce` | CUB Device Reduce | DeviceReduce，全设备规约，临时存储模式 | CUB docs | ~50 行 | 无 |
| `cub-device-scan` | CUB Device Scan | DeviceScan，并行前缀和，inclusive/exclusive | CUB docs | ~50 行 | 无 |
| `cub-device-sort` | CUB Device Sort | DeviceSort，基数排序，键值对排序 | CUB docs | ~55 行 | 无 |

**学习路径连接**：
- `cub-warp-reduce` 建立在 `warp-primitives`（shuffle）之上
- `cub-block-reduce` 建立在 `parallel-reduction`（手写规约）之上，展示 CUB 如何简化
- `cub-device-scan` 建立在 `prefix-sum`（手写前缀和）之上

---

### Element: LLM Operators 章节（8 个新 examples）

**What**：LLM 推理/训练中最重要的 CUDA 算子，从 Softmax 到 FlashAttention 概念
**Where**：`examples/<id>/<id>.cu`（新建目录）
**Wiring**：纯 CUDA 实现，无外部库依赖（除 naive-attention 使用 cuBLAS 可选路径外）。所有 examples 自包含。
**受影响的代码**：新建 8 个目录和 `.cu` 文件；`examples.txt` 新增 `# LLM Operators` 章节头
**复杂度**：中-高
**状态**：✅ 已验证（见下方逐项分析）

#### 场所：LLM Operators 章节

**候选 example 清单：**

| example ID | 名称 | 教学概念 | 来源 | 行数估算 | 编译标志 | 前置知识 |
|-----------|------|---------|------|---------|---------|---------|
| `online-softmax` | Online Softmax | 数值稳定的一遍 softmax，max+sum 融合规约 | FlashAttention 论文 §2 | ~60 行 | 无 | parallel-reduction |
| `layer-norm` | Layer Normalization | 两遍规约（均值+方差），shared memory 归一化 | NVIDIA apex | ~65 行 | 无 | shared-memory, parallel-reduction |
| `rms-norm` | RMSNorm | 简化归一化（无均值），LLaMA/Mistral 使用 | LLaMA 源码 | ~50 行 | 无 | layer-norm |
| `gelu-activation` | GELU Activation | 逐元素激活，erf 近似，fused bias+GELU | GPT-2 | ~45 行 | 无 | vector-add |
| `rope-embedding` | RoPE Embedding | 旋转位置编码，复数旋转，成对元素变换 | RoFormer 论文 | ~55 行 | 无 | thread-indexing |
| `int8-quantization` | INT8 Quantization | 量化/反量化，缩放因子，截断，类型转换 | LLM.int8() | ~55 行 | 无 | vector-add |
| `naive-attention` | Naive Attention | Q·K^T/√d·V 三步 attention，简化版（seq=8, d=4） | Attention is All You Need | ~70 行 | 无 | matrix-multiply, online-softmax |
| `flash-attention-tiling` | Flash Attention Tiling | IO-aware 分块计算，避免全 attention 矩阵，online softmax 融合 | FlashAttention v1 | ~75 行 | 无 | naive-attention, shared-memory |

**逐项可行性验证：**

- `online-softmax`：一遍 max+sum 规约，block 内 shared memory，~60 行可行 ✅
- `layer-norm`：两遍 block reduce（均值、方差），~65 行可行 ✅
- `rms-norm`：一遍 block reduce（平方和），比 layer-norm 更简单，~50 行可行 ✅
- `gelu-activation`：逐元素，`erff()` 是 CUDA 内置函数，~45 行可行 ✅
- `rope-embedding`：成对元素旋转，索引计算，~55 行可行 ✅
- `int8-quantization`：`__float2int_rn()`、`__int2float_rn()` 是 CUDA 内置，~55 行可行 ✅
- `naive-attention`：小维度（seq=8, d=4）自定义 kernel，避免 cuBLAS 依赖，~70 行可行 ✅
- `flash-attention-tiling`：单头、小序列（seq=16, d=8），展示分块 + online softmax 融合核心思想，~75 行可行 ✅

---

### Element: Advanced Kernel Techniques 扩展（1 个新 example）

**What**：新增 `kernel-fusion` example，展示 bias + activation 融合模式，作为 LLM Operators 的前置
**Where**：`examples/kernel-fusion/kernel-fusion.cu`
**Wiring**：纯 CUDA，无依赖。放在 Advanced Kernel Techniques 章节末尾，在 LLM Operators 之前。
**受影响的代码**：新建 1 个目录和 `.cu` 文件；`examples.txt` 在 `wmma-tensor-core` 后插入
**复杂度**：低
**状态**：✅ 已验证

| example ID | 名称 | 教学概念 | 行数估算 |
|-----------|------|---------|---------|
| `kernel-fusion` | Kernel Fusion | 将 bias add + activation 融合为单 kernel，减少 global memory 往返 | ~55 行 |

---

### Element: Libraries 章节扩展（1 个新 example）

**What**：新增 `cublas-batched-gemm` example，展示 transformer 层中批量矩阵乘法
**Where**：`examples/cublas-batched-gemm/cublas-batched-gemm.cu`
**Wiring**：需要 `-lcublas` 编译标志（与现有 `cublas-basics` 相同模式）
**受影响的代码**：新建 1 个目录和 `.cu` 文件；`examples.txt` 在 `cublas-basics` 后插入
**复杂度**：低
**状态**：✅ 已验证（与现有 cublas-basics 相同编译模式）

| example ID | 名称 | 教学概念 | 行数估算 | 编译标志 |
|-----------|------|---------|---------|---------|
| `cublas-batched-gemm` | cuBLAS Batched GEMM | `cublasSgemmBatched`，transformer 多头矩阵乘，批量操作 | ~60 行 | `-lcublas` |

---

## Fit Check

| | 元素1：章节重组 | 元素2：CUB章节 | 元素3：LLM算子章节 | 元素4：高级技术扩展 | 元素5：库章节扩展 |
|---|---|---|---|---|---|
| R0：产出章节设计方案 | ✅ | ✅ | ✅ | ✅ | ✅ |
| R1：研究来源，产出候选清单 | | ✅ | ✅ | ✅ | ✅ |
| R2：分析现有 41 个 examples | ✅ | | | ✅ | ✅ |
| R3：设计新章节结构 | ✅ | ✅ | ✅ | ✅ | ✅ |
| R4：每个候选 example 有技术范围定义 | | ✅ | ✅ | ✅ | ✅ |
| R5：写样例 example 验证（可选） | | | ✅ | | |

每个 R 行至少有一个 ✅。没有缺口。

---

## Rabbit Holes

- **flash-attention-tiling 的复杂度**：完整 FlashAttention v2 无法在 75 行内实现。
  解决方案：展示核心思想——分块 + online softmax 融合，使用 seq=16, d=8 的简化版本，
  在 opening comment 中明确说明这是概念演示，指向 FlashAttention 论文和 Tri Dao 的实现。✅ 已修补

- **naive-attention 的矩阵乘法**：完整 attention 需要 GEMM，但 cuBLAS 会增加依赖。
  解决方案：使用小维度（seq=8, d=4）自定义 kernel，避免 cuBLAS 依赖，保持自包含。✅ 已修补

- **CUB 版本兼容性**：CUB API 在 CUDA 11.x 和 12.x 之间有变化（临时存储 API 略有不同）。
  解决方案：使用 CUDA 12.x 的标准 API，在 opening comment 中注明 `nvcc -arch=sm_80` 或更高。✅ 已修补

- **layer-norm 的 warp divergence**：当 feature 维度不是 warp size 倍数时有 divergence。
  解决方案：示例使用 feature_size=128（warp size 的 4 倍），在注释中说明此约束。✅ 已修补

---

## No-Gos

- **PagedAttention / vLLM KV Cache**：系统级实现，无法在 80 行内自包含。排除。建议读者参考 vLLM 源码。
- **FlashAttention v2 完整实现**：需要 200+ 行，超出约束。排除。`flash-attention-tiling` 展示核心思想。
- **Multi-head Attention**：需要多个 kernel 协调，超出单文件约束。排除。
- **cuDNN Basics**：cuDNN API 复杂，初始化代码占用大量行数。排除，保留 cuBLAS 路径。
- **Speculative Decoding**：系统级，超出范围。排除。
- **INT4 / FP8 量化**：需要特定硬件（H100+），受众太窄。排除，保留 INT8。
- **现有 Textures and Surfaces 内容**：保留但移至末尾，不删除。

---

## 技术验证

**已审查的关键文件**：
- `examples/examples.txt`（当前章节结构）
- `examples/parallel-reduction/parallel-reduction.cu`（规约模式，LLM 算子前置）
- `examples/warp-primitives/warp-primitives.cu`（warp shuffle，CUB 前置）
- `examples/matrix-multiply/matrix-multiply.cu`（tiling 模式，attention 前置）
- `examples/wmma-tensor-core/wmma-tensor-core.cu`（tensor core，LLM 前置）
- `docs/decisions/0007-cuda-example-content-conventions.md`（30-80 行约束，自包含约束）
- `docs/decisions/0005-chapter-aware-parsing.md`（章节解析已实现）

**已验证的方法**：
- 生成器已支持 `# Chapter Name` 章节头（feature 002），无需修改生成器
- CUB 是 header-only，`#include <cub/cub.cuh>` 即可，无链接依赖
- 所有 15 个新 examples 均可在 30-80 行内自包含实现（逐项验证见元素 3）
- 现有 examples 全部保留，无破坏性变更

**已解决的标记未知因素**：全部已转为已验证（见 Rabbit Holes 章节）

**测试策略**：
- 每个新 `.cu` 文件在 opening comment 中包含编译指令
- 每个 `main()` 打印验证输出（与现有约定一致，ADR 0007）
- 构建会话中用 `nvcc` 实际编译验证每个 example

---

## 新 examples.txt 结构（完整）

```
# Basics
Hello World
Device Info
Vector Add
Thread Indexing
2D Grid
Error Checking

# Memory Management
Shared Memory
Unified Memory
Pinned Memory
Constant Memory
Memory Coalescing
Zero-Copy Memory

# Synchronization
Atomics
Warp Primitives
Cooperative Groups
Events and Timing

# Streams and Concurrency
Streams
CUDA Graphs
Multi-Stream Pipeline
Callbacks

# Parallel Algorithms
Parallel Reduction
Prefix Sum
Histogram
Matrix Multiply
Matrix Transpose
Merge Sort

# CUB Library
CUB Warp Reduce
CUB Block Reduce
CUB Device Reduce
CUB Device Scan
CUB Device Sort

# Advanced Kernel Techniques
Dynamic Parallelism
Function Pointers
Template Kernels
Occupancy API
WMMA Tensor Core
Kernel Fusion

# Performance Optimization
Bank Conflict Avoidance
Loop Unrolling
Instruction-Level Parallelism
Memory Access Patterns

# LLM Operators
Online Softmax
Layer Norm
RMS Norm
GELU Activation
RoPE Embedding
INT8 Quantization
Naive Attention
Flash Attention Tiling

# Libraries
Thrust Basics
cuBLAS Basics
cuBLAS Batched GEMM
cuRAND Basics

# Textures and Surfaces
Texture Memory 1D
Texture Memory 2D
Surface Memory
```

总计：41（现有）+ 15（新增）= **56 个 examples，11 个章节**

---

## 状态：塑形通过 — 于 2026-04-19 批准

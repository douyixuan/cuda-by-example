# 方案包：NVIDIA Samples Migration

**功能 ID**：002
**创建日期**：2026-04-18
**框架**：[frame.md](./frame.md)
**状态**：塑形中

---

## Problem

cuda-by-example 目前只有 12 个示例（573 行代码），覆盖了 CUDA 最基础的概念。一个想要系统学习 CUDA 的开发者来到站点后，在 "Warp Primitives" 就断了学习路径——没有中级到进阶的连贯路线。他们被迫去翻 NVIDIA 官方文档（冗长、缺少渐进式教学）或 NVIDIA/cuda-samples 源码（大量样板代码、依赖 helper 库、没有教学注释）。

**基线**：12 个示例的扁平列表，无章节分组。读者在入门阶段后就离开。

## Appetite

Medium Batch — 2-3 个会话

- Session 1：基础设施增强（`examples.txt` 分组支持、首页章节导航）+ 第一批 ~15 个核心示例
- Session 2：第二批 ~14 个中级/进阶示例
- Session 3（如需要）：剩余示例 + 审查打磨

## Requirements

| ID | 需求 | 状态 |
|----|------|------|
| R0 | 将示例从 12 个扩展到 ~41 个，覆盖从入门到进阶的完整 CUDA 学习路径 | 核心目标 |
| R1 | `examples.txt` 支持 `# 章节标题` 语法，生成器解析并传递分组信息 | 必须项 |
| R2 | 首页按章节分组展示示例，搜索过滤在分组模式下正常工作 | 必须项 |
| R3 | 每个新示例为 30-80 行自包含教学 `.cu` 文件，遵循现有 `//` 注释 + 代码交替的 Seg 模式 | 必须项 |
| R4 | 覆盖关键缺失主题：Tensor Core (WMMA)、CUDA Graphs、Dynamic Parallelism、Cooperative Groups、纹理、归约等 | 必须项 |
| R5 | 示例按渐进式学习路径排序——从基础到库集成的连贯路线 | 必须项 |
| R6 | 搜索功能自动覆盖新增示例 | 排除（已由现有 search-index.json 机制覆盖，无需额外工作） |
| R7 | 自定义 CUDA lexer 以高亮 `__global__`、`<<<>>>` 等语法 | 排除（v1 已接受 C++ lexer 覆盖 ~95%，见 ADR 0003） |

## Solution

引入三个元素：**章节感知解析器**（扩展生成器以支持分组）、**分组首页**（按章节展示示例列表）、**示例内容创作**（~29 个新 CUDA 教学 `.cu` 文件）。解决方案复用现有 `#` 前缀语法（当前被静默丢弃），将其转化为章节标题。Example 的线性链接保持不变以确保左右箭头导航跨章节工作。

### Element: 章节感知解析器

**What**：扩展 `parseExamples()` 函数，将 `examples.txt` 中 `#` 开头的行解析为章节标题，将示例组织到 `Chapter` 结构体中。

**Where**：`tools/generate.go` 第 226-261 行（`parseExamples` 函数）、第 138-143 行（数据模型）

**Wiring**：
- 新增 `Chapter` 结构体：`Name string`、`Examples []*Example`
- 修改 `parseExamples()` 返回值为 `([]*Example, []*Chapter)`
  - `# ` 开头的行成为当前章节的 `Name`
  - 后续非空/非 `#` 行归入当前章节
  - 无章节标题的示例归入隐式 "默认" 章节
- `PrevExample`/`NextExample` 链接仍跨章节线性连接（保持左右箭头导航）
- `main()` 中：`renderIndex` 接收 `[]*Chapter`；`renderExamples` 和 `writeSearchIndex` 接收展平的 `[]*Example`

**受影响的代码**：
- `tools/generate.go`：新增 `Chapter` 结构体（~5 行）；修改 `parseExamples()` 返回值和循环逻辑（~20 行改动）；修改 `renderIndex()` 签名（1 行）；修改 `main()` 调用链（~3 行）

**状态**：已验证——`#` 前缀已有解析逻辑（第 229 行 `!strings.HasPrefix(line, "#")`），只需从"丢弃"改为"捕获"。当前 `examples.txt` 中无 `#` 行，新增后向后兼容。

#### 场所：生成器（`tools/generate.go`）

**代码功能点：**

| 功能点 | 类型 | 连出 | 返回到 |
|--------|------|------|--------|
| `Chapter{Name, Examples}` | 结构体 | 被 `parseExamples` 生产 | 传入 `renderIndex` |
| `parseExamples()` | 函数 | 读取 `examples/examples.txt` | 返回 `([]*Example, []*Chapter)` |
| `renderIndex(chapters)` | 函数 | 执行 `index.tmpl` 模板 | 写入 `public/index.html` |
| `renderExamples(examples)` | 函数 | 不变，接收展平的 `[]*Example` | 写入各示例 HTML |
| `writeSearchIndex(examples)` | 函数 | 不变，接收展平的 `[]*Example` | 写入 `search-index.json` |

### Element: 分组首页

**What**：修改首页模板，按章节分组展示示例列表，搜索过滤支持跨组工作并在无匹配时隐藏整个章节。

**Where**：`templates/index.tmpl` 第 44-48 行（列表区块）、第 52-82 行（搜索 JS）；`templates/site.css`

**Wiring**：
- `index.tmpl` 从 `{{range .}}` 遍历 `[]*Example` 改为遍历 `[]*Chapter`
- 每个章节渲染为 `<div class="chapter"><h3>章节名</h3><ul>...</ul></div>`
- 搜索 JS 在过滤 `<li>` 后，额外检查每个 `.chapter` div 内是否有可见 `<li>`，若全部隐藏则隐藏该 div
- `site.css` 添加 `.chapter h3` 样式（字号、间距）

**受影响的代码**：
- `templates/index.tmpl`：重写第 44-48 行列表区块（~10 行）；修改第 63-81 行搜索 JS（~10 行新增）
- `templates/site.css`：添加 `.chapter` 和 `.chapter h3` 样式（~8 行）

**状态**：已验证——Go template 支持嵌套 `{{range}}`；JS DOM 操作直接可行

#### 场所：首页（`public/index.html`）

**UI 功能点：**

| 功能点 | 类型 | 连出 | 返回到 |
|--------|------|------|--------|
| 章节标题 `<h3>` | 显示 | 无 | 无（视觉分组锚点） |
| 示例链接 `<a href>` | 链接 | GET `/<example-id>/` | 示例详情页 |
| 搜索框 `<input#search>` | 输入 | 过滤 `search-index.json` | 显示/隐藏 `<li>` 和 `.chapter` div |

**代码功能点：**

| 功能点 | 类型 | 连出 | 返回到 |
|--------|------|------|--------|
| 搜索过滤 JS | 内嵌脚本 | 遍历 `li[data-id]` 匹配 query | 切换 `li.style.display` + `chapter.style.display` |
| `fetch('search-index.json')` | HTTP GET | 加载搜索索引 | 存入 `index` 变量 |

### Element: 示例内容创作

**What**：创建 ~29 个新 CUDA 教学示例，从 NVIDIA/cuda-samples 参考源码提炼为 30-80 行自包含 `.cu` 文件，组织到 9 个章节中。

**Where**：`examples/<id>/<id>.cu`（每个新示例一个目录）+ `examples/examples.txt`

**Wiring**：
- 每个新 `.cu` 文件遵循现有 Seg 模式（`//` 注释段 + 代码段交替）
- `examples.txt` 从 12 行扩展到 ~50 行（含 9 个 `# 章节标题` 行 + 41 个示例行）
- 生成器通过 `mustGlob("examples/" + id + "/*")` 自动发现新文件
- 搜索索引通过 `writeSearchIndex` 自动覆盖
- `PrevExample`/`NextExample` 自动根据 `examples.txt` 顺序连接

**章节与示例清单**：

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
Constant Memory          ← 新增
Memory Coalescing        ← 新增
Zero-Copy Memory         ← 新增

# Synchronization
Atomics
Warp Primitives
Cooperative Groups       ← 新增
Events and Timing        ← 新增

# Streams and Concurrency
Streams
CUDA Graphs              ← 新增
Multi-Stream Pipeline    ← 新增
Callbacks                ← 新增

# Parallel Algorithms
Parallel Reduction       ← 新增
Prefix Sum               ← 新增
Histogram                ← 新增
Matrix Multiply          ← 新增
Matrix Transpose         ← 新增
Merge Sort               ← 新增

# Textures and Surfaces
Texture Memory 1D        ← 新增
Texture Memory 2D        ← 新增
Surface Memory           ← 新增

# Advanced Kernel Techniques
Dynamic Parallelism      ← 新增
Function Pointers        ← 新增
Template Kernels         ← 新增
Occupancy API            ← 新增
WMMA Tensor Core         ← 新增

# Performance Optimization
Bank Conflict Avoidance  ← 新增
Loop Unrolling           ← 新增
Instruction-Level Parallelism  ← 新增
Memory Access Patterns   ← 新增

# Libraries
Thrust Basics            ← 新增
cuBLAS Basics            ← 新增
cuRAND Basics            ← 新增
```

**受影响的代码**：
- `examples/examples.txt`：完全重写（从 12 行到 ~50 行）
- `examples/` 目录：新增 29 个子目录，每个含一个 `.cu` 文件

**状态**：已验证——模式已建立，生成器已测试可处理任意数量 `.cu` 文件

## Fit Check

| | Element: 章节感知解析器 | Element: 分组首页 | Element: 示例内容创作 |
|---|---|---|---|
| R0：扩展到 ~41 个示例 | | | Yes |
| R1：examples.txt 支持章节分组语法 | Yes | | |
| R2：首页按章节导航展示 | Yes | Yes | |
| R3：每个示例 30-80 行，遵循 Seg 模式 | | | Yes |
| R4：覆盖 Tensor Core、CUDA Graphs 等 | | | Yes |
| R5：渐进式学习路径排序 | Yes | Yes | Yes |

每个 R 行至少一个 Yes。没有缺口。每个 Element 列至少一个 Yes。没有多余元素。

## Rabbit Holes

- **Dynamic Parallelism / WMMA 编译要求**：修补——这些示例需要特定 compute capability（3.5+ / 7.0+）和编译标志（`-rdc=true`）。由于本站是纯教学展示（不编译运行），在示例开头注释中声明硬件和编译要求即可。不影响生成器或站点功能。

- **库示例链接依赖**：修补——cuBLAS/cuRAND/Thrust 示例编译时需要 `-lcublas`/`-lcurand` 等链接标志。同上，在示例注释中说明编译命令。Thrust 是 header-only，更简单。

- **搜索 JS 在分组模式下的行为**：修补——当前搜索 JS 基于 `<li>` 逐个过滤。分组后需额外 ~10 行 JS 在过滤后隐藏空章节 div。已验证 DOM 操作直接可行。

- **41 个示例的生成性能**：已验证——`renderExamples` 中的 `defer f.Close()` 会堆积 41 个 defer，但在 Go 中对此量级完全无影响。当前 12 个已用此模式。

- **示例内容量与时间预算适配**：修补——29 个新示例的创作由 AI 代理辅助，参考 NVIDIA/cuda-samples 源码提炼。预估：基础设施变更 ~1h + 每个示例 ~0.5h（代理辅助），Session 1 完成基础设施 + 15 个示例，Session 2 完成 14 个示例。

## No-Gos

- **自定义 CUDA lexer**：v1 已接受 C++ lexer 覆盖 ~95% 的 CUDA 语法（ADR 0003）。`__global__`/`__shared__` 等关键字不单独高亮。在此批次中不改变。

- **在浏览器中运行 CUDA 代码**：不可行（无 WebGPU-CUDA 桥接），已在 001 中排除。

- **自动化 diff 测试**：生成器输出的回归测试。不在此批次范围内。

- **多 GPU 示例**：需要多 GPU 硬件，且不适合单文件教学格式。排除。

- **CUDA Driver API 示例**：Driver API 是低级 API（`cuCtxCreate` 等），与 Runtime API 教学目标不符。排除。

- **GUI/图形示例**：依赖 OpenGL/Vulkan 互操作，不适合自包含单文件格式。排除。

## Technical Validation

**已审查的代码库**：
- `tools/generate.go`：完整阅读（341 行）——理解 `parseExamples`、`parseSegs`、`chromaFormat`、`renderIndex`、`renderExamples`、`writeSearchIndex` 的完整数据流
- `templates/index.tmpl`：完整阅读——理解首页渲染和搜索 JS
- `templates/example.tmpl`：完整阅读——确认示例页无需修改
- `templates/site.css`：完整阅读（230 行）——确认样式扩展点
- `examples/shared-memory/shared-memory.cu`、`examples/streams/streams.cu`：验证示例文件模式
- `examples/examples.txt`：验证当前 12 个示例列表和格式
- `.shapeup/001-cuda-by-example-site-shipped/package.md`：了解已有架构决策
- `docs/architecture.md`：了解约定和已知限制

**已验证的方法**：
- 生成器成功构建当前 12 个示例（`go run -mod=mod tools/generate.go /tmp/cuda-test-output` 成功退出）
- `#` 前缀解析逻辑已存在于 `parseExamples` 第 229 行，改造为章节捕获的工作量极小
- Go template 支持嵌套 `{{range}}`，分组渲染无技术障碍
- `favicon.ico` 存在于 `templates/` 目录（71518 字节），不会导致构建 panic

**已解决的标记未知因素**：全部 5 个风险已解决，零未解决项

**测试策略**：
- 基础设施变更后运行 `go run -mod=mod tools/generate.go` 验证构建成功
- 检查生成的 `index.html` 中章节分组是否正确渲染
- 检查搜索过滤是否在分组模式下正常工作
- 每个新 `.cu` 文件创建后增量构建验证

---

## 状态：Shape Go — 于 2026-04-18 批准

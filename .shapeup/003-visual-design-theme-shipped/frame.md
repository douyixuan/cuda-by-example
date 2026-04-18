# Frame: Code Syntax Highlighting

**Feature ID**: 003
**Created**: 2026-04-18
**Status**: Framing

---

## Problem

cuda-by-example 是一个以**代码为核心**的教学站点，但代码块几乎没有有效的语法高亮。一个开发者打开任意示例页面时，看到的代码几乎是单色的：

- **大量 token 无颜色** — CSS 中 `.nf`（函数名）、`.nx`（变量名）、`.o`（操作符）、`.p`（标点）的样式规则为空（`{ }`），这些 token 全部渲染为默认文本色。这意味着 `cudaMalloc`、`threadIdx.x`、`<<<blocks, threads>>>` 这些 CUDA 核心概念在视觉上毫无突出。

- **有颜色的部分也很低调** — 关键字是低饱和度棕色（`#954121`），数字是灰色（`#666666`），字符串是暗绿（`#219161`）。整体效果接近纯文本。

- **CUDA 特有语法无差异化** — `__global__`、`__device__`、`__shared__`、`<<<...>>>` 是 CUDA 最具辨识度的语法，但它们在视觉上与普通 C++ 代码没有任何区分。

**基准现状**：Chroma 库已集成（使用 `swapoff` 样式 + CSS classes + C++ lexer），基础设施完备，问题不在工具链而在配色和 lexer 的 token 覆盖。

**当前的变通方式**：用户只能靠自己的经验和注意力去区分代码结构，无法借助颜色快速扫描——这直接违背了 "by example" 格式的核心价值主张：让代码一目了然。

## Affected Segment

**所有用户**（作者 + 公开访客）：

代码高亮影响每一个示例页面的每一行代码。站点目前有 59 个示例，每个示例都是左侧注释 + 右侧代码的并排布局。代码区是用户视觉停留时间最长的区域。

对比参照：主流代码学习站点（Rust Book、Go by Example、MDN）和 IDE（VS Code、JetBrains）都提供丰富的语法高亮，用户对此有隐性期待。

## Business Value

- **教学效果** — 语法高亮是代码可读性的核心。颜色让用户能快速区分关键字/类型/函数/字符串/注释，降低认知负担，这是 "by example" 教学格式的基本要求
- **专业感** — 缺少高亮让站点看起来像一个半成品，影响访客对内容质量的信任
- **CUDA 学习体验** — CUDA 特有语法（`__global__`、`<<<>>>`）的视觉突出能帮助初学者更快建立对 GPU 编程模型的直觉

## Evidence

- CSS 中 4 个主要 token 类（`.nf`、`.nx`、`.o`、`.p`）颜色规则为空，只有 keywords、types、numbers、strings、comments 有颜色（共 ~15 个 token 类）
- 实际渲染的 HTML（如 `hello-world/index.html`）中，大部分代码 span 只有 `.cl`（code line）class，缺少语义化的 token class
- 当前使用 Chroma 的 C++ lexer（`lexers.Get(filePath)` 按文件扩展名匹配），CUDA 特有语法（`__global__` 等）由 C++ lexer 处理但可能未被正确分类
- Chroma 库已 vendor 到项目中（`vendor/github.com/alecthomas/chroma/v2`），可以直接修改或扩展

## Appetite

**Small Batch: 1 session**

聚焦范围：
- 选择或定制一套有表现力的代码高亮配色方案（light + dark mode）
- 确保 Chroma 的 C++ lexer 对 CUDA `.cu` 文件的 token 覆盖足够
- 如需要，调整或扩展 lexer 以正确高亮 CUDA 特有语法
- 更新 CSS 中所有 token class 的颜色规则

不包括：站点整体视觉身份（配色方案、字体、布局）、响应式设计、动画等——这些可以作为后续功能单独 frame。

## Frame Statement

> "If we can shape this into something doable and execute within 1 session, it will make every code example on the site immediately more readable — with proper syntax highlighting that distinguishes keywords, types, functions, strings, and CUDA-specific syntax at a glance."

---

## Status: Frame Go — approved 2026-04-18

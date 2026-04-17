# Package: Code Syntax Highlighting

**Feature ID**: 003
**Created**: 2026-04-18
**Frame**: [frame.md](./frame.md)
**Appetite**: Small Batch (1 session)
**Status**: Shaping

---

## Problem

cuda-by-example 的代码块完全没有语法高亮。根因是 `.cu` 文件扩展名不被 Chroma 的任何 lexer 识别——`lexers.Get(filePath)` 返回 `nil`，退回到 Fallback lexer（纯文本）。渲染后的 HTML 只有 `class="cl"`（code line），没有语义化的 token class（如 `.k`、`.nf`、`.s`），因此 CSS 中的颜色规则从未生效。

基准现状：59 个示例页面的代码区完全是单色文本。

## Requirements

- **R0**: 完整的语法高亮——所有主要 token 类（关键字、类型、函数名、字符串、数字、注释、操作符、预处理器）都有明确的颜色区分（Core goal）
- **R1**: 成熟的配色方案——使用 GitHub light/dark 主题作为基础，light + dark mode 都要好看（Must-have）
- **R2**: CUDA 特有语法突出——`__global__`、`__device__`、`__shared__`、`__host__`、`__constant__` 等要被识别为关键字并着色（Must-have）
- **R3**: 不破坏现有架构——继续使用 Chroma + CSS classes 方式，不重写生成器（Must-have）

## Solution

三步修复：(1) 在 vendored C++ lexer 中注册 `*.cu` 扩展名并添加 CUDA 关键字规则；(2) 用 GitHub light/dark 主题的配色替换 `site.css` 中的语法高亮颜色；(3) 重新生成站点验证效果。

### Changes

| File / Module | Change | Serves |
|---------------|--------|--------|
| `vendor/.../lexers/embedded/c++.xml` config section | 添加 `<filename>*.cu</filename>` 使 `.cu` 文件匹配 C++ lexer | R0, R3 |
| `vendor/.../lexers/embedded/c++.xml` statements state | 在 generic `Name` 规则之前，添加 CUDA 关键字规则：`__(global\|device\|host\|shared\|constant\|managed\|restrict\|noinline\|forceinline\|launch_bounds)__\b` → `KeywordReserved` | R2 |
| `templates/site.css` light mode 语法高亮区 | 替换现有稀疏的颜色规则为 GitHub light 主题的完整配色（覆盖 `.k`、`.kt`、`.kr`、`.nf`、`.n`、`.nb`、`.o`、`.p`、`.s`、`.se`、`.m`/`.mi`/`.mf`/`.mh`/`.mo`、`.c1`、`.cm`、`.cp`、`.cpf`、`.err` 等全部 token class） | R0, R1 |
| `templates/site.css` dark mode 语法高亮区 | 同上，使用 GitHub Dark 主题配色 | R0, R1 |

**Fit check**: R0 由 lexer 修复（产出语义 token）+ CSS 配色（着色）共同覆盖。R1 由 CSS 配色覆盖。R2 由 CUDA 关键字规则覆盖。R3 由方案本身保证（只改 CSS 和 vendored XML，不改 generate.go 架构）。每个 R 都映射到至少一个 change。无间隙。

## Rabbit Holes

- **`<<<>>>` 语法高亮**：C++ lexer 的操作符规则逐字符匹配 `<` 和 `>`，`<<<1, 1>>>` 会被标记为 6 个独立的 Operator token。效果可接受——它们会被着色为操作符色。Patched：不做特殊处理，1 session 内不值得为此创建专门的 CUDA 操作符规则。

- **CUDA 内置变量（`threadIdx.x` 等）**：这些是结构体字段访问，不是语言关键字。C++ lexer 将其标记为 `Name`（通用标识符），不做特殊高亮。Declared out of bounds：在 GitHub 主题中，通用标识符用默认文本色是标准行为。

- **vendored 文件的嵌入编译**：`lexers.go` 使用 `//go:embed embedded` 在编译时加载 XML。修改后的 XML 在 `go run` 时自动生效，无需额外构建步骤。Validated ✅。

- **C++ 函数定义正则对 CUDA 的兼容性**：root state 的函数定义正则 `((?:[\w*\s])+?(?:\s|[*]))([a-zA-Z_]\w*)(\s*\([^;]*?\))` 能正确匹配 `__global__ void hello() {`，将 `hello` 标记为 `NameFunction`。Validated ✅。

- **CUDA 关键字正则的精确性**：`__(global|device|host|shared|constant|managed|restrict|noinline|forceinline|launch_bounds)__\b` 使用枚举列表而非通配 `__\w+__`，避免误匹配非 CUDA 的双下划线标识符（如 `__cplusplus`、`__LINE__` 等应保持原有分类）。Validated ✅。

## No-Gos

- **不做 CUDA 内置变量/函数的特殊高亮**：`threadIdx`、`blockDim`、`cudaMalloc` 等 CUDA API 函数和内置变量不做特殊处理。它们是 API 标识符而非语言关键字，由通用 `Name` 规则覆盖。可作为后续增强。
- **不做自定义主题切换器**：不提供用户选择主题的 UI。使用系统 `prefers-color-scheme` 自动切换 light/dark。
- **不改变站点整体视觉身份**：配色、字体、布局等整体视觉设计不在本次范围。
- **不修改 `generate.go` 的架构**：`chromaFormat()` 函数的调用方式和参数不变。

## Technical Validation

**Key files reviewed**:
- `tools/generate.go` — `chromaFormat()` 使用 `lexers.Get(filePath)` + `html.WithClasses(true)` + `swapoff` style
- `vendor/.../lexers/embedded/c++.xml` — 完整的 C++ tokenizer 规则，330 行 XML
- `vendor/.../lexers/lexers.go` — `Get()` 调用 `GlobalLexerRegistry.Get(name)` 按名称/别名/文件名模式匹配
- `vendor/.../styles/github.xml` — 38 行，覆盖所有主要 token 类的配色
- `vendor/.../styles/github-dark.xml` — 44 行，覆盖所有主要 token 类的 dark mode 配色
- `vendor/.../chroma/v2/types.go:230-310` — 完整的 token type → CSS class 映射表
- `templates/site.css` — 当前的颜色规则（light + dark mode）
- `public/hello-world/index.html` — 实际渲染输出验证

**Approach validated**: 在当前代码中运行 `go run tools/generate.go` 生成站点并检查 HTML 输出，确认 `.cu` 文件确实只产出 `class="cl"` 无语义 token。修改 C++ lexer 添加 `*.cu` 后将产出完整的 token class。

**Test strategy**: 修改后运行 `go run tools/generate.go /tmp/test-site`，用 grep 检查输出 HTML 中是否包含 `.k`、`.nf`、`.s` 等语义 token class。对比 hello-world 示例的修改前后 HTML 差异。运行 `go test ./tools/...` 确保现有测试通过。

---

## Status: Shape Go — approved 2026-04-18

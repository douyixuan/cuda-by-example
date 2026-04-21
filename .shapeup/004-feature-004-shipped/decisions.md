# 做出的决策 — LLM 算子章节设计方案

**功能 ID**：004
**交付时间**：2026-04-21
**时间预算**：Medium Batch（2-3 个会话）
**实际工作量**：2 个构建会话（+ 1 个塑形会话）

## 关键架构决策

- **内容专属章节扩展**（ADR 0009）：通过仅修改 `examples.txt` 和新增 `.cu` 文件添加 2 个新章节 + 15 个新 examples，零生成器代码变更。验证了 feature 002 架构设计的可扩展性。
- **第一个 example 承载章节介绍**（ADR 0009）：`cub-warp-reduce.cu` 的 opening comment 扩展为 CUB 整体介绍，说明 Warp/Block/Device 三级架构和 5 个 examples 的关系，无需改动生成器或模板。
- **Source 引用用 Markdown 链接**（ADR 0010）：`// Source: [display](url)` 格式通过 Blackfriday 渲染为可点击的 `<a>` 标签，零生成器变更，利用现有的注释内 Markdown 渲染管道。

## 被削减的内容（范围削减）

- **R5（写样例验证）升级为必须项**：原计划只写 1-2 个样例 example 验证方案可行性，实际构建了全部 15 个 examples。方案包设计质量足够高，无需样例验证阶段。
- **无功能性削减**：所有塑形元素均已实现。Package.md 的全部 No-Gos 保持不变（PagedAttention、FlashAttention v2 完整实现、multi-head attention、cuDNN、INT4/FP8 等）。

## 出乎意料的内容

- **flash-attention-tiling 的 80 行限制**：初版 97 行，超出 ADR 0007 限制。需要精简：合并 `cudaMalloc` 调用、移除冗余注释和空行、内联局部变量。说明 online softmax + tiling 的核心思想在 80 行内是可表达的，但没有裕量。
- **CUB 比预期更紧凑**：DeviceReduce/DeviceScan/DeviceSort 均在 38-47 行内完成，远低于预估的 50-55 行。CUB 的 "query temp storage → allocate → execute" 三步模式虽然独特，但每步只需 2-3 行。
- **Source 格式迭代**：经历了三次演化：纯文本 → 论文引用 → GitHub 仓库 URL。最终确定 Markdown 链接格式，让用户可以直接跳转到有 CUDA 实现的代码仓库。
- **生成器零改动实际上可行**：在设计之初，预期可能需要为章节添加描述文字（需改生成器），实际通过"第一个 example 承载章节介绍"的模式完全绕过了这个需求。

## 未来改进领域

- **Index 页面章节描述文字**：当前 index 只有章节名，无说明文字。若需要，改动路径清晰：在 `Chapter` 结构体加 `Description string`，在 `examples.txt` 解析 `## desc:` 行，在 `index.tmpl` 渲染。触发时机：章节数量增长到读者无法通过名称判断内容时。
- **80 行限制 CI 检查**：目前无自动检查。可在 `generate_test.go` 中增加一个测试：遍历所有 `.cu` 文件，断言行数 ≤ 80。
- **Source: 格式 lint**：CUB 和 LLM Operators 章节的新 examples 应包含 `Source:` 行，目前依赖约定，无自动检查。

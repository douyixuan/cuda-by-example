# Frame: NVIDIA Samples Migration

**Feature ID**: 002
**Created**: 2026-04-16
**Status**: Framing

---

## Problem

cuda-by-example 目前只有 12 个手写示例（573 行代码），覆盖了 CUDA 最基础的概念（hello world、vector add、shared memory 等）。但 CUDA 的特性远不止这些——Tensor Core、CUDA Graphs、Dynamic Parallelism、Cooperative Groups、纹理、归约算法等重要主题完全缺失。

一个想要系统学习 CUDA 的开发者来到站点后，很快会发现学习路径在 "Warp Primitives" 就断了。他们的出路是：
- 去读 NVIDIA 官方文档（冗长、缺少渐进式教学）
- 去翻 NVIDIA/cuda-samples 源码（大量样板代码、依赖 helper 库、没有教学注释）
- 搜博客（质量参差不齐）
- 问 AI（缺少结构化路径）

**基准现状**：12 个示例 → 读者在入门阶段后就离开，没有中级→进阶的连贯路径。

## Affected Segment

从初学者到有经验的开发者的全路径 CUDA 学习者：
- 刚接触 GPU 编程的学生和开发者
- 已知基础但想深入特定特性（如 Tensor Core、Graphs）的中级开发者
- 需要快速查阅某个 CUDA API 用法的有经验开发者

CUDA 开发者社区持续增长（AI/ML 驱动），但高质量的 "by example" 风格结构化学习资源几乎不存在。gobyexample.com 在 Go 社区的成功证明了这种格式的价值。

## Business Value

- **社区贡献**：填补 CUDA 学习资源的空白——目前没有一个 "CUDA by Example" 风格的结构化站点覆盖从入门到进阶的完整路径
- **深度学习**：将 NVIDIA 的 100+ 示例提炼为教学风格的代码是深入理解每个 CUDA 特性的最有效方式
- **内容护城河**：从 12 个示例扩展到 ~50 个，使站点从 "玩具项目" 变为 "参考资源"

## Evidence

- NVIDIA/cuda-samples 有 100+ 示例，横跨 9 个类别（Introduction、Concepts、Features、Libraries、Performance 等）
- 去除重复变体（*Drv、*_nvrtc）、平台特定、GUI 依赖、多 GPU 后，约 40-50 个适合转换为单文件教学示例
- 现有 12 个示例在 3 天内完成（4 月 9-11 日），平均每个示例 ~48 行代码，平均 ~2 小时/个（含生成器开发）
- 生成器基础设施（解析器、模板、CI/CD）已完备，新增示例的边际成本主要是内容创作
- gobyexample.com 的成功先例：Go 社区中最受欢迎的学习资源之一

## Appetite

**Medium Batch: 2-3 sessions**

- Session 1：基础设施增强（examples.txt 分组支持、首页章节导航）+ 筛选并确定最终示例清单 + 第一批 ~15 个核心示例
- Session 2：第二批 ~15-20 个中级/进阶示例
- Session 3（如需要）：剩余示例 + 审查 & 打磨全站

约束：每个示例需要从 NVIDIA 的冗长代码中提炼为 30-80 行的自包含教学 `.cu` 文件，这是创作性工作而非机械复制。

## Frame Statement

> "If we can shape this into something doable and execute within 2-3 sessions, it will transform cuda-by-example from a 12-example demo into a ~50-example comprehensive CUDA learning resource — filling a genuine gap in the CUDA education ecosystem."

---

## Status: Frame Go — approved 2026-04-16

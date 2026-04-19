# 山形图 — LLM 算子章节设计方案
**更新时间**：2026-04-19
**会话**：01

## 范围
  ✓ examples.txt-update — 完成（章节重组，Textures 移至末尾，CUB Library 插入）
  ✓ cub-warp-reduce — 完成（51 行，WarpReduce + TempStorage 模式）
  ✓ cub-block-reduce — 完成（52 行，BlockReduce，对比 parallel-reduction）
  ✓ cub-device-reduce — 完成（37 行，两步 API 模式验证）
  ✓ cub-device-scan — 完成（38 行，InclusiveSum，对比 prefix-sum）
  ✓ cub-device-sort — 完成（46 行，SortPairs，键值对排序）

## 风险
无剩余风险。所有 CUB 范围已完成。

## 下一步
会话 3：LLM Operators 章节（8 个 examples）+ kernel-fusion + cublas-batched-gemm

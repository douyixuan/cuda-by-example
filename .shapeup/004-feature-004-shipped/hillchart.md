# 山形图 — LLM 算子章节设计方案
**更新时间**：2026-04-19
**会话**：02

## 范围
  ✓ examples.txt-update — 完成（章节重组，Textures 移至末尾，CUB + LLM Operators 插入）
  ✓ cub-warp-reduce — 完成（51 行）
  ✓ cub-block-reduce — 完成（52 行）
  ✓ cub-device-reduce — 完成（37 行）
  ✓ cub-device-scan — 完成（38 行）
  ✓ cub-device-sort — 完成（46 行）
  ✓ kernel-fusion — 完成（59 行）
  ✓ cublas-batched-gemm — 完成（59 行）
  ✓ online-softmax — 完成（66 行）
  ✓ layer-norm — 完成（72 行）
  ✓ rms-norm — 完成（57 行）
  ✓ gelu-activation — 完成（45 行）
  ✓ rope-embedding — 完成（54 行）
  ✓ int8-quantization — 完成（55 行）
  ✓ naive-attention — 完成（66 行）
  ✓ flash-attention-tiling — 完成（80 行，符合 ADR 0007 限制）

## 风险
- 无。所有必须项完成，go test 全绿。

## 下一步
1. git commit 并运行 /ship 004

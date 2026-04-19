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
  ▼ flash-attention-tiling — 下坡（97 行，超出 80 行限制，需要裁剪）

## 风险
- flash-attention-tiling 超出 ADR 0007 的 80 行限制（当前 97 行），需裁剪约 17 行

## 下一步
1. 裁剪 flash-attention-tiling.cu 至 ≤80 行
2. 运行 go test 确认全绿
3. git commit 并运行 /ship 004

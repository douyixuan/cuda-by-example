# 构建摘要 — LLM 算子章节设计方案

**功能 ID**：004
**构建会话数**：3（塑形 1 + 构建 2）
**完成日期**：2026-04-19

## 构建了什么

- `examples/examples.txt` 章节重组：
  - 新增 `# CUB Library`（5 examples）
  - 新增 `# LLM Operators`（8 examples）
  - Advanced Kernel Techniques 新增 `Kernel Fusion`
  - Libraries 新增 `cuBLAS Batched GEMM`
  - `Textures and Surfaces` 移至末尾
  - 总计：41 → 56 examples，9 → 11 章节
- CUB Library 章节（5 examples，均 ≤55 行）：
  - `cub-warp-reduce`（51 行）
  - `cub-block-reduce`（52 行）
  - `cub-device-reduce`（37 行）
  - `cub-device-scan`（38 行）
  - `cub-device-sort`（46 行）
- LLM Operators 章节（8 examples，均符合 30-80 行约束）：
  - `online-softmax`（66 行）
  - `layer-norm`（72 行）
  - `rms-norm`（57 行）
  - `gelu-activation`（45 行）
  - `rope-embedding`（54 行）
  - `int8-quantization`（55 行）
  - `naive-attention`（66 行）
  - `flash-attention-tiling`（80 行）
- 其他新增：
  - `kernel-fusion`（59 行，bias+GELU 融合模式）
  - `cublas-batched-gemm`（59 行，`cublasSgemmBatched`）
- `tools/` 下 `go test ./...` 全绿

## 被削减的内容（范围削减）

- **R5（写样例验证）升级为必须项**：最终构建了全部 15 个新 examples，而非仅 1-2 个样例。
- 无功能性削减。所有塑形元素均已实现。

## 变更的文件

- `examples/examples.txt`（章节重组 + 15 个新条目）
- 新增 15 个 `examples/<id>/<id>.cu`：
  - `cub-warp-reduce`、`cub-block-reduce`、`cub-device-reduce`、`cub-device-scan`、`cub-device-sort`
  - `kernel-fusion`、`cublas-batched-gemm`
  - `online-softmax`、`layer-norm`、`rms-norm`、`gelu-activation`、`rope-embedding`、`int8-quantization`、`naive-attention`、`flash-attention-tiling`
- `.shapeup/004-feature-004-building/hillchart.md`（全部范围标记为 ✓）

## 出乎意料的内容

- `flash-attention-tiling` 初版 97 行，需要裁剪至 80 行：合并了 `cudaMalloc` 多行为单行、
  移除冗余注释与空行、内联 `m_tile` 计算进 score 循环。ADR 0007 的 80 行上限对
  包含 online softmax 的 tiling kernel 属于较紧约束，但通过精简样板代码可达。
- CUB 的 `DeviceReduce` / `DeviceScan` / `DeviceSort` 比预期更紧凑（均 ≤50 行），
  因 CUB 的 "temp storage query + allocate + execute" 模式本身只占 6-8 行。
- `naive-attention` 保持无 cuBLAS 依赖是对的决定：三个小 kernel（dotScores、softmaxRows、
  weightedSum）比调 cuBLAS + 一个 softmax kernel 更清晰，且更好地承接 `flash-attention-tiling`。
- 生成器（feature 002 ADR 0005）无需任何修改即可处理新章节 —— 纯数据变更完成整个功能。

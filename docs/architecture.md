# Architecture

Living record of architectural patterns, conventions, and decisions accumulated as features ship.

---

## CUDA by Example Site — S1 Generator (2026-04-09)

### Patterns Introduced

- **Fork-and-adapt**: Copy upstream gobyexample's `generate.go` into `tools/` and modify
  in place. Changes are subtractive (remove Go Playground, AWS S3) or additive (new functions).
  The core segment parser remains untouched. (ADR 0001)
- **Pre-processing pipeline**: Insert transformation passes before the segment parser
  rather than modifying parser internals. `normalizeBlockComments` is the first such pass.
  Future passes (e.g., CUDA-specific transformations) should follow this pattern. (ADR 0002)
- **Convention-over-configuration for examples**: Each example lives in `examples/<id>/<id>.cu`.
  The ordered list in `examples/examples.txt` drives navigation. No metadata files, no YAML
  frontmatter — the file structure IS the configuration.

### Data Model

- **Segment (`Seg`)**: A contiguous block of either documentation or code, parsed from a `.cu`
  file. Docs segments come from `//` comment lines (or pre-processed `/* */` blocks).
  Code segments are everything else. Each segment is rendered independently —
  docs through Blackfriday (Markdown→HTML), code through Chroma (C++→HTML).
- **Example**: An ordered entry in `examples.txt` mapping to `examples/<id>/<id>.cu`.
  Contains: `ID`, `Name`, `Segs[]`, `PrevExample`, `NextExample`.

### Key Files

| File | Role |
|------|------|
| `tools/generate.go` | Static site generator (forked from gobyexample) |
| `tools/build` | Shell script: runs generator, copies output to `public/` |
| `examples/examples.txt` | Ordered list of example IDs (drives navigation) |
| `examples/<id>/<id>.cu` | Annotated CUDA source files |
| `templates/*.tmpl` | HTML templates (index, example, footer, 404) |
| `templates/site.css` | Stylesheet (copied from gobyexample, modified) |
| `templates/site.js` | Keyboard navigation (← → arrow keys) |
| `go.mod` | Dependencies: chroma/v2, blackfriday/v2 |
| `vendor/gobyexample/` | Reference submodule (read-only) |

### Conventions Established

- **`-mod=mod` required**: All `go build` / `go run` commands must use `-mod=mod` because
  `vendor/` contains a git submodule, not Go vendored deps. (ADR 0004 — plan to rename
  to `upstream/` to eliminate this)
- **Annotation style**: Use `/* */` block comments for multi-line documentation blocks,
  `//` for single-line annotations. The pre-processor normalizes both to `//` before parsing.
- **Example naming**: Directory and file names must match (e.g., `vector-add/vector-add.cu`).
  Use kebab-case. The ID in `examples.txt` must match the directory name exactly.

### Known Limitations

- **No CUDA-specific syntax highlighting**: Chroma's C++ lexer covers ~95% of `.cu` syntax.
  CUDA keywords (`__global__`, `__shared__`) and launch syntax (`<<<>>>`) are not specially
  highlighted. Acceptable for v1. (ADR 0003)
- **No automated tests**: No diff-based test suite for generated output. Deferred to S5.
- **No CI/CD**: GitHub Pages deployment not yet configured. Deferred to S5.
- **`vendor/` naming conflict**: Will cause confusion for Go developers. Plan to rename
  to `upstream/`. (ADR 0004)

---

## NVIDIA Samples Migration (2026-04-18)

### Patterns Introduced

- **Chapter-aware parsing**: `examples.txt` supports `# Chapter Name` lines that group
  examples into chapters for the index page. The parser returns a dual result
  `([]*Example, []*Chapter)` — only `renderIndex` uses chapters; all other consumers
  operate on the flat example list. Backward compatible: no `#` lines → flat list. (ADR 0005)
- **Testable generator refactoring**: `parseExamples()` refactored into
  `parseExamplesFrom(txtPath, examplesDir)` to accept paths as arguments, enabling unit
  testing with `t.TempDir()`. The original function is now a thin wrapper. (ADR 0006)
- **Content conventions for CUDA examples**: 30-80 lines, self-contained, `//`-comment
  seg pattern, compile instructions in opening comments, verification output in `main()`,
  progressive chapter ordering. (ADR 0007)

### Data Model Changes

- **`Chapter` struct**: `Name string`, `Examples []*Example` — groups examples under a named
  heading. Produced by `parseExamplesFrom`, consumed by `renderIndex` via `indexData`.
- **`indexData` struct**: `Examples []*Example`, `Chapters []*Chapter` — passed to `index.tmpl`
  to support both grouped and flat rendering modes.

### Template Changes

- **`index.tmpl`**: Renders `{{range .Chapters}}` with `<div class="chapter"><h3>` containers.
  Falls back to `{{range .Examples}}` when `Chapters` is nil. Search JS hides empty chapter
  divs when filtering.
- **`site.css`**: Added `.chapter` and `.chapter h3` styles with dark mode support.

### Conventions Established

- **Chapter ordering in `examples.txt`**: Chapters follow a progressive learning path:
  Basics → Memory → Synchronization → Streams → Algorithms → Textures → Advanced → Performance → Libraries.
  New examples should be added to the appropriate chapter, not appended to the end.
- **Special compilation requirements**: Examples needing non-default `nvcc` flags (e.g.,
  `-arch=sm_70`, `-lcublas`, `-rdc=true`) document them in the opening comment block.
- **Generator test pattern**: Tests create temp directories with stub `.cu` files, call
  `parseExamplesFrom` with those paths, and assert on the returned data structures.

### Known Limitations

- **Chapter info not on example pages**: Individual example pages don't display which
  chapter they belong to. Only the index page shows chapter grouping.
- **No chapter-level navigation**: No "jump to next chapter" UI. Arrow keys navigate
  linearly across all examples regardless of chapter boundaries.
- **No CI for example line counts**: The 30-80 line convention is not enforced by automation.

---

## Code Syntax Highlighting (2026-04-18)

### Patterns Introduced

- **Vendored lexer extension**: CUDA-specific lexer behavior is added by editing the vendored
  Chroma XML file (`vendor/.../lexers/embedded/c++.xml`) rather than writing a new lexer.
  The `//go:embed` directive picks up changes automatically at compile time. Future language
  extensions should follow this pattern before considering a standalone lexer. (ADR 0003 updated)
- **GitHub theme via vendored styles**: Syntax highlight colors are sourced from Chroma's own
  vendored `styles/github.xml` and `styles/github-dark.xml`, then applied in `site.css` under
  `prefers-color-scheme` media queries. This keeps the palette in sync with the vendored Chroma
  version. (ADR 0008)

### Key Files Changed

| File | Change |
|------|--------|
| `vendor/.../lexers/embedded/c++.xml` | Added `*.cu`/`*.cuh` filenames; added CUDA keyword rule |
| `templates/site.css` | Replaced light+dark syntax colors with GitHub theme (17 classes each) |
| `tools/generate_test.go` | Added 4 syntax highlighting tests |

### Conventions Established

- **CUDA keyword tokenization**: `__global__`, `__device__`, `__host__`, `__shared__`,
  `__constant__`, `__managed__`, `__restrict__`, `__noinline__`, `__forceinline__`,
  `__launch_bounds__` are tokenized as `KeywordReserved` (`kr` CSS class). The regex uses
  explicit enumeration to avoid false matches on `__cplusplus`, `__LINE__`, etc.
- **Syntax highlight test pattern**: Tests call `chromaFormat(code, "test.cu")` and assert
  on CSS class presence in the rendered HTML string. Lexer registration is tested separately
  via `cudaLexer()` asserting `cfg.Name == "C++"`.
- **17 token classes**: The canonical set of Chroma CSS classes used by C++/CUDA output is:
  `k`, `kt`, `kr`, `kd`, `nc`, `nf`, `o`, `p`, `s`, `sa`, `se`, `mi`, `mb`, `c`, `cm`,
  `cp`, `cpf`. Any future theme change should cover all 17.

### Known Limitations

- **`<<<>>>` not specially highlighted**: CUDA kernel launch syntax tokenizes as 6 individual
  Operator tokens. Acceptable — they render with operator color, which is visually distinct.
- **CUDA built-in variables not highlighted**: `threadIdx.x`, `blockDim.x`, etc. stay as
  generic `Name` tokens. Standard behavior per GitHub theme; no special color.
- **No theme toggle**: Only `prefers-color-scheme` auto-detection. A manual toggle was
  explicitly deferred as out of scope.

---

## LLM Operators Chapter Design (2026-04-21)

### What Was Added

56 total examples across 11 chapters (up from 41 examples, 9 chapters). Two new chapters
inserted, one chapter moved, two existing chapters extended.

### Chapter Ordering — Learning Path Rationale

| # | Chapter | Examples | Role in path |
|---|---------|----------|--------------|
| 1 | Basics | 6 | Entry point: threads, grids, device query |
| 2 | Memory Management | 6 | Core memory hierarchy: shared, unified, pinned, constant |
| 3 | Synchronization | 4 | Atomics, warp shuffles, cooperative groups |
| 4 | Streams and Concurrency | 4 | Overlap, pipelines, async execution |
| 5 | Parallel Algorithms | 6 | Reduction, scan, sort, matrix ops — the building blocks |
| 6 | **CUB Library** | 5 | NVIDIA's official primitives — same ops as ch.5, zero boilerplate |
| 7 | Advanced Kernel Techniques | 6 | Dynamic parallelism, occupancy, tensor cores, kernel fusion |
| 8 | Performance Optimization | 4 | Bank conflicts, ILP, memory access patterns |
| 9 | **LLM Operators** | 8 | Softmax → LayerNorm → RMSNorm → GELU → RoPE → INT8 → Attention |
| 10 | Libraries | 4 | Thrust, cuBLAS (single + batched), cuRAND |
| 11 | Textures and Surfaces | 3 | Legacy / specialist API — useful but not on the main path |

**Textures moved to last**: Texture memory is rarely used in modern LLM/ML workloads.
Moving it to position 11 removes it from the critical learning path without deleting it.

**CUB positioned after Parallel Algorithms**: Readers implement reduction/scan manually
first (ch.5), then see how CUB abstracts the same operations (ch.6). CUB then serves
as a prerequisite for understanding CUB-based patterns inside LLM kernels.

**Kernel Fusion added to Advanced Kernel Techniques** (before LLM Operators): The
bias+activation fusion pattern is the simplest real-world kernel fusion, preparing
readers for the fused online-softmax loops in FlashAttention.

### Reference Repositories

Sources referenced from `.cu` opening comments. Each URL points to the folder or file
most relevant to the concept taught.

| Example | Concept | Repository URL |
|---------|---------|----------------|
| `cub-warp-reduce` | CUB WarpReduce | https://github.com/NVIDIA/cccl/tree/main/cub/cub/warp |
| `cub-block-reduce` | CUB BlockReduce | https://github.com/NVIDIA/cccl/tree/main/cub/cub/block |
| `cub-device-reduce` | CUB DeviceReduce | https://github.com/NVIDIA/cccl/tree/main/cub/cub/device |
| `cub-device-scan` | CUB DeviceScan | https://github.com/NVIDIA/cccl/tree/main/cub/cub/device |
| `cub-device-sort` | CUB DeviceSort (radix sort) | https://github.com/NVIDIA/cccl/tree/main/cub/cub/device |
| `kernel-fusion` | Fused bias+activation | https://github.com/NVIDIA/Megatron-LM/blob/main/megatron/core/fusions |
| `cublas-batched-gemm` | `cublasSgemmBatched` | https://github.com/NVIDIA/CUDALibrarySamples/tree/master/cuBLAS |
| `online-softmax` | Online softmax (1-pass) | https://github.com/Dao-AILab/flash-attention |
| `layer-norm` | LayerNorm CUDA kernel | https://github.com/NVIDIA/apex/tree/master/csrc |
| `rms-norm` | RMSNorm (LLaMA-style) | https://github.com/meta-llama/llama/blob/main/llama/model.py |
| `gelu-activation` | Fused bias+GELU | https://github.com/NVIDIA/Megatron-LM/blob/main/megatron/core/fusions/fused_bias_gelu.py |
| `rope-embedding` | RoPE (apply_rotary_emb) | https://github.com/meta-llama/llama/blob/main/llama/model.py |
| `int8-quantization` | INT8 quantization kernels | https://github.com/TimDettmers/bitsandbytes |
| `naive-attention` | Attention kernels | https://github.com/NVIDIA/TensorRT-LLM |
| `flash-attention-tiling` | FlashAttention tiling | https://github.com/Dao-AILab/flash-attention |

### Excluded Topics (No-Gos)

| Topic | Reason |
|-------|--------|
| FlashAttention v2 full implementation | 200+ lines; `flash-attention-tiling` covers the core idea |
| Multi-head attention | Requires multi-kernel coordination; exceeds single-file constraint |
| PagedAttention / KV cache | System-level; see vLLM: https://github.com/vllm-project/vllm |
| cuDNN Basics | Initialization boilerplate dominates; cuBLAS path is cleaner |
| INT4 / FP8 quantization | Requires H100+; audience too narrow |
| Speculative decoding | System-level scheduling; out of scope |

### Conventions Established

- **`Source:` as Markdown link**: Opening comments use `[display](url)` format so
  blackfriday renders them as clickable `<a>` tags on example pages.
- **CUB chapter intro in first example**: `cub-warp-reduce.cu` carries the chapter-level
  CUB explanation. The other four `cub-*.cu` files each include a one-liner definition.
  This avoids needing a generator-level chapter description feature.
- **LLM operator ordering**: online-softmax → layer-norm → rms-norm → gelu → rope →
  int8 → naive-attention → flash-attention-tiling. Each builds on the previous:
  softmax is used in attention; LayerNorm before RMSNorm (simpler variant); GELU
  before naive attention (activation used in FFN); attention before flash-attention.

# Package: CUDA by Example Site

**Feature ID**: 001
**Created**: 2026-04-09
**Frame**: [frame.md](frame.md)
**Time Budget**: Big Batch — 4-5 sessions
**Status**: Shaping

---

## Problem

A developer wanting to learn CUDA today has to triangulate between nvidia/cuda-samples
(working code, zero explanation), dense NVIDIA documentation, and scattered blog posts.
There is no single site that shows annotated `.cu` code side-by-side with plain-English
explanation — the format that made gobyexample.com the canonical Go quick-reference.

## Time Budget

Big Batch — 4-5 sessions

| Session | Scope |
|---------|-------|
| S1 | Repo setup + Go generator (fork generate.go, adapt for .cu, /* */ pre-processing, updated templates) |
| S2 | First batch of examples: CUDA basics (hello world, device info, vector add, thread indexing, 2D grid) |
| S3 | Memory examples: global, shared, unified memory, pinned memory |
| S4 | Streams, async copy, atomics, warp primitives |
| S5 | Buffer: polish, GitHub Actions CI/CD to GitHub Pages, public launch prep |

## Requirements (R)

| ID | Requirement | Status |
|----|-------------|--------|
| R0 | Annotated `.cu` files parsed into two-column docs+code HTML pages | Core goal |
| R1 | Navigation: index page + prev/next links + keyboard arrow keys | Must |
| R2 | Go generator forked from gobyexample, adapted for `.cu` + `/* */` pre-processing | Must |
| R3 | First batch of CUDA basics examples (5-8 examples) | Must |
| R4 | Intermediate examples batch (memory, streams, atomics) | Optional |
| R5 | GitHub Pages deployment via GitHub Actions | Optional |
| R6 | Client-side search | Optional |

---

## Solution

Fork gobyexample's `generate.go` into our `tools/` directory, strip the Go Playground
and AWS S3 upload code, add a `/* */` → `//` pre-processing pass, and point the Chroma
lexer at `.cu` files using the C++ lexer. Add `mmcgrana/gobyexample` as a git submodule
for reference — we copy their CSS and templates as a starting point and modify them.
Write annotated `.cu` example files; `examples.txt` defines the order.

---

### Element: Git submodule (gobyexample reference)

**What**: `mmcgrana/gobyexample` added as a git submodule at `vendor/gobyexample/`
**Where**: repo root — `git submodule add https://github.com/mmcgrana/gobyexample vendor/gobyexample`
**Wiring**: Not imported as a Go library. Used as a file reference: `tools/generate.go` is a
modified copy of `vendor/gobyexample/tools/generate.go`; `templates/` starts as a copy of
`vendor/gobyexample/templates/` with CUDA-specific edits.
**Affected code**: `vendor/gobyexample/` (read-only submodule), `tools/generate.go`, `templates/`
**Complexity**: Low
**Status**: ✅ Verified — submodule approach confirmed, no Go import needed

---

### Element: `/* */` pre-processing pass

**What**: A function `normalizeBlockComments(lines []string) []string` that runs before
`parseSegs`. Converts standalone block comment lines to `//` lines so the existing
segment parser handles them without modification.

**Rules**:
1. A line where `/*` is the first non-whitespace token → start of a block comment block.
   Strip `/*`, emit as `// <content>`.
2. Lines inside a block comment (no leading `/*` or `*/`) → strip leading ` * ` if present,
   emit as `// <content>`.
3. A line containing only `*/` (possibly with whitespace) → end of block comment, emit nothing.
4. A line with code followed by `/* comment */` inline → leave untouched (stays as code segment).
   The inline comment will appear in the syntax-highlighted code block.
5. String literals containing `/*` or `*/` → not a concern for `.cu` annotation files
   (annotations are top-level comments, not inside string literals).

**Where**: `tools/generate.go` — new function called at the top of `parseSegs`
**Wiring**: `parseSegs(sourcePath)` calls `normalizeBlockComments(lines)` before the
existing `docsPat` regex loop. No changes to `docsPat` or the segment loop itself.
**Affected code**: `tools/generate.go` — one new function (~30 lines), one call site
**Complexity**: Low
**Status**: ✅ Verified — rules cover all annotation use cases; inline `/* */` on code lines
intentionally left as code (correct behavior)

#### Place: `tools/generate.go`

**Code affordances:**
| Affordance | Type | Wires to | Returns |
|------------|------|----------|---------|
| `normalizeBlockComments(lines []string) []string` | function | called by `parseSegs` | normalized `[]string` |
| `parseSegs(sourcePath string)` | function (modified) | calls `normalizeBlockComments`, then existing `docsPat` loop | `[]*Seg, string` |
| `whichLexer(path string)` | function (modified) | add `.cu` → `"cpp"` case | lexer name string |

---

### Element: Go generator (`tools/generate.go`)

**What**: Fork of `vendor/gobyexample/tools/generate.go` with these diffs:
1. Remove Go Playground integration: delete `URLHash`, `GoCodeHash`, `CodeRun`, `CodeForJs`,
   `resetURLHashFile`, `parseHashFile`, and the `.hash` file logic in `parseExamples`
2. Remove AWS S3 upload: delete `tools/upload` and its imports from `go.mod`
3. Add `normalizeBlockComments` (see above)
4. `whichLexer`: add `".cu"` → `"cpp"` (Chroma's C++ lexer handles CUDA syntax)
5. `parseExamples`: glob for `*.cu` instead of `*.go` and `*.sh`
6. Templates: update title/branding to "CUDA by Example"

**Where**: `tools/generate.go` (new file, ~200 lines)
**Wiring**: reads `examples/examples.txt` → reads `examples/<id>/<id>.cu` → renders
`templates/index.tmpl` + `templates/example.tmpl` → writes `public/`
**Affected code**: `tools/generate.go`, `go.mod` (remove AWS SDK deps), `templates/*.tmpl`
**Complexity**: Low — mostly deletion from the original
**Status**: ✅ Verified — gobyexample source fully read; all changes are subtractive or
additive in isolated functions

#### Place: `examples/<id>/<id>.cu`

**UI affordances (rendered output):**
| Affordance | Type | Wires to | Returns |
|------------|------|----------|---------|
| Left column | docs panel | `DocsRendered` (Markdown → HTML) | explanation text |
| Right column | code panel | `CodeRendered` (Chroma C++ → HTML) | syntax-highlighted CUDA |
| Prev/Next links | navigation | `PrevExample.ID` / `NextExample.ID` | adjacent example page |
| ← → keyboard | JS in template | `window.location.href` | navigate between examples |

**Code affordances:**
| Affordance | Type | Wires to | Returns |
|------------|------|----------|---------|
| `parseExamples()` | function | reads `examples.txt`, globs `*.cu` | `[]*Example` |
| `parseAndRenderSegs(path)` | function | `normalizeBlockComments` → `parseSegs` → Chroma | `[]*Seg, string` |
| `renderIndex(examples)` | function | `templates/index.tmpl` | `public/index.html` |
| `renderExamples(examples)` | function | `templates/example.tmpl` | `public/<id>` (no extension) |

---

### Element: `examples/` — first batch (S2)

**What**: 5-8 annotated `.cu` files covering CUDA basics. Written from scratch (not copied
from nvidia/cuda-samples — their code has too much boilerplate). nvidia/cuda-samples used
as correctness reference only.

**Curriculum (S2):**
1. `hello-world` — `printf` from a kernel, `<<<1,1>>>` launch syntax
2. `device-info` — `cudaGetDeviceProperties`, reading GPU specs
3. `vector-add` — 1D grid/block, `threadIdx`, `blockIdx`, `blockDim`, memory copy
4. `thread-indexing` — visualizing global thread ID calculation
5. `2d-grid` — `threadIdx.x/y`, `blockIdx.x/y`, 2D problem mapping

**Where**: `examples/<id>/<id>.cu` — one directory per example
**Wiring**: `examples.txt` lists them in order; generator picks them up automatically
**Affected code**: new files only
**Complexity**: Medium — requires correct CUDA code + clear annotations
**Status**: ✅ Verified — annotation format confirmed from gobyexample source study;
Chroma C++ lexer handles CUDA keywords adequately for v1

---

### Element: `go.mod` + build tooling

**What**: Minimal `go.mod` — keep only `chroma/v2` and `blackfriday/v2`, drop AWS SDK.
`tools/build` shell script copied from gobyexample and simplified (remove `tools/test`,
`tools/format`, `tools/measure` for now — add back in S5 if needed).

**Where**: `go.mod`, `go.sum`, `tools/build`
**Wiring**: `go build ./tools/generate.go` produces the generator binary; `tools/build`
runs it and copies output to `public/`
**Affected code**: `go.mod` (new), `tools/build` (new, ~15 lines)
**Complexity**: Low
**Status**: ✅ Verified — go.mod deps confirmed from gobyexample source

---

## Fit Check (R × Solution)

| | Submodule | `/* */` pre-proc | Generator | Examples S2 | go.mod + build |
|---|---|---|---|---|---|
| R0: annotated .cu → HTML | | ✅ | ✅ | ✅ | ✅ |
| R1: navigation | | | ✅ | | |
| R2: Go generator + /* */ | ✅ | ✅ | ✅ | | ✅ |
| R3: first examples batch | | | | ✅ | |
| R4: intermediate examples | | | | (S3-S4) | |
| R5: GitHub Pages CI | | | | | (S5) |
| R6: search | | | | | (S5) |

Every R0–R3 row has ≥1 ✅. R4–R6 are optional, scoped to later sessions.

---

## Rabbit Holes

- **Chroma C++ lexer missing CUDA keywords** (`__global__`, `__shared__`, `<<<>>>`):
  Chroma's C++ lexer won't specially highlight CUDA execution configuration syntax.
  Decision: acceptable for v1 — code is still readable and highlighted as C++.
  A custom Chroma lexer can be added in S5 if it matters.

- **`/* */` inside string literals**: A `.cu` annotation file could theoretically have
  `printf("/* not a comment */")` which the pre-processor would mishandle.
  Decision: annotation files are author-controlled. Convention: use `//` for all
  annotations; `/* */` only appears in code blocks where it's inline (rule 4 above).
  Document this in the contributor guide.

- **gobyexample submodule vs. copy**: We can't `import` their Go code as a library
  (different module path). The submodule is reference-only — we copy and modify files.
  Decision: copy `generate.go` into `tools/` at project init; submodule stays for
  diffing/updating reference. This is clean and explicit.

- **No `tools/test` in S1**: gobyexample's test script compares generated output against
  committed `public/`. We skip this for S1-S4 (no committed public/ yet).
  Decision: add `TESTING` mode in S5 when the site is stable enough to commit `public/`.

- **`.cu` files won't compile standalone** (need CUDA toolkit): The generator only reads
  and parses `.cu` files as text — it never compiles them. No CUDA toolkit needed to
  build the site. LSP (clangd) works independently in the editor.

---

## Appetite

Big Batch — 4-5 sessions (fixed time, variable scope).

## No-Gos

- No Go Playground integration (CUDA can't run in browser)
- No AWS S3 upload (GitHub Pages instead)
- No custom CUDA Chroma lexer in v1
- No automated test suite until S5
- No verbatim nvidia/cuda-samples code (too much boilerplate)

---

## Exclusions

- **Go Playground integration**: CUDA can't run in a browser. Removed entirely.
- **AWS S3 upload**: We use GitHub Pages. AWS SDK removed from go.mod.
- **`tools/test`, `tools/format`, `tools/measure`**: Deferred to S5. Not needed to ship S1.
- **Custom CUDA Chroma lexer**: Deferred to S5. C++ lexer is sufficient for v1.
- **nvidia/cuda-samples code verbatim**: Their examples have too much boilerplate for
  a learning site. We write our own annotated `.cu` files, using their code as a
  correctness reference only.
- **Search (R6)**: Optional, scoped to S5.

---

## Technical Validation

**Key files reviewed**:
- `mmcgrana/gobyexample/tools/generate.go` — full source read ✅
- `mmcgrana/gobyexample/templates/index.tmpl` — full source read ✅
- `mmcgrana/gobyexample/templates/example.tmpl` — full source read ✅
- `mmcgrana/gobyexample/templates/footer.tmpl` — full source read ✅
- `mmcgrana/gobyexample/go.mod` — deps confirmed ✅
- `mmcgrana/gobyexample/tools/build` — build script read ✅
- `nvidia/cuda-samples/Samples/0_Introduction/vectorAdd/vectorAdd.cu` — structure confirmed ✅

**Verified approach**: gobyexample's segment parser uses `//` regex line-by-line.
CUDA uses the same `//` syntax. The only addition is the `/* */` pre-processing pass,
which is isolated and doesn't touch the existing parser logic. Chroma C++ lexer confirmed
available in `chroma/v2`. All changes to `generate.go` are either deletions (Playground,
S3) or additions in new isolated functions.

**All flagged unknowns resolved**: Zero open items. All rabbit holes patched or scoped out.

**Test strategy**: S1 ends with `tools/build` producing a valid `public/` directory
with at least one rendered example. Visual inspection in browser. Automated diff-based
testing deferred to S5.

---

## Status: Shape Go — approved 2026-04-09

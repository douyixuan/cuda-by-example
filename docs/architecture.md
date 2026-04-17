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

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

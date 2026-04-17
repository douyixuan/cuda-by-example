# Build Summary — CUDA by Example Site

**Feature ID**: 001
**Build sessions**: 1 (S1)
**Completed**: 2026-04-09

## What was built
- `tools/generate.go` — Go static site generator forked from gobyexample, adapted for `.cu` files
- `normalizeBlockComments()` — pre-processing pass converting `/* */` blocks to `//` lines
- `templates/` — index, example, 404, footer templates + CSS/JS/favicon from gobyexample
- `tools/build` — shell script that runs the generator and copies output to `public/`
- `go.mod` / `go.sum` — minimal deps: chroma/v2 + blackfriday/v2
- `vendor/gobyexample` — git submodule for reference
- 5 annotated `.cu` examples: Hello World, Device Info, Vector Add, Thread Indexing, 2D Grid
- `examples/examples.txt` — ordered example list

## What was cut (scope hammering)
- Nothing cut from S1 — all must-haves delivered

## Key files added/modified
- `tools/generate.go` (new)
- `tools/build` (new)
- `go.mod`, `go.sum` (new)
- `templates/index.tmpl`, `example.tmpl`, `footer.tmpl`, `404.tmpl` (new)
- `templates/site.css`, `site.js`, `favicon.ico` (copied from submodule)
- `examples/examples.txt` (new)
- `examples/hello-world/hello-world.cu` (new)
- `examples/device-info/device-info.cu` (new)
- `examples/vector-add/vector-add.cu` (new)
- `examples/thread-indexing/thread-indexing.cu` (new)
- `examples/2d-grid/2d-grid.cu` (new)

## Surprises
- `go mod tidy` stripped deps before any `.go` source existed — had to write generate.go first
- The `vendor/` directory name conflicts with Go's vendoring convention; used `-mod=mod` flag
  in `tools/build` to bypass. Consider renaming submodule dir to `upstream/` in S2.
- Chroma's C++ lexer handles `<<<>>>` syntax as operators — readable but not specially highlighted.
  Acceptable for v1.

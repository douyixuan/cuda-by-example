# Decisions Made — CUDA by Example Site

**Feature ID**: 001
**Shipped**: 2026-04-16
**Appetite**: Big Batch — 4-5 sessions
**Actual effort**: 1 build session (S1 — generator + first 5 examples)

## Key Architectural Decisions

- **Fork gobyexample generator** (ADR 0001): Copy and modify `generate.go` rather than
  building from scratch or importing as a library. Subtractive changes (remove Playground,
  S3) plus additive changes (block comment pre-processing, `.cu` support).
- **Block comment pre-processing** (ADR 0002): `normalizeBlockComments` converts `/* */`
  to `//` before the segment parser runs, keeping the parser untouched.
- **C++ lexer for CUDA highlighting** (ADR 0003): Reuse Chroma's C++ lexer. Good enough
  for v1 — custom CUDA lexer deferred.
- **`vendor/` submodule naming** (ADR 0004): Known conflict with Go vendoring. Workaround:
  `-mod=mod` flag. Plan to rename to `upstream/` later.

## What Was Cut (Scope Hammering)

- Nothing cut from S1 — all must-haves delivered within a single session.
- S2–S5 scopes (intermediate examples, advanced examples, CI/CD, search, automated tests)
  remain as future sessions per the original appetite.

## What Surprised Us

- `go mod tidy` fails when run before any `.go` source exists — had to write `generate.go`
  first, then run `go mod tidy`. Minor sequencing issue.
- `vendor/` directory name clashes with Go's vendoring convention, requiring `-mod=mod`.
  Not anticipated during shaping. Should rename to `upstream/` in a future session.
- Chroma's C++ lexer handles `<<<>>>` as operators — better than expected. No custom
  tokenization needed for v1 readability.

## Future Improvement Areas

- **Rename `vendor/` → `upstream/`**: Eliminate the Go vendoring conflict and `-mod=mod`
  requirement.
- **Custom CUDA Chroma lexer**: Properly highlight `__global__`, `__shared__`, `<<<>>>`.
  The `whichLexer` function is the single integration point.
- **Automated test suite**: Diff-based testing of generated `public/` output against
  committed baseline.
- **GitHub Pages CI/CD**: GitHub Actions workflow for automatic deployment on push.
- **More examples**: S2 (memory), S3 (streams/atomics), S4 (advanced) per the package plan.

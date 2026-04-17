# ADR 0006: Testable Generator Refactoring

**Status**: Accepted
**Date**: 2026-04-18
**Feature**: 002 — NVIDIA Samples Migration

## Context

The original `parseExamples()` was a zero-argument function that hardcoded the path `"examples/examples.txt"` and the directory `"examples/"`. This made unit testing impossible without creating files at those exact locations — the generator had no test suite at all (noted as a known limitation in Feature 001).

## Decision

Refactor `parseExamples()` into `parseExamplesFrom(txtPath, examplesDir string)` that accepts paths as arguments. The original `parseExamples()` becomes a thin wrapper calling `parseExamplesFrom("examples/examples.txt", "examples")`.

Tests use `t.TempDir()` to create isolated example directories with minimal `.cu` files, enabling fast, parallel, side-effect-free testing.

## Rationale

- **Zero behavior change**: The wrapper ensures all production call sites work identically
- **Standard Go testing pattern**: Accept dependencies as arguments rather than hardcoding them
- **Enables TDD for future changes**: Any modification to parsing logic now has a safety net

## Alternatives Considered

- **Interface-based dependency injection**: Rejected — over-engineered for a single-file generator. The function-argument approach is simpler and idiomatic for Go scripts.
- **Test with real example files in-repo**: Rejected — tests would break whenever examples change, and would be slow due to Chroma rendering.

## Consequences

**Positive**:
- First test suite for the generator: 3 tests covering chapters, backward compatibility, and pointer integrity
- Tests run in <1s with no external dependencies
- Future generator changes can be developed with TDD

**Negative / Trade-offs**:
- Test `.cu` files are minimal stubs (`// test\nint main() { return 0; }`) — they don't exercise Chroma rendering or segment parsing edge cases

**Future considerations**:
- Add integration tests that run the full generator and diff against golden output files
- Add segment parsing tests for edge cases (empty files, comment-only files, mixed block/line comments)

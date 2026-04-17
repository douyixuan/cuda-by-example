# ADR 0003: Use Chroma C++ Lexer for CUDA Syntax Highlighting

**Status**: Accepted
**Date**: 2026-04-09
**Feature**: 001 — CUDA by Example Site

## Context

CUDA `.cu` files are a superset of C++ with additional keywords (`__global__`, `__shared__`,
`__device__`) and syntax (`<<<blocks, threads>>>`). Chroma does not have a dedicated CUDA
lexer. We needed syntax highlighting for `.cu` code segments.

## Decision

Map `.cu` files to Chroma's C++ lexer via `whichLexer`. The C++ lexer handles standard
C++ syntax, keywords, operators, strings, and comments. CUDA-specific tokens like
`__global__` render as identifiers and `<<<>>>` renders as operators — readable but
not semantically highlighted.

## Rationale

A custom CUDA lexer would require understanding Chroma's lexer API, writing and testing
token rules for all CUDA-specific constructs, and maintaining it as Chroma evolves.
The C++ lexer produces acceptable output for v1 — code is readable and most syntax
is correctly highlighted. The marginal improvement from custom highlighting doesn't
justify the effort within the S1 appetite.

## Alternatives Considered

- **Custom Chroma CUDA lexer**: Correct highlighting for all CUDA tokens, but estimated
  at 1-2 sessions of work (lexer definition + testing + integration). Out of appetite for S1.
- **Use a different highlighter (Pygments, tree-sitter)**: Would require replacing Chroma
  entirely. Pygments has a CUDA lexer but isn't a Go library. Too disruptive.
- **No syntax highlighting**: Unacceptable — code readability is core to the site's value.

## Consequences

**Positive**:
- Zero custom lexer code to write or maintain
- Chroma C++ lexer is well-tested and handles 95%+ of `.cu` syntax correctly
- Shipped in S1 without blocking on lexer development

**Negative / Trade-offs**:
- `__global__`, `__shared__`, `__device__` are not highlighted as keywords
- `<<<>>>` kernel launch syntax has no special highlighting
- May look less polished than a purpose-built CUDA highlighter

**Future considerations**:
- A custom CUDA lexer can be added in S5 or later if the highlighting gap matters
  enough to users. The `whichLexer` function is the single integration point.

# ADR 0001: Fork gobyexample Generator Instead of Building from Scratch

**Status**: Accepted
**Date**: 2026-04-09
**Feature**: 001 — CUDA by Example Site

## Context

We needed a static site generator that parses annotated `.cu` source files and renders
two-column docs+code HTML pages — the exact format that gobyexample.com uses for Go.
Building this from scratch would mean reimplementing segment parsing, Chroma integration,
template rendering, and navigation logic that already exists in a proven ~200-line Go program.

## Decision

Copy `mmcgrana/gobyexample/tools/generate.go` into `tools/generate.go` and modify it
in place. Changes are subtractive (remove Go Playground, AWS S3 upload) and additive
(add `normalizeBlockComments`, `.cu` file globbing, C++ lexer mapping). The original
segment parser and template rendering logic remain untouched.

## Rationale

The gobyexample generator is small (~200 lines), well-structured, and battle-tested
(8.1k stars, 8 translations). Forking it lets us ship S1 in a single session while
inheriting a proven architecture. The changes are isolated — the core parsing loop
didn't need modification.

## Alternatives Considered

- **Build from scratch**: Full control, but would take 2-3x longer for the same result.
  The segment parser + Chroma pipeline is non-trivial to get right.
- **Import as Go library**: gobyexample isn't designed as a library (no exported API,
  different module path). Would require upstream changes we don't control.
- **Use a general-purpose SSG (Hugo, Jekyll)**: Would require extensive custom plugin
  work to achieve the two-column annotated format. More complexity, not less.

## Consequences

**Positive**:
- S1 delivered in a single session — generator working with 5 examples
- Inherits gobyexample's proven CSS, JS keyboard navigation, and template structure
- Low maintenance surface — most of the code is unchanged upstream logic

**Negative / Trade-offs**:
- Diverges from upstream over time — manual effort to incorporate gobyexample improvements
- Templates and CSS are copied, not linked — changes must be applied manually

**Future considerations**:
- If gobyexample makes significant generator improvements, a manual diff/merge may be worthwhile
- Custom CUDA-specific features (e.g., kernel launch syntax highlighting) will further
  diverge from the upstream base

# ADR 0009: Content-Only Chapter Extension

**Status**: Accepted
**Date**: 2026-04-21
**Feature**: 004 — LLM Operators Chapter Design

## Context

The site needed two new chapters (CUB Library, LLM Operators) plus extensions to two
existing chapters (Advanced Kernel Techniques, Libraries), totalling 15 new examples.
The chapter-aware generator had already been built in feature 002 (ADR 0005): it reads
`# Chapter Name` lines from `examples.txt` and groups examples accordingly.

The question was whether adding 15 new examples across 2 new chapters required any changes
to the generator, templates, or build pipeline — or whether the existing data-driven
architecture could absorb new chapters purely as content changes.

## Decision

Add all new chapters and examples exclusively through:
1. Editing `examples/examples.txt` — insert new `# Chapter Name` headers and example names
2. Adding new `examples/<id>/<id>.cu` files — one directory per example

Zero changes to `tools/generate.go`, `templates/`, or `tools/build`.

## Rationale

The feature 002 architecture was explicitly designed for this: the generator treats
`examples.txt` as its sole configuration source, and each `# Chapter Name` line
automatically creates a chapter group. The 30-80 line self-contained `.cu` convention
(ADR 0007) means each new example is fully independent.

This approach proved out the "convention-over-configuration" investment: adding 15 new
examples across 2 new chapters required only content files, no code changes.

## Alternatives Considered

- **Generator-level chapter descriptions**: Add a `description:` metadata block after
  each `# Chapter Name` line, parse it in the generator, and render it in `index.tmpl`.
  Rejected — not needed for this feature; the CUB chapter intro was handled by expanding
  `cub-warp-reduce.cu`'s opening comment (see "first-example intro" pattern below).
- **Separate metadata files per chapter**: A `chapters/cub-library.md` with description,
  icon, etc. Rejected — over-engineered for the current use case; adds a new file type
  and parser without clear benefit.

## Consequences

**Positive**:
- Zero generator changes means zero risk of breaking existing 41 examples
- Adding future chapters requires only content files — the contribution barrier is minimal
- Validates the feature 002 architecture investment at scale (2→11 chapters)

**Negative / Trade-offs**:
- No way to add a chapter-level description visible on the index page without a generator
  change; the current approach puts the intro in the first example's opening comment
- Reordering chapters requires editing `examples.txt` by hand — no drag-and-drop UI

**Patterns Established**:
- **First-example chapter intro**: When a new chapter needs an introductory explanation,
  expand the opening comment of the chapter's first example to carry it. For CUB:
  `cub-warp-reduce.cu` explains what CUB is, its three-level architecture (Warp/Block/Device),
  and the relationship between the 5 examples in the chapter.

**Future Considerations**:
- If the index page needs per-chapter descriptions (e.g., "CUB Library — NVIDIA's official
  GPU primitives"), that would require a generator change: parse a `## description:` line
  after `# Chapter Name`, add `Description string` to the `Chapter` struct, and render it
  in `index.tmpl`. A natural next step when the site grows beyond ~15 chapters.

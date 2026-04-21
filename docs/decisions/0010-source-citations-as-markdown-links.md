# ADR 0010: Source Citations as Markdown Links

**Status**: Accepted
**Date**: 2026-04-21
**Feature**: 004 — LLM Operators Chapter Design

## Context

The 15 new examples (CUB, LLM operators) are derived from or inspired by real production
codebases: Dao-AILab/flash-attention, NVIDIA/apex, meta-llama/llama, TimDettmers/bitsandbytes,
etc. Readers wanting to study the production implementations need a traceable path from the
simplified teaching example to the real source.

The `.cu` files already carry a `// Source:` comment line (established informally during
feature 004 build). The question was: plain URL text, or a format that renders as a
clickable link on the site?

## Decision

Write `Source:` lines using Markdown link syntax inside `//` comments:

```c
// Source: [github.com/Dao-AILab/flash-attention](https://github.com/Dao-AILab/flash-attention) — flash_fwd_kernel.h
```

The site generator passes `//` comment content through Blackfriday (Markdown→HTML).
Blackfriday renders `[text](url)` as `<a href="url">text</a>`, so the link becomes
clickable on the example page with no template or generator changes.

## Rationale

- Zero generator changes required — Blackfriday already handles Markdown in docs segments
- Readers get a one-click path to the production source
- The display text can be the short repo name while the href is the full URL + file path,
  keeping the rendered comment readable

## Alternatives Considered

- **Plain URL in comment**: `// Source: https://github.com/...`. Renders as plain text,
  not clickable. Sufficient for copy-paste but worse UX.
- **Separate `references.md` file**: List all source URLs in a standalone document, not
  in `.cu` files. Rejected — decouples the citation from the example; easy to drift out
  of sync as examples evolve.
- **HTML `<a>` tag in comment**: Would be passed through Blackfriday's HTML rendering mode.
  Rejected — Blackfriday's default mode sanitizes raw HTML; Markdown links are cleaner.

## Consequences

**Positive**:
- One-click source traceability for all 15 new examples
- Convention is self-documenting — future example authors see the pattern in existing files
- No generator changes; works with the existing Markdown-in-comments pipeline

**Negative / Trade-offs**:
- Authors must write `[display](url)` syntax in a C comment, which looks unusual
- Markdown special characters in URL paths (e.g., `_`) must be escaped as `\_` to prevent
  Blackfriday from italicizing them (e.g., `flash\_fwd\_kernel.h`)

**Convention**:
- All new examples with a production source reference should include a `// Source: [...](...)`
  line in the opening comment block, before the `// Compile:` line
- The display text should be the short `owner/repo` form; the href the full URL to the
  most relevant file or directory

**Future Considerations**:
- A linter could check that new `.cu` files in the LLM Operators and CUB chapters include
  a `Source:` line — currently unenforced

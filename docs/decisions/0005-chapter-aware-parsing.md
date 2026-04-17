# ADR 0005: Chapter-Aware Parsing with Backward Compatibility

**Status**: Accepted
**Date**: 2026-04-18
**Feature**: 002 — NVIDIA Samples Migration

## Context

With 41 examples spanning beginner to advanced topics, a flat list became unnavigable. The `examples.txt` format needed grouping without breaking existing linear navigation (prev/next arrow keys) or the search index pipeline.

The original `parseExamples` already filtered out `#`-prefixed lines (line 229: `!strings.HasPrefix(line, "#")`), silently discarding them. This was an accidental hook for chapter support.

## Decision

Extend `parseExamples` to capture `# ` lines as chapter headings instead of discarding them. Return a dual result: `([]*Example, []*Chapter)`. Only `renderIndex` receives the chapter grouping; all other consumers (`renderExamples`, `writeSearchIndex`, prev/next linking) continue to operate on the flat example slice.

When no `# ` headers exist in `examples.txt`, `chapters` is `nil` and the index template falls back to flat list rendering — full backward compatibility.

## Rationale

- **Minimal blast radius**: Only `renderIndex` and `index.tmpl` know about chapters. The example rendering pipeline, search index, and keyboard navigation are untouched.
- **Reuse existing syntax**: The `#` prefix was already parsed (and discarded). Converting from "discard" to "capture" required ~20 lines of changes.
- **Linear linking preserved**: `PrevExample`/`NextExample` still chains across chapters, so arrow-key navigation works seamlessly across chapter boundaries.

## Alternatives Considered

- **Separate chapter config file (YAML/JSON)**: Rejected — adds a second source of truth for example ordering. The `examples.txt` convention-over-configuration pattern from Feature 001 works well.
- **Directory-based grouping (`examples/basics/hello-world/`)**: Rejected — breaks the existing flat directory structure and requires changes to `mustGlob`, the build script, and all file path logic.

## Consequences

**Positive**:
- 9 chapters organize 41 examples into a progressive learning path
- Zero changes to example rendering, search, or navigation
- Backward compatible — removing all `# ` lines restores original behavior

**Negative / Trade-offs**:
- Chapter metadata only affects the index page — individual example pages don't show which chapter they belong to
- No chapter-level navigation (e.g., "jump to next chapter")

**Future considerations**:
- If chapters grow beyond ~12, consider collapsible sections or a sidebar TOC
- Chapter names could be used in page titles or breadcrumbs on example pages

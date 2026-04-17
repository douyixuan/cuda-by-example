# Decisions Made — NVIDIA Samples Migration

**Feature ID**: 002
**Shipped**: 2026-04-18
**Appetite**: Medium Batch — 2-3 sessions
**Actual effort**: 1 session

## Key Architectural Decisions
- **Chapter-aware parsing** (ADR 0005): Extended `parseExamples` to capture `# ` lines as chapter headings. Dual return `([]*Example, []*Chapter)` isolates chapter grouping to the index page only. Backward compatible — no `#` lines reverts to flat list.
- **Testable generator refactoring** (ADR 0006): Extracted `parseExamplesFrom(txtPath, examplesDir)` to enable unit testing with temp directories. First test suite for the generator (3 tests).
- **Content conventions** (ADR 0007): Established 30-80 line self-contained `.cu` file format with compile instructions in comments and verification output in main().

## What Was Cut (Scope Hammering)
- Nothing — all 29 planned examples and both infrastructure elements were completed within a single session.

## What Surprised Us
- The `#` prefix was already being parsed and discarded in the original code (line 229). Converting to chapter capture required ~20 lines of changes.
- The generator architecture scaled from 12 to 41 examples without any performance or structural issues — all 41 generated on the first try.
- The entire build completed in 1 session vs. the 2-3 session appetite. AI-assisted example authoring was faster than estimated.

## Future Improvement Areas
- **Chapter-level navigation**: Example pages could show which chapter they belong to, with "next chapter" links.
- **Collapsible chapters**: If the example count grows beyond ~50, the index page may need collapsible sections or a sidebar TOC.
- **Line count CI**: Automated enforcement of the 30-80 line convention for new examples.
- **Integration tests**: Golden-file diff tests for the full generated output.

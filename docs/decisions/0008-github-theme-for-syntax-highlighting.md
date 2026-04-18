# ADR 0008: GitHub Light/Dark Theme for Syntax Highlighting

**Status**: Accepted
**Date**: 2026-04-18
**Feature**: 003 — Code Syntax Highlighting

## Context

The site uses Chroma for syntax highlighting, which emits CSS class names (`.k`, `.kt`, `.nf`, etc.) but leaves color assignment to `site.css`. The original CSS had ~15 token classes with colors, but 4 major ones (`.nf`, `.nx`, `.o`, `.p`) were empty, rendering function names, operators, and punctuation as plain text. The site needed a complete, mature color palette that covered all token classes Chroma emits for C++/CUDA code.

## Decision

Source colors directly from Chroma's vendored `styles/github.xml` and `styles/github-dark.xml` and apply them in `site.css` under `prefers-color-scheme` media queries. Cover all 17 token classes present in rendered CUDA output.

## Rationale

GitHub's theme is the de facto standard for code on the web — familiar to the target audience (developers), well-tested across token types, and already vendored in the project. Sourcing from the vendored XML files ensures the palette stays in sync with the Chroma version in use. Using `prefers-color-scheme` avoids adding a theme-switcher UI component, keeping the scope within the 1-session appetite.

## Alternatives Considered

- **Monokai / Dracula / other dark-first themes**: Rejected — less familiar to the GitHub-native developer audience; would require a custom light variant.
- **Custom hand-crafted palette**: Rejected — unnecessary design work when a proven palette is already vendored.
- **Chroma's built-in HTML formatter with inline styles**: Rejected — breaks the existing architecture (R3: keep Chroma + CSS classes approach); inline styles can't be overridden by `prefers-color-scheme`.
- **Custom theme switcher toggle**: Rejected — out of scope for this batch; `prefers-color-scheme` covers the common case.

## Consequences

**Positive**:
- All 17 token classes now have colors in both light and dark modes.
- Dark mode comments use italic style, matching GitHub Dark convention.
- Zero new JavaScript — purely CSS.
- Future Chroma upgrades can re-sync colors from the vendored XML.

**Negative / Trade-offs**:
- Site appearance is tied to GitHub's aesthetic; diverging later requires a full palette replacement.
- `prefers-color-scheme` only — users who want to override system preference have no toggle.

**Future Considerations**:
- A theme toggle could be added as a separate small-batch feature if user demand arises.
- If Chroma is upgraded, the vendored XML should be re-checked for new token classes.

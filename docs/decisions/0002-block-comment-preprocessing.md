# ADR 0002: Pre-process Block Comments Rather Than Modifying the Segment Parser

**Status**: Accepted
**Date**: 2026-04-09
**Feature**: 001 — CUDA by Example Site

## Context

gobyexample's segment parser uses a `//`-based regex (`docsPat`) to separate documentation
from code. CUDA's idiomatic comment style includes `/* */` block comments. We needed `.cu`
annotation files to support both `//` and `/* */` for documentation segments.

## Decision

Add a `normalizeBlockComments(lines []string) []string` function that runs before the
segment parser. It converts standalone `/* */` blocks into `//` lines, leaving inline
`/* */` on code lines untouched. The existing `docsPat` regex and segment loop are
not modified.

## Rationale

Isolating the conversion in a pre-processing pass means the original parser logic —
which is proven and well-understood — stays untouched. The pre-processor is ~30 lines
with clear rules. This separation makes both pieces independently testable and avoids
introducing regressions in the segment parsing logic.

## Alternatives Considered

- **Modify `docsPat` regex to handle `/* */`**: Would require multi-line regex state
  tracking in a loop designed for line-by-line processing. Higher complexity, higher
  risk of subtle bugs.
- **Require all annotations use `//` only**: Works but feels unnatural for C/CUDA
  developers accustomed to `/* */` doc blocks. Would create friction for contributors.

## Consequences

**Positive**:
- Zero changes to the proven segment parser
- Clean separation of concerns — pre-processing is independent and testable
- Authors can use idiomatic C-style block comments in `.cu` files

**Negative / Trade-offs**:
- Edge case: `/* */` inside string literals could theoretically be mishandled. Accepted
  because annotation files are author-controlled and this case doesn't arise in practice.
- Two-pass processing adds minimal overhead (negligible for file sizes involved)

**Future considerations**:
- If contributors encounter the string literal edge case, a more sophisticated parser
  may be needed — but the convention "don't put `/* */` in string literals in annotation
  files" is sufficient for now

# ADR 0004: Git Submodule at vendor/ Conflicts with Go Vendoring

**Status**: Accepted (with known technical debt)
**Date**: 2026-04-09
**Feature**: 001 — CUDA by Example Site

## Context

gobyexample was added as a git submodule at `vendor/gobyexample/` for reference and
diffing. However, `vendor/` is a reserved directory name in Go modules — `go mod` treats
it as the vendor directory for dependency management. This causes `go mod tidy` and
`go build` to behave unexpectedly unless the `-mod=mod` flag is used.

## Decision

Keep the submodule at `vendor/gobyexample/` for S1 and use `-mod=mod` in `tools/build`
to bypass Go's vendor directory detection. Document the conflict and plan to rename to
`upstream/` in a future session.

## Rationale

Renaming the submodule mid-build would require updating git history, `.gitmodules`, and
any references. The `-mod=mod` workaround is a single flag that resolves the issue
immediately. S1's priority was shipping the generator, not perfecting directory layout.

## Alternatives Considered

- **Rename to `upstream/` immediately**: Cleaner, but adds churn during S1 when the
  priority is getting the generator working. Deferred.
- **Don't use a submodule**: Lose the ability to diff against upstream gobyexample.
  The submodule is valuable for tracking divergence.
- **Use `vendor/gobyexample` with Go vendoring**: Not viable — gobyexample isn't a Go
  dependency we import. The directory is purely for reference files.

## Consequences

**Positive**:
- S1 shipped without directory restructuring
- `-mod=mod` is a well-understood Go flag with no side effects for this project

**Negative / Trade-offs**:
- `vendor/` name is confusing for Go developers who expect it to contain vendored deps
- Requires `-mod=mod` flag in all Go build commands — easy to forget

**Future considerations**:
- Rename `vendor/gobyexample/` to `upstream/gobyexample/` in S2 or S5 to eliminate
  the conflict and the need for `-mod=mod`

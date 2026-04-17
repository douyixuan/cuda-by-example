# ADR 0007: CUDA Example Content Conventions

**Status**: Accepted
**Date**: 2026-04-18
**Feature**: 002 — NVIDIA Samples Migration

## Context

Scaling from 12 to 41 CUDA examples required consistent conventions for content quality, scope, and format. Each example is derived from NVIDIA's cuda-samples (100+ files with extensive boilerplate, helper libraries, and build complexity) and must be distilled into a self-contained teaching file.

## Decision

Establish the following conventions for all CUDA teaching examples:

1. **30-80 lines per file** — long enough to teach a concept, short enough to read in one sitting
2. **Self-contained** — each `.cu` file compiles independently with `nvcc` (no helper headers, no multi-file builds)
3. **Seg pattern** — `//` comment blocks alternate with code blocks; the generator parses these into side-by-side docs + code
4. **Compile instructions in comments** — examples requiring special flags (e.g., `-arch=sm_70`, `-lcublas`, `-rdc=true`) document them in the opening comment block
5. **Verification output** — every `main()` prints expected values so readers can verify correct execution
6. **Progressive ordering** — chapters arranged from fundamentals to libraries, with each chapter building on concepts from earlier ones

## Rationale

- **Self-contained files** eliminate the "where do I find the helper?" problem that plagues NVIDIA's official samples
- **Line count constraint** forces focus on one concept per example — multi-concept examples get split into separate files
- **Compile instructions as comments** avoid the rabbit hole of building a compilation system while still being useful to readers who want to run the code
- **Verification output** serves as both documentation and a poor-man's test

## Alternatives Considered

- **Include Makefile per example**: Rejected — adds build complexity and doesn't match the educational, read-first nature of the site
- **Use NVIDIA's helper headers**: Rejected — defeats the purpose of self-contained examples; adds vendor dependency
- **Longer, comprehensive examples (100-200 lines)**: Rejected — breaks the "learn one concept at a time" philosophy that makes gobyexample.com effective

## Consequences

**Positive**:
- Consistent reader experience across all 41 examples
- Every example can be copy-pasted and compiled directly
- Progressive chapter ordering creates a complete learning path

**Negative / Trade-offs**:
- Some topics (e.g., multi-GPU, complex reduction trees) can't fit in 80 lines and were excluded
- Self-contained constraint means some code patterns are simplified vs. production CUDA code
- No runtime verification — the site displays code but can't execute it

**Future considerations**:
- A linter or CI check could enforce the 30-80 line constraint on new examples
- Examples could be tagged with minimum compute capability for better discoverability

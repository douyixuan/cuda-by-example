# Frame: CUDA by Example Site

**Feature ID**: 001
**Created**: 2026-04-09
**Status**: Framing

---

## Problem

Learning CUDA today is painful in multiple compounding ways:

1. **No concise annotated reference** — NVIDIA's official docs and books like "CUDA by Example" (Sanders & Kandrot) are verbose. There's no quick-reference site where you see working `.cu` code side-by-side with plain-English explanation, the way gobyexample.com works for Go.

2. **Examples are scattered** — Good CUDA code exists across NVIDIA's cuda-samples repo, GitHub gists, Stack Overflow answers, and blog posts. There's no single organized, navigable source.

3. **Existing resources assume too much** — Most tutorials front-load GPU architecture theory or assume deep C++ expertise before showing a single working kernel.

4. **Building the site IS the learning** — Writing annotated examples forces the author to deeply understand each concept, making the project itself a structured learning path.

A developer wanting to learn CUDA today has to triangulate between NVIDIA's cuda-samples repo (code without explanation), dense documentation, and scattered blog posts. There's no "just show me working code with a clear explanation" resource.

## Affected Users

**Primary**: The author (Cedric) — using the project as a structured CUDA learning path.

**Secondary**: Other developers learning CUDA — the site will be published publicly. The Go by Example model (8.1k stars, 8 language translations) demonstrates strong demand for this format in other ecosystems. CUDA has no equivalent.

**Strategic value**: CUDA/GPU programming is increasingly critical (ML, HPC, graphics). A well-executed public resource could become a canonical reference, similar to how gobyexample.com became the canonical Go quick-reference.

## Business Value

- **Personal**: Structured learning project with a concrete deliverable — forces depth over breadth, produces a portfolio artifact.
- **Community**: Fills a real gap. No "CUDA by Example" site exists in the gobyexample format. High potential for organic discovery via search and GitHub.
- **Leverage**: Using nvidia/cuda-samples as the source material means the examples are already correct and tested — the work is curation, annotation, and presentation, not writing CUDA from scratch.

## Evidence

- gobyexample.com model is proven: 8.1k GitHub stars, 8 translations, widely cited as the best Go quick-reference.
- nvidia/cuda-samples repo exists as a rich source of working, tested CUDA code to annotate.
- No equivalent "CUDA by Example" site in this format exists (gap confirmed by absence).
- All four pain points above apply to the author directly — this is a real problem, not a hypothetical.

## Time Budget

**Big Batch — 4-5 sessions**

Breakdown:
- Session 1: Site generator (extract annotations from `.cu` files, render to static HTML, navigation)
- Session 2: First batch of examples — CUDA basics (hello world, memory, threads, blocks)
- Session 3: Intermediate examples — shared memory, streams, async
- Session 4: Advanced examples + polish (search, styling, deployment)
- Session 5: Buffer — scope overflow, deployment, public launch prep

## Frame Statement

> "If we can shape this into something buildable and execute it in 4-5 sessions,
> it will produce a public CUDA learning resource in the gobyexample format —
> filling a real gap in the ecosystem while giving Cedric a structured path
> to deeply learn CUDA."

---

## Status: Frame Go — approved 2026-04-09

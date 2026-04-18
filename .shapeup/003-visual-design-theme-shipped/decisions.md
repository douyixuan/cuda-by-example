# Decisions Made — Code Syntax Highlighting

**Feature ID**: 003
**Shipped**: 2026-04-18
**Time Budget**: Small Batch (1 session)
**Actual Effort**: 1 build session

## Key Architectural Decisions

- **Vendored lexer extension over new lexer**: Added `*.cu`/`*.cuh` to the existing C++ XML
  lexer rather than writing a standalone CUDA lexer. Simpler, lower risk, and the C++ lexer
  already handles ~95% of CUDA syntax correctly.
- **GitHub theme sourced from vendored Chroma styles**: Colors copied from `styles/github.xml`
  and `styles/github-dark.xml` already in the vendor tree. Avoids custom palette design work
  and stays in sync with the Chroma version in use. (ADR 0008)
- **`prefers-color-scheme` only**: No theme toggle UI. Keeps scope within 1-session appetite.

## What Was Cut (Scope Hammering)

- **`<<<>>>` special operator**: Accepted as 6 individual Operator tokens — visually distinct
  enough, and parsing the angle brackets as a single token would require significant lexer work.
- **CUDA built-in variable highlighting** (`threadIdx.x`, `blockDim.x`): Generic `Name` token
  is standard GitHub theme behavior. No user-visible regression.
- **Theme toggle**: Deferred. `prefers-color-scheme` covers the common case.

## What Surprised Us

- No unexpected complications — the fix was exactly as shaped. The C++ lexer's function
  definition regex already handled `__global__ void hello()` correctly.
- Token coverage in rendered HTML is comprehensive across all 41 examples.

## Plan Adjustment

- `TestCUFilesProduceSemanticTokens` replaced with `TestCUFilesUseCppLexer`: direct lexer
  config check is more precise than inferring registration from rendered HTML output.

## Future Improvement Areas

- **Theme toggle**: If users request manual light/dark override, add a small JS toggle.
- **`<<<>>>` as a single token**: Could be done with a custom lexer rule, but low value.
- **CUDA built-in variable highlighting**: Would require a custom lexer or post-processing pass.

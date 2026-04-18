# Scope: Lexer Fix

## Hill Position
✓ Done — deployed, tests passing

## Must-Haves
- [x] Register `*.cu` and `*.cuh` in C++ lexer config
- [x] Add CUDA keyword rule (`__global__`, `__device__`, etc.) as KeywordReserved
- [x] CUDA keywords placed before generic `Name` rule to take priority
- [x] Tests: `.cu` file resolves to C++ lexer (`TestCUFilesUseCppLexer` — calls `cudaLexer()` directly, asserts `cfg.Name == "C++"`)
- [x] Tests: CUDA keywords tokenized as `kr` (KeywordReserved)

## Notes
- CUDA keyword regex uses explicit enumeration (`__global__|__device__|...`) to avoid false positives on `__cplusplus`, `__LINE__`, etc.
- Rule placed in `statements` state, before the catch-all `Name` rule at line 223

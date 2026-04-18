# Scope: CSS Theming

## Hill Position
✓ Done — deployed, tests passing

## Must-Haves
- [x] Replace light mode syntax colors with GitHub Light palette
- [x] Replace dark mode syntax colors with GitHub Dark palette
- [x] Cover all token classes: keywords, types, functions, strings, numbers, operators, punctuation, comments, preprocessor, errors
- [x] Dark mode comments use italic style per GitHub Dark convention
- [x] Verify rendered HTML contains semantic token classes (`k`, `kt`, `kr`, `nf`, `s`, `mi`, `o`, `p`, `cp`, etc.)

## Notes
- Colors sourced from vendored `styles/github.xml` and `styles/github-dark.xml`
- Added coverage for previously-empty classes: `.nf`, `.nx`, `.o`, `.p`
- Added new classes not in original CSS: `.kr`, `.nc`, `.sa`, `.se`, `.mb`, `.c`, `.cm`, `.cp`, `.cpf`, `.err`

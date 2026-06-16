---
name: verify
description: Verification workflow — run tests, lint, typecheck, and validate implementation
license: MIT
compatibility: opencode
metadata:
  audience: all users
  workflow: generalpippy
---

## What I do

I run verification checks on your codebase:
1. Run the test suite
2. Run linting
3. Run type checking
4. Report any issues found
5. Fix issues if possible

## When to use me

Use this when:
- You've made changes and want to verify they work
- Before committing code
- After implementing a feature
- When you want to ensure code quality

## How to use me

1. Run `/verify` or ask Pippy to verify
2. I'll run all checks in sequence
3. I'll report any issues found
4. I'll fix issues if possible

## What I check

| Check | Tool | Purpose |
|-------|------|---------|
| Tests | Project test runner | Verify functionality |
| Lint | ESLint/linter | Code style and quality |
| Type check | TypeScript/tsc | Type safety |
| Build | Project build tool | Compilation |

## Common Issues

- **Test failures** — I'll analyze and fix
- **Lint errors** — I'll auto-fix where possible
- **Type errors** — I'll add types or fix mismatches
- **Build errors** — I'll debug and fix

## Important Notes

- I run checks in order: tests → lint → typecheck → build
- If any check fails, I'll report and fix before moving on
- I follow existing code style and patterns
- I write tests for new functionality

---
description: Ship mode — review, verify, and prepare this branch for PR
agent: pippy
---

## Ship Mode

An alias for `/goal "review, verify, and prepare this branch for PR"`.

Pippy will:
1. Review all changes (git diff)
2. Run the full verification gate (tests, lint, typecheck)
3. Check for security issues
4. Check docs for public API changes
5. Prepare a commit message and PR description
6. Report readiness — no auto-push

### Git Operations via rtk

Prefer `rtk` for read-only git/status/diff/list operations when `rtk` is installed (detect with `command -v rtk`). Fall back to plain bash only if `rtk` is missing.

### Early Context Compression

Before the final verification gate, call `compress` to summarize large exploration/planning sections that consumed context window. This keeps verification output readable and prevents context pressure from degrading the final report.

### Caveman Mode Reports

When Caveman mode (OpenCode compression style) is active, report in caveman-full style: terse, no fluff, preserve full technical substance and verification results. Drop filler words, hedging, and pleasantries. Keep error messages, test output, and file paths exact.

### Release Confirmation

After `gh release create`, trust the CLI exit status. Do NOT re-fetch the release to confirm. Only investigate if the command reports an error (non-zero exit or stderr output).

**Usage:** /ship

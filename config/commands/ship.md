---
description: Ship mode — review, verify, and prepare this branch for PR
agent: pippy
---

## Ship Mode

An alias for `/goal "review, verify, and prepare this branch for PR"`.

Pippy will:
1. Review all changes (`rtk git diff` when `rtk` is installed)
2. Run the full verification gate (tests, lint, typecheck)
3. Check for security issues
4. Check docs for public API changes
5. Prepare a commit message and PR description
6. Report readiness — no auto-push

### RTK Force

When `rtk` is installed, `/ship` MUST route every shell command through `rtk`. Use `rtk git status`, `rtk git log`, `rtk git diff`, `rtk gh ...`, and `rtk make all` instead of raw `git`, `gh`, or `make`. For commands without a specialized wrapper, use `rtk run` or `rtk proxy`. Fall back to raw shell only if `rtk` is missing or the wrapper fails for that exact command, and mention the fallback in the report.

### Early Context Compression

Before the final verification gate, call `compress` to summarize large exploration/planning sections that consumed context window. This keeps verification output readable and prevents context pressure from degrading the final report.

### Caveman Mode Reports

When Caveman mode (OpenCode compression style) is active, report in caveman-full style: terse, no fluff, preserve full technical substance and verification results. Drop filler words, hedging, and pleasantries. Keep error messages, test output, and file paths exact.

### Release Confirmation

After `gh release create`, trust the CLI exit status. Do NOT re-fetch the release to confirm. Only investigate if the command reports an error (non-zero exit or stderr output).

**Usage:** /ship

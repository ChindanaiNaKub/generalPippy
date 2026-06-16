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

**Usage:** /ship

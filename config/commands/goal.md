---
description: Start a self-driving goal — Pippy plans, executes, verifies, and iterates until done
agent: pippy
---

## /goal

Start the self-driving loop.

```
/goal "<verifiable objective>"
```

Pippy will:
1. Parse the objective into acceptance criteria
2. Explore the codebase with jcodemunch
3. Plan step-by-step with verification per step
4. Execute and verify each step
5. Retry failures (3 cheap + 1 strong diagnosis)
6. Run the final no-mistakes gate
7. Report done / blocked / partial

### Examples

```
/goal "add input validation to the signup endpoint"
/goal "refactor the auth module to use dependency injection"
/goal "fix the flaky test in orders.test.ts"
```

### Notes

- YOLO mode is on by default (auto-allow reads, subagent routing, exploration bash, and verification bash; implementation edits route to `pippy-build`).
- Pippy stops only when acceptance criteria are met by evidence.
- Use `/ship` as a shortcut for PR prep.
- Use OpenCode's session usage display for exact tokens/cost, and `/budget` for routing and efficiency guidance.

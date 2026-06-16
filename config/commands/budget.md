---
description: Audit budget health and routing behavior
---

## Budget Report

Audit the current session for budget health, routing behavior, and token-efficiency opportunities.

Do **not** estimate tokens, model usage, agent usage, or cost from conversation volume. OpenCode's TUI/session usage display is the authoritative source for actual tokens and spend. If live usage data is not available in this command context, say so directly and point the user to OpenCode's built-in usage/cost display.

Report only what can be grounded in the visible session:
1. Whether the task should have delegated implementation to `pippy-build`
2. Whether planning or stuck-step diagnosis should have used `pippy-plan`
3. Whether the conversation appears to be running too long before compaction
4. Whether `rtk`, Caveman mode, and jcodemunch were used where appropriate
5. Whether verification was batched (e.g., `make all`) instead of running separate redundant commands
6. Specific optimization suggestions for the next step

If the user asks for exact spend, answer:

> I cannot measure exact token usage or cost from this command. Use OpenCode's built-in session usage/cost display for authoritative numbers.

**Warn qualitatively when:**
- Implementation appears to be happening in the primary strong-model agent instead of `pippy-build`
- No subagent delegation happened for a straightforward coding/editing task
- Large file reads, repeated diffs, or verbose test output are inflating context
- Verification commands are run redundantly instead of batched safely (e.g., prefer `make all` over separate `make test` + `make lint`)

For caveman, distinguish:
- **Caveman mode**: OpenCode command/config mode. Treat it as available when `/caveman` exists in OpenCode commands or `AGENTS.md` contains a `caveman-begin` block.
- **Caveman CLI**: optional shell executable. Do not report Caveman mode as missing merely because `command -v caveman` fails.

**Usage:** /budget

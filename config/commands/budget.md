---
description: Report role usage accounting and budget guidance
---

## Budget Report

Report OpenCode-recorded usage and cost for one root session and its child sessions, grouped by Pippy role, then add grounded budget guidance.

OpenCode-recorded session usage is authoritative for exact numbers. Do **not** estimate tokens, model usage, agent usage, or cost from conversation volume. If OpenCode session records are not visible in this command context, say which records are missing and report `Blocked` for exact accounting while still giving routing and efficiency guidance from visible evidence.

Session selection:
- `/budget` auto-detects the current/latest root session only when exactly one candidate is unambiguous from the current OpenCode context.
- `/budget <session-id>` reports historical usage for that explicit root session.
- If auto-detection is ambiguous, stop instead of guessing. List candidate session ids, timestamps, and visible titles/objectives when available, then ask the user to rerun `/budget <session-id>`.

Report a role usage accounting table with these rows:
- Coordinator (`pippy`)
- Planning (`pippy-plan`)
- Implementation (`pippy-build`)
- `Total`

Each row must include:
- model
- session count
- input tokens
- output tokens
- cache-read tokens
- cache-write tokens
- cost

If a role has no sessions, show session count `0` and token/cost values as `0` or `not recorded`, whichever matches the OpenCode record. Never invent a model or price.

After the exact role usage accounting table, report only budget guidance grounded in visible evidence:
1. Whether implementation delegated to `pippy-build`
2. Whether planning or stuck-step diagnosis used `pippy-plan`
3. Whether the conversation appears to be running too long before compaction
4. Whether `rtk`, Caveman mode, jcodemunch, and ponytail were used where appropriate
5. Whether verification was batched (e.g., `make all`) instead of running separate redundant commands
6. The selected model profile and role-based model routing when `~/.config/opencode/generalpippy/profile.json` is visible
7. Specific optimization suggestions for the next step, including an explicit compression recommendation when a finished work block is obvious

**Warn when:**
- Implementation appears to be happening in the primary strong-model agent instead of `pippy-build`
- No subagent delegation happened for a straightforward coding/editing task
- Visible agent models disagree with selected profile metadata for the planning, implementation, or system-task roles
- Large file reads, repeated diffs, or verbose test output are inflating context
- Verification commands are run redundantly instead of batched safely (e.g., prefer `make all` over separate `make test` + `make lint`)
- The session added new scripts, dependencies, wrappers, or custom logic without first considering existing stdlib, repo utilities, native OpenCode behavior, or already-installed dependencies

For caveman, distinguish:
- **Caveman mode**: OpenCode command/config mode. Treat it as available when `/caveman` exists in OpenCode commands or `AGENTS.md` contains a `caveman-begin` block.
- **Caveman CLI**: optional shell executable. Do not report Caveman mode as missing merely because `command -v caveman` fails.

For ponytail, distinguish:
- **ponytail constraint**: planning/build behavior that prefers stdlib, existing dependencies, repo-local utilities, and native platform features before adding new code or dependencies.
- **ponytail plugin**: optional OpenCode plugin. If installed but no relevant reuse decision appears in the visible work, report it as "not visibly exercised" rather than failed.
- Treat ponytail as a soft observation by default. Make it a warning only when the visible session added custom logic, wrappers, scripts, or dependencies without showing reuse consideration.

For optional efficiency tools generally:
- Use **not applicable** when the session type did not call for the tool (for example, jcodemunch during docs-only work or ponytail when no new code/dependency choice occurred).
- Use **not visibly exercised** when the tool or constraint may have mattered but the visible session contains no evidence that it shaped the work.
- Use **missed opportunity** when visible evidence shows the tool or constraint should have been used and was not.

**Usage:** `/budget` or `/budget <session-id>`

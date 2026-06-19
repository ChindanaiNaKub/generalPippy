---
description: Report role usage accounting and budget guidance
---

## Budget Report

Report OpenCode-recorded usage and cost for one root session and its child sessions, grouped by Pippy role, then add grounded budget guidance.

OpenCode-recorded session usage is authoritative for exact numbers. Do **not** estimate tokens, model usage, agent usage, or cost from conversation volume. If OpenCode session records are not visible in this command context, say which records are missing and report `Blocked` for exact accounting while still giving routing and efficiency guidance from visible evidence.

Use OpenCode's local database before giving up:
1. Run `opencode db path` to confirm the database is visible.
2. Use `opencode db --format json "<SQL>"` to read the `session` table. Do not read raw logs first; logs are fallback evidence only.
3. For `/budget <session-id>`, treat the argument as the root session id and report rows where `id = <session-id>` or `parent_id = <session-id>`.
4. For bare `/budget`, find recent root candidates for the current project directory:

```sql
select id, title, directory, agent, model, cost, tokens_input, tokens_output,
       tokens_cache_read, tokens_cache_write, time_created, time_updated
from session
where parent_id is null
  and directory = '<current working directory>'
order by time_updated desc
limit 5;
```

Auto-select only when one candidate is clearly the current/latest root session. If several recent roots are plausible, stop instead of guessing and ask for `/budget <session-id>`.

After selecting a root session, query the root and direct child sessions:

```sql
select id, parent_id, agent, model, cost, tokens_input, tokens_output,
       tokens_cache_read, tokens_cache_write, title, directory,
       time_created, time_updated
from session
where id = '<root-session-id>' or parent_id = '<root-session-id>'
order by time_created;
```

Group rows by agent role:
- `pippy` → Coordinator
- `pippy-plan` → Planning
- `pippy-build` → Implementation

Use the `model` JSON field from each row. Sum `cost`, `tokens_input`, `tokens_output`, `tokens_cache_read`, and `tokens_cache_write` per role and for Total. Session count is the number of rows in that role. If the `session` table or required columns are unavailable, report `Blocked` for exact accounting and include the failed `opencode db` command or missing columns.

Session selection:
- `/budget` auto-detects the current/latest root session only when exactly one candidate is unambiguous from the current OpenCode context.
- `/budget <session-id>` reports historical usage for that explicit root session.
- If auto-detection is ambiguous, stop instead of guessing. List candidate session ids, timestamps, and visible titles/objectives when available, then ask the user to rerun `/budget <session-id>`.

Report a role usage accounting table with this exact column order:

| Role | Model | Sessions | Input Tokens | Output Tokens | Cache-Read Tokens | Cache-Write Tokens | Cost |
| --- | --- | ---: | ---: | ---: | ---: | ---: | ---: |

Use this table as the primary accounting surface. Do not omit `Cost` from the table and do not move cost only into prose guidance.

Include these rows:
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
- Coordinator (`pippy`) cost dominates the run because long exploration, review, `/budget`, or `/ship` work stayed on a strong model after implementation was done
- Visible agent models disagree with selected profile metadata for the planning, implementation, or system-task roles
- Large file reads, repeated diffs, or verbose test output are inflating context
- Verification commands are run redundantly instead of batched safely (e.g., prefer `make all` over separate `make test` + `make lint`)
- The session added new scripts, dependencies, wrappers, or custom logic without first considering existing stdlib, repo utilities, native OpenCode behavior, or already-installed dependencies

When comparing with previous or historical sessions, keep the blame precise:
- High Coordinator (`pippy`) cost means the root coordination session was expensive.
- High Implementation (`pippy-build`) cost means delegated implementation was expensive.
- Do **not** say implementation happened directly on a strong model merely because Coordinator cost is high.
- Only report implementation bypass when the database and visible transcript show implementation work happened in `pippy` without a matching `pippy-build` child session.

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

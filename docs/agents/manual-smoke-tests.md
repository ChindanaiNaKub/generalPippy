# Manual Smoke Tests

Use these checks after installing GeneralPippy when you need human-visible proof that OpenCode is using the intended routing and budget boundaries.

## Setup

1. Run `./install.sh`.
2. Start OpenCode in this repo with `opencode`.
3. Confirm the active/default agent is `pippy`.

## Automated Doctor Check

Run the automated validator first:

```bash
scripts/doctor.sh
```

This checks agent frontmatter, permission boundaries, stale v1.0 references, and pinned deps. Returns non-zero on problems.

## 1. Resolved Config

In a shell, run:

```bash
opencode debug config | jq '{
  default_agent,
  pippy: .agent.pippy.permission,
  build: .agent["pippy-build"] | {mode, model, permission},
  plan: .agent["pippy-plan"] | {mode, model, permission}
}'
```

Expected behavior:

- `default_agent` is `pippy`.
- `pippy.permission.edit` is `deny`.
- `pippy.permission.bash["*"]` is `ask`.
- Read-only exploration commands such as `find`, `cat`, `sed -n`, `head`, `tail`, `wc`, `nl`, `rg`, `grep`, `tree`, `jq`, `file`, `stat`, and `du -sh` are allowed.
- `pippy.permission.task["pippy-build"]` is `allow`.
- `pippy.permission.task["pippy-plan"]` is `allow`.
- `pippy-build.model` is `opencode-go/mimo-v2.5`.
- `pippy-build.permission.edit` is `allow`.
- `pippy-build.permission.task` is `deny`.
- `pippy-plan.permission.edit` is `deny`.
- `pippy-plan.permission.task` is `deny`.

## 2. Routing Session

In OpenCode, run:

```text
/goal "make a harmless one-line documentation wording improvement, verify it, and report the agent routing used"
```

Expected behavior:

- The primary `pippy` session plans and verifies, but does not edit files directly.
- A `pippy-build` child session is created for the edit.
- The `pippy-build` child session shows `opencode-go/mimo-v2.5`.
- If analysis or stuck-step diagnosis is needed, `pippy-plan` is read-only.
- Final verification runs from the primary `pippy` session.

Then run:

```text
/budget
```

Expected behavior:

- `/budget` reports that implementation was delegated to `pippy-build`.
- `/budget` points to OpenCode's built-in usage/cost display for exact spend.
- `/budget` does not estimate exact tokens, model usage, or cost from conversation volume.

## 3. Failure Signals

- The primary `pippy` session edits files directly.
- The primary `pippy` session has unrestricted `bash: allow`.
- Read-only inspection commands such as `find`, `cat`, or `sed -n` require approval.
- No `pippy-build` child session appears for the documentation edit.
- `pippy-build` runs on a strong model instead of `opencode-go/mimo-v2.5`.
- `pippy-plan` edits files or invokes implementation work.
- `/budget` invents exact cost numbers.

## 4. /ship Budget-Efficiency Checks

Run `/ship` in OpenCode and verify these budget-efficiency behaviors:

- **rtk for git/status**: `/ship` uses `rtk git status`, `rtk git log`, and `rtk git diff` instead of raw git commands for read-only operations.
- **Context compression before final gate**: `/ship` compresses context (via caveman mode or explicit compress) before the final verification gate to reduce token usage.
- **Caveman-full reporting**: When caveman mode is available, `/ship` reports in caveman-full compression style for status, build, and verification output.
- **No re-fetch of releases**: After `gh release create` succeeds, `/ship` trusts the exit status and does not re-fetch the release metadata to confirm it exists.

Expected failure signals:
- `/ship` runs raw `git status` instead of `rtk git status` when rtk is installed.
- `/ship` re-fetches release info after creating a release.
- `/ship` reports in full prose when caveman mode is available.

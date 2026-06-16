# Manual Smoke Tests

Use these checks after installing GeneralPippy when you need human-visible proof that OpenCode is using the intended routing and budget boundaries.

## Setup

1. Run `./install.sh`.
2. Start OpenCode in this repo with `opencode`.
3. Confirm the active/default agent is `pippy`.

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

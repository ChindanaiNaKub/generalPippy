# Manual Smoke Tests

Use these checks after installing GeneralPippy when you need human-visible proof that OpenCode is using the intended routing and budget boundaries.

## Setup

1. Run `./install.sh`.
2. Start OpenCode in this repo with `opencode`.
3. Confirm the active/default agent is `pippy`.

## Automated Doctor Check

Run the automated validator first:

```bash
OPENCODE_CONFIG="${XDG_CONFIG_HOME:-$HOME/.config}/opencode" scripts/doctor.sh
```

This checks agent frontmatter, permission boundaries, stale v1.0 references, and pinned deps. Returns non-zero on problems.

When `~/.config/opencode/generalpippy/profile.json` exists, `scripts/doctor.sh` validates installed role models against that metadata instead of assuming the Balanced defaults.

## 1. Resolved Config

In a shell, run:

```bash
cat ~/.config/opencode/generalpippy/profile.json

opencode debug config | jq '{
  default_agent,
  pippy: .agent.pippy.permission,
  build: .agent["pippy-build"] | {mode, model, permission},
  plan: .agent["pippy-plan"] | {mode, model, permission}
}'
```

Expected behavior:

- `profile.json` records the selected model profile and concrete planning, implementation, and system-task role models.
- `default_agent` is `pippy`.
- `pippy.permission.edit` is `deny`.
- `pippy.permission.bash` is `allow`.
- `pippy.permission.task["pippy-build"]` is `allow`.
- `pippy.permission.task["pippy-plan"]` is `allow`.
- `pippy-build.model` matches the implementation role model in `profile.json` (`opencode-go/mimo-v2.5` for Balanced).
- `pippy-build.permission.edit` is `allow`.
- `pippy-build.permission.bash` is `allow`.
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
- Review and final verification run from the primary `pippy` session.

Then run:

```text
/budget
```

Expected behavior:

- `/budget` reports that implementation was delegated to `pippy-build`.
- `/budget` reports the selected model profile and role-based routing when profile metadata is visible.
- `/budget` points to OpenCode's built-in usage/cost display for exact spend.
- `/budget` does not estimate exact tokens, model usage, or cost from conversation volume.
- `/budget` distinguishes ponytail constraint (stdlib reuse behavior) from ponytail plugin (optional OpenCode plugin).
- `/budget` uses optional-tool status language: "not applicable" when tool was not needed, "not visibly exercised" when evidence is missing, "missed opportunity" when tool should have been used.
- `/budget` includes an explicit compression recommendation when a finished work block is obvious.
- `/budget` distinguishes Caveman mode (OpenCode command/config) from Caveman CLI (shell executable), and does not report Caveman mode as missing based on `command -v caveman`.

## 3. Failure Signals

- The primary `pippy` session edits files directly.
- The primary `pippy` session or `pippy-build` asks before running git, gh, make, dependency, or repo-local commands in YOLO mode.
- No `pippy-build` child session appears for the documentation edit.
- `pippy-build` runs on a strong model instead of `opencode-go/mimo-v2.5`.
- `pippy-plan` edits files or invokes implementation work.
- `/budget` invents exact cost numbers.

## 4. Advisor Adapter Checks

After install, inspect detected advisor adapters:

```bash
cat ~/.config/opencode/generalpippy/advisors.json
```

Expected behavior:

- Detected advisor adapters are present with `"enabled": false`.
- Each adapter has a read-only-oriented command template.
- `/advice <adapter-name>` refuses disabled or unknown adapters and lists available adapters.
- After manually setting one adapter to `"enabled": true`, `/advice <adapter-name>` prepares an advisor context bundle and treats the advisor response as non-authoritative evidence.
- `/advice all` reports no enabled advisors when none are enabled, and summarizes agreement, disagreement, assumptions, and unresolved product or architecture conflicts when multiple advisors are enabled.

## 5. /ship Budget-Efficiency Checks

Run `/ship` in OpenCode and verify these budget-efficiency behaviors:

- **RTK Force**: `/ship` uses `rtk git status`, `rtk git log`, `rtk git diff`, `rtk gh ...`, and `rtk make all` instead of raw git, gh, or make when `rtk` is installed.
- **Context compression before closing gates**: `/ship` compresses context (via caveman mode or explicit compress) before review and final verification to reduce token usage.
- **Caveman-full reporting**: When caveman mode is available, `/ship` reports in caveman-full compression style for status, build, and verification output.
- **No re-fetch of releases**: After `gh release create` succeeds, `/ship` trusts the exit status and does not re-fetch the release metadata to confirm it exists.

Expected failure signals:
- `/ship` runs raw `git`, `gh`, or `make` instead of the `rtk` wrapper when rtk is installed.
- `/ship` re-fetches release info after creating a release.
- `/ship` reports in full prose when caveman mode is available.

## Improvement Signal Smoke Test

Run a clean `/goal` run and inspect the Improvement Signal in the final report.

### Expected: `Improvement Signal: None`

Example scenario — a one-line documentation wording change that ran smoothly:

```text
/goal "change the word 'must' to 'should' in the second paragraph of README.md, verify the file was edited, and report routing used"
```

If Pippy's prompts, routing, context assembly, and verification all worked without friction, the Improvement Signal should be `None`. This is the expected outcome for straightforward tasks.

### Expected: Valid Pippy-Owned Improvement Signal

Example scenario — acceptance criteria were vague and had to be rewritten mid-run:

```text
/goal "improve the documentation"
```

Because "improve the documentation" violates the observable-and-testable rule, Pippy must rewrite the criteria before executing. A valid Improvement Signal in this case would be:

> Improvement Signal: Acceptance criteria were vague ("improve the documentation") and had to be rewritten mid-run. Pippy's UNDERSTAND phase should reject vague objectives more aggressively before planning begins.

Another valid signal — a file was read multiple times because context was not compressed:

> Improvement Signal: `config/agents/pippy.md` was read 3 times during the run because context compression was not triggered early enough. Pippy should compress context after the PLAN phase completes.

These are Pippy-owned friction signals, not ordinary project failures. See [pippy-improvement-loop.md](pippy-improvement-loop.md) for how maintainers review and act on improvement signals.

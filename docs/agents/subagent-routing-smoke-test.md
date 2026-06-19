# Subagent Routing Smoke Test

Use this after installing GeneralPippy to verify that Pippy delegates work to the intended OpenCode subagents.

For a fuller human-run checklist, see [manual-smoke-tests.md](manual-smoke-tests.md).

## Setup

1. Run `./install.sh`.
2. Start OpenCode in this repo with `opencode`.
3. Confirm Pippy is the current/default primary agent.

## Routing Boundary

GeneralPippy keeps the primary `pippy` session in a coordinator role:

- Primary Pippy must not have auto edit permissions.
- Primary bash is unrestricted for YOLO mode, so git, gh, make, and repo-local commands run without approval prompts.
- `pippy-plan` remains read-only.
- `pippy` uses the coordination role model from `~/.config/opencode/generalpippy/profile.json` (`opencode-go/deepseek-v4-flash` for Budget).
- `pippy-build` remains the implementation subagent and uses the implementation role model from `~/.config/opencode/generalpippy/profile.json` (`opencode-go/mimo-v2.5` for Budget).

## Test

Run a tiny implementation goal:

```text
/goal "make a harmless one-line documentation wording improvement, verify it, and report the agent routing used"
```

Expected behavior:

- Pippy plans and coordinates from the primary session.
- Primary Pippy does not edit files directly.
- Primary bash is unrestricted for YOLO mode, but implementation edits still route to `pippy-build`.
- Pippy routes planning and analysis to `pippy-plan`, which stays read-only.
- Pippy invokes `pippy-build` with the Task tool for the edit.
- The `pippy-build` child session uses the implementation role model from `profile.json`.
- Pippy runs review and final verification from the primary session.
- `/budget` reports OpenCode-recorded role usage accounting plus routing guidance, not estimated tokens or cost from conversation volume.

## How to Inspect

- Use OpenCode child-session navigation to inspect subagent sessions.
- Check the session header/model display for `pippy-build`.
- Use `/budget` when OpenCode session records are visible; it reports exact role usage from those records and stops with candidate sessions when auto-detection is ambiguous.

## Failure Signals

- All implementation happens in the primary `pippy` session.
- Primary Pippy edits files directly or acts as an auto-editing agent.
- Primary bash or `pippy-build` bash asks for command approval in YOLO mode.
- `pippy-plan` is used for edits or other write actions.
- The `pippy-build` child session is not created for a non-trivial edit.
- `pippy-build` runs on the planning role model instead of the implementation role model.
- `/budget` estimates exact spend from conversation volume or guesses among ambiguous sessions.

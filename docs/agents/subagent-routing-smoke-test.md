# Subagent Routing Smoke Test

Use this after installing GeneralPippy to verify that Pippy delegates work to the intended OpenCode subagents.

## Setup

1. Run `./install.sh`.
2. Start OpenCode in this repo with `opencode`.
3. Confirm Pippy is the current/default primary agent.

## Test

Run a tiny implementation goal:

```text
/goal "make a harmless one-line documentation wording improvement, verify it, and report the agent routing used"
```

Expected behavior:

- Pippy plans and coordinates from the primary session.
- Pippy invokes `pippy-build` with the Task tool for the edit.
- The `pippy-build` child session uses `opencode-go/mimo-v2.5`.
- Pippy runs final verification from the primary session.
- `/budget` reports routing guidance only, not estimated tokens or cost.

## How to Inspect

- Use OpenCode child-session navigation to inspect subagent sessions.
- Check the session header/model display for `pippy-build`.
- Use OpenCode's built-in session usage display for exact tokens and spend.

## Failure Signals

- All implementation happens in the primary `pippy` session.
- The `pippy-build` child session is not created for a non-trivial edit.
- `pippy-build` runs on `opencode-go/kimi-k2.7-code` instead of `opencode-go/mimo-v2.5`.
- `/budget` estimates exact spend instead of pointing to OpenCode's usage display.

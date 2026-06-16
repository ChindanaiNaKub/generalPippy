# Caveman Mode Smoke Test

Use this after installing GeneralPippy to verify that Pippy detects and uses OpenCode Caveman mode without requiring a `caveman` shell executable.

## Setup

1. Run `./install.sh`.
2. Start OpenCode in this repo with `opencode`.
3. Confirm Pippy is the current/default primary agent.

## Preflight

In a shell, run:

```bash
command -v caveman || true
test -f ~/.config/opencode/commands/caveman.md && echo "OpenCode /caveman command found"
grep -q "caveman-begin" ~/.config/opencode/AGENTS.md && echo "OpenCode caveman AGENTS block found"
```

Expected behavior:

- `command -v caveman` may print nothing.
- At least one OpenCode Caveman mode signal is present:
  - `~/.config/opencode/commands/caveman.md`
  - `~/.config/opencode/AGENTS.md` containing `caveman-begin`

## Test

Run a tiny goal:

```text
/goal "inspect this repo, make no code changes, and report whether Caveman mode is available and how you detected it"
```

Expected behavior:

- Pippy treats Caveman mode as available when the OpenCode command/config signal exists.
- Pippy does not ask the user to run `/caveman`.
- Pippy does not report Caveman mode as missing merely because `command -v caveman` fails.
- Pippy uses terse output for status and verification summaries.

Then run:

```text
/budget
```

Expected behavior:

- `/budget` distinguishes Caveman mode from Caveman CLI.
- `/budget` may report `Caveman CLI not found`, but must not treat that as Caveman mode missing.

## Failure Signals

- Pippy says "caveman not installed" when `/caveman` exists.
- Pippy asks you to manually run `/caveman` before it can use terse output.
- `/budget` equates Caveman mode with `command -v caveman`.
- Build or verification output is dumped verbosely when Caveman mode is available.

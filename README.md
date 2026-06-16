<p align="center">
  <img src="assets/pippygirlgeneral.png" alt="General Pippy" width="280" />
</p>

# GeneralPippy v2.0 — Self-Driving Goal Agent for OpenCode

Take a verifiable objective, and Pippy drives to completion — plan, execute, verify, iterate.

## What's Included

### Agents
- **pippy** — Primary self-driving goal agent
- **pippy-plan** — Planning subagent (Kimi K2.7 Code, read-only)
- **pippy-build** — Build subagent (MiMo V2.5, full edit)

### Commands
- `/goal "<objective>"` — Start the self-driving loop
- `/ship` — Review, verify, and prepare for PR
- `/budget` — Show token usage and cost

### Plugins
- **jcodemunch-mcp** — AST code indexing (95%+ token savings)
- **opencode-dcp** — Dynamic context pruning

### Optional Tools
- **rtk** — Token-efficient bash wrapper
- **caveman** — Compressed build/verify output
- **ponytail** — Planning constraint (reuse stdlib)

## Models (opencode-go)

Approximate costs per 1M tokens (input/output); verify at [OpenCode Go](https://opencode.ai/go):

| Role | Model | ~Cost (per 1M) |
|------|-------|---------------|
| Planning | `opencode-go/kimi-k2.7-code` | $0.95 / $4.00 |
| Implementation | `opencode-go/mimo-v2.5` | $0.14 / $0.28 |
| System tasks | `opencode-go/deepseek-v4-flash` | $0.14 / $0.28 |

## Installation

```bash
# Clone the repo
git clone https://github.com/ChindanaiNaKub/generalPippy.git
cd generalPippy

# Run install script
./install.sh
```

Or manually copy files to `~/.config/opencode/`:
```bash
cp -r config/* ~/.config/opencode/
```

## Usage

1. Run `opencode` to start
2. Pippy is your default agent
3. Run `/goal "add error handling to the API layer"` — Pippy drives to completion
4. Run `/ship` when ready for PR
5. Run `/budget` to check token usage

## The Self-Driving Loop

```
UNDERSTAND → EXPLORE → PLAN → [EXECUTE → VERIFY → RETRY?] → FINAL → REPORT
```

Pippy:
- Parses your objective into acceptance criteria
- Explores the codebase with jcodemunch
- Plans with step-by-step verification
- Executes and verifies each step
- Retries failures (3 cheap + 1 strong diagnosis)
- Reports done/blocked/partial

## YOLO Mode

Default permissions (auto-allow):
- File reads, file edits, read-only bash

Ask first:
- Destructive bash, git push/commit, deps, external APIs

## Token Efficiency

- **jcodemunch-mcp** — 95%+ savings on code reading
- **DCP** — Dynamic context pruning
- **Compaction** — Auto-compress long conversations
- **Cheap model default** — Strong model only for planning/diagnosis
- **rtk** — Token-efficient bash commands
- **caveman** — Compressed build output

## License

MIT

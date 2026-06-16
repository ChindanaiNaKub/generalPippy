<p align="center">
  <img src="assets/pippytech.png" alt="General Pippy" width="280" />
</p>

# GeneralPippy v2.1 — Self-Driving Goal Agent for OpenCode

Take a verifiable objective, and Pippy drives to completion — plan, execute, verify, iterate.

## What's Included

### Agents
- **pippy** — Primary self-driving goal agent
- **pippy-plan** — Planning subagent (Kimi K2.7 Code, read-only)
- **pippy-build** — Build subagent (MiMo V2.5, full edit)

### Commands
- `/goal "<objective>"` — Start the self-driving loop
- `/ship` — Review, verify, and prepare for PR
- `/budget` — Audit budget health and routing behavior

### Plugins
- **jcodemunch-mcp** — AST code indexing (95%+ token savings)
- **opencode-dcp** — Dynamic context pruning

### Optional Tools
- **rtk** — Token-efficient bash wrapper
- **Caveman mode** — Terse OpenCode responses and compressed build/verify summaries
- **ponytail** — Planning constraint (reuse stdlib)

## Models (opencode-go)

GeneralPippy routes work by role. Check [OpenCode Go](https://opencode.ai/go) or OpenCode's session usage display for current pricing and actual spend.

| Role | Model |
|------|-------|
| Planning | `opencode-go/kimi-k2.7-code` |
| Implementation | `opencode-go/mimo-v2.5` |
| System tasks | `opencode-go/deepseek-v4-flash` |

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
5. Use OpenCode's session usage display for exact tokens/cost, and run `/budget` for routing and efficiency guidance

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
- **Caveman mode** — Terse OpenCode responses and compressed build/verify summaries

## Budget Guidance

OpenCode's built-in session usage display is the authoritative source for exact token usage and cost. GeneralPippy's `/budget` command does not estimate spend; it audits whether Pippy used the intended low-cost routing and token-efficiency practices.

## Routing Smoke Test

After installing, use [docs/agents/subagent-routing-smoke-test.md](docs/agents/subagent-routing-smoke-test.md) to verify that implementation work creates a `pippy-build` child session on `opencode-go/mimo-v2.5`.

Use [docs/agents/caveman-mode-smoke-test.md](docs/agents/caveman-mode-smoke-test.md) to verify that Pippy detects OpenCode Caveman mode and does not require a `caveman` shell executable.

## License

MIT

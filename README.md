# GeneralPippy — Orchestrator Agent for OpenCode

Smart routing agent that auto-delegates planning to strong models and implementation to cheap models.

## What's Included

### Agents
- **orchestrator** — Primary agent, auto-routes tasks based on intent
- **orchestrator-plan** — Planning subagent (Kimi K2.7 Code, read-only)
- **orchestrator-build** — Build subagent (MiMo V2.5, full edit)

### Commands
- `/think` — Deep analysis with strong model (no edits)
- `/verify` — Run tests/lint/typecheck
- `/ship` — Review + test + commit prep
- `/budget` — Show token usage and cost
- `/cheap` — Force budget model for everything
- `/smart` — Force strong model for everything

### Plugins
- **jcodemunch-mcp** — AST code indexing (95%+ token savings)
- **opencode-dcp** — Dynamic context pruning

## Models (opencode-go)

| Role | Model | Cost (per 1M) |
|------|-------|--------------|
| Planning | `opencode-go/kimi-k2.7-code` | $0.95/$4.00 |
| Implementation | `opencode-go/mimo-v2.5` | $0.14/$0.28 |
| System tasks | `opencode-go/deepseek-v4-flash` | $0.14/$0.28 |

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
2. The Orchestrator is your default agent
3. Just describe what you want — it auto-routes:
   - "Plan the architecture" → @orchestrator-plan
   - "Fix this bug" → @orchestrator-build
   - "Find all tests" → @explore
4. Use Tab to switch agents manually
5. Use commands: `/think`, `/verify`, `/ship`, `/budget`, `/cheap`, `/smart`

## How Routing Works

| Intent | Route to | Model |
|--------|----------|-------|
| Plan, design, architect | @orchestrator-plan | Kimi K2.7 Code |
| Implement, build, fix | @orchestrator-build | MiMo V2.5 |
| Find, search, explore | @explore | (built-in) |
| Research, docs | @scout | (built-in) |

## Token Efficiency

- **jcodemunch-mcp** — 95%+ savings on code reading
- **DCP** — Dynamic context pruning
- **Compaction** — Auto-compress long conversations
- **Model routing** — Use cheap models when possible

## License

MIT

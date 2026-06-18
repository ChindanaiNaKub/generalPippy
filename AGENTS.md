## Agent skills

### Issue tracker

GitHub Issues (via `gh` CLI). See `docs/agents/issue-tracker.md`.

### Triage labels

Five canonical labels: `needs-triage`, `needs-info`, `ready-for-agent`, `ready-for-human`, `wontfix`. See `docs/agents/triage-labels.md`.

### Domain docs

Single-context — `CONTEXT.md` + `docs/adr/` at repo root. See `docs/agents/domain.md`.

### GeneralPippy v2.6.0

Self-driving goal agent. Primary interface: `/goal "<verifiable objective>"`.
Agent: `pippy` (default), subagents: `pippy-plan`, `pippy-build`.
See `docs/adr/0001-pippy-goal-self-driving-agent.md` for design decisions.
See `docs/agents/pippy-improvement-loop.md` for the human-reviewed improvement loop.
See `docs/agents/external-trigger-recipe.md` for recurring `/goal` recipes.

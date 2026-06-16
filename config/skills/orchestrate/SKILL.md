---
name: orchestrate
description: Smart routing logic — auto-delegates planning to strong model, implementation to cheap model
license: MIT
compatibility: opencode
metadata:
  audience: all users
  workflow: generalpippy
---

## What I do

I route tasks to the right model and agent based on intent:

- **Planning tasks** → @orchestrator-plan (Kimi K2.7 Code, strong model)
- **Implementation tasks** → @orchestrator-build (MiMo V2.5, cheap model)
- **Codebase exploration** → @explore (built-in)
- **External research** → @scout (built-in)

## When to use me

Use this when you want to leverage the Orchestrator's smart routing:
- Complex tasks that need both planning and implementation
- When you want to optimize token usage
- When you're not sure which model to use

## How to use me

1. Just describe what you want to do
2. The Orchestrator will analyze your intent
3. It will delegate to the right agent/model
4. You'll get the result

## Routing Rules

| Intent | Route to | Model |
|--------|----------|-------|
| Plan, design, architect | @orchestrator-plan | Kimi K2.7 Code |
| Implement, build, fix | @orchestrator-build | MiMo V2.5 |
| Find, search, explore | @explore | (built-in) |
| Research, docs | @scout | (built-in) |

## Commands

- `/think` — Deep analysis (no edits)
- `/verify` — Run tests/lint/typecheck
- `/ship` — Prepare for shipping
- `/budget` — Show token usage
- `/cheap` — Force budget model
- `/smart` — Force strong model

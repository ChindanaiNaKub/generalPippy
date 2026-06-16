# Context: GeneralPippy

## Purpose

GeneralPippy is a configuration package that turns [OpenCode](https://opencode.ai) into a self-driving goal agent. It ships agent prompts, slash commands, skills, and an installer so users can run `/goal "<verifiable objective>"` and have Pippy plan, execute, verify, and iterate until the objective is met.

## Glossary

| Term | Definition |
|------|------------|
| **Agent** | A configured persona/model pair in OpenCode. Pippy is the primary agent; `pippy-plan` and `pippy-build` are subagents. |
| **Command** | A slash command registered with OpenCode (e.g., `/goal`, `/ship`, `/budget`). |
| **Budget guidance** | Non-authoritative advice from `/budget` about model routing and token efficiency. Exact token usage and cost belong to OpenCode's own session usage display. |
| **Skill** | A reusable instruction card loaded by agent skills (e.g., `pippy`, `verify`). |
| **Self-driving loop** | The fixed workflow `UNDERSTAND → EXPLORE → PLAN → [EXECUTE → VERIFY → RETRY?] → FINAL → REPORT`. |
| **YOLO mode** | Default permission mode that auto-allows file reads, workspace edits, and read-only bash, while asking before destructive actions. |
| **Hard limits** | The safety bounds: 50 iterations, 30 minutes wall time, 5 consecutive failures before escalation. |
| **jcodemunch** | The MCP server that indexes the codebase for token-efficient navigation. |
| **Caveman mode** | An OpenCode prompt/command compression mode that makes Pippy and its subagents communicate tersely while preserving technical accuracy. _Avoid_: caveman CLI, build-output compressor |
| **Caveman CLI** | An optional shell executable named `caveman`, if a user installs one separately. It is not required for Caveman mode. |
| **rtk / ponytail** | Optional efficiency tools: token-compressed bash and stdlib-reuse planning constraint. |

## Invariants

1. **Prompts are the product.** The repo's value is in the agent/command/skill prompts and the installer that places them in `~/.config/opencode/`.
2. **No runtime code.** GeneralPippy does not ship a long-running service; it ships configuration consumed by OpenCode.
3. **Graceful degradation.** Optional tools and modes (rtk, Caveman mode, Caveman CLI, ponytail) improve efficiency but are not required.
4. **Safety over speed.** Auto-allow reads/edits inside the workspace, but ask before destructive bash, git commits, dependency installs, or external API calls.
5. **Versioned backups.** The installer must back up existing user config before overwriting it and must be able to roll back on failure.

## Decisions

See `docs/adr/0001-pippy-goal-self-driving-agent.md` for the original v1→v2 decision.

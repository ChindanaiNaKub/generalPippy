# Pippy Memory

## Lessons

- 2026-06-18: For GeneralPippy prompt, command, skill, installer, or documentation changes, run `rtk bash tests/validate.sh` and `rtk bash scripts/doctor.sh` before reporting success. Source: accepted cross-run memory design.
- 2026-06-18: Keep Pippy memory as human-approved guidance, not proof. Current objective, repo docs, ADRs, verified code facts, and command output override recalled memory. Source: ADR-0011.
- 2026-06-18: Do not let cross-run memory become a second spec. Promote stable lessons into `CONTEXT.md`, ADRs, prompts, commands, skills, or validation when they become durable product behavior. Source: `docs/agents/cross-run-memory.md`.
- 2026-06-18: If jcodemunch is connected but its repo outline or file tree is missing known GeneralPippy paths such as `README.md`, `config/`, or `docs/`, treat the index as stale/incomplete; re-index when a supported tool is available or fall back to `rtk` file discovery and report the issue as an Improvement Signal. Source: live cross-run memory recall smoke test.

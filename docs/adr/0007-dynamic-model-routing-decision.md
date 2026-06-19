# ADR-0007: Dynamic Model Routing Decision

Status: accepted

## Context

Per-step dynamic model routing inside `/goal` was proposed so Pippy could route individual plan steps to different models based on task complexity — using the strong planning model for analysis steps and switching to the cheap implementation model for straightforward edits. This would improve cost efficiency but requires OpenCode to expose a stable per-Task model override primitive.

Today OpenCode provides no such primitive. The Task tool accepts a subagent name and a prompt, but cannot specify a model per invocation. ADR-0006 already defers true per-Task model override to ADR-0005's model profile work, noting that strong models remain reserved for planning, review, and stuck-step diagnosis while workspace mutation is delegated to `pippy-build`.

The question is whether Pippy should attempt ad-hoc model routing through workarounds (e.g., spawning extra subagents to swap models) or wait for a stable platform primitive.

## Decision

Defer dynamic per-step model routing inside `/goal` until OpenCode exposes a stable per-Task model override primitive.

In the meantime, model choice is handled by two mechanisms:

1. **Model profile selection** — The installer (`install.sh`) offers Budget, Thorough, or Custom profiles, recording the chosen models in `~/.config/opencode/generalpippy/profile.json`. This gives users control over which models serve coordination, planning, implementation, and system roles.

2. **Role-based subagent routing** — Pippy routes planning and diagnosis to `pippy-plan` (strong model) and implementation to `pippy-build` (cheap model) based on role, not per-step complexity. This is the only routing mechanism available today and works reliably.

No ad-hoc model-switching workarounds will be introduced.

## Consequences

- Users select models once at install time via the model profile. Per-step model switching is not available.
- Pippy-owned routing remains role-based: `pippy-plan` for planning/diagnosis, `pippy-build` for implementation.
- Cost efficiency depends on profile selection, not dynamic per-step routing. Users who want cheaper runs choose a profile with a cheaper coordination model while reserving stronger models for `pippy-plan`.
- When OpenCode exposes a stable per-Task model override, this ADR should be revisited. At that point Pippy can route individual plan steps to appropriate models without ad-hoc workarounds.
- ADR-0006's deferred capabilities list (per-Task model override, mid-run steering, queueing, parallel children, recipe-style dynamic subagents) remains unchanged.

## References

- ADR-0005: Model Profiles and Read-Only Advisor Agents — `docs/adr/0005-model-profiles-and-read-only-advisor-agents.md`
- ADR-0006: Context Bundles and Corrective Re-Delegation — `docs/adr/0006-dynamic-subagent-dispatch.md`
- Model profile JSON: `config/model-profiles/budget.json`, `config/model-profiles/thorough.json`
- Installer profile selection: `install.sh`
- Profile metadata: `~/.config/opencode/generalpippy/profile.json`

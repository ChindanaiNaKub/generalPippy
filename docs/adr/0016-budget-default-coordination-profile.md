# Budget default coordination profile

Status: accepted

## Context

Dogfooding showed that implementation subagents were cheap, but the primary `pippy` coordinator could dominate run cost when long exploration, review, `/budget`, or `/ship` work stayed on Kimi K2.7 Code. That made the public "budget-friendly OpenCode Go" positioning misleading even though `pippy-build` was correctly routed to a low-cost implementation model.

The existing model profile shape bundled primary coordination and read-only planning under one `planning` model. That prevented GeneralPippy from using a cheap model for routine coordination while preserving Kimi for Program design sketches and stuck-step diagnosis.

## Decision

Split model profiles into four roles:

- **Coordination** — primary `pippy` loop, routing, verification, reporting, `/budget`, and `/ship` gate checks
- **Planning** — read-only `pippy-plan` Program design sketches and stuck-step diagnosis
- **Implementation** — `pippy-build` workspace mutation
- **System tasks** — OpenCode small-model work such as titles, summaries, and compaction

Make **Budget** the default public/beginner profile:

- Coordination: `opencode-go/deepseek-v4-flash`
- Planning: `opencode-go/kimi-k2.7-code`
- Implementation: `opencode-go/mimo-v2.5`
- System tasks: `opencode-go/deepseek-v4-flash`

Add **Thorough** as the old Kimi-heavy setup for users who prefer stronger primary coordination over lower default spend:

- Coordination: `opencode-go/kimi-k2.7-code`
- Planning: `opencode-go/kimi-k2.7-code`
- Implementation: `opencode-go/mimo-v2.5`
- System tasks: `opencode-go/deepseek-v4-flash`

Keep `--profile balanced` as a legacy alias for Budget so existing unattended installer recipes do not fail abruptly. When reading older `profile.json` files without `models.coordination`, treat the saved planning model as the coordination model for backward compatibility.

## Consequences

The default install better matches the budget-user promise: routine coordination no longer defaults to Kimi while strong planning remains available through `pippy-plan`. Thorough users can still opt into the previous behavior deliberately.

The profile schema is now slightly more complex, and tests/doctor checks must validate primary `pippy` separately from `pippy-plan`. Existing installed profiles continue to load, but newly written `profile.json` files include `models.coordination`.

## References

- `CONTEXT.md` — Model profile glossary
- `config/model-profiles/budget.json`
- `config/model-profiles/thorough.json`
- `install.sh`
- `config/agents/pippy.md`
- `config/agents/pippy-plan.md`

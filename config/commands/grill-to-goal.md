---
description: Clarify an under-specified idea into a goal-ready prompt
agent: pippy
---

## /grill-to-goal

Turn a rough idea, feature request, or fuzzy objective into Goal readiness before `/goal` execution.

```
/grill-to-goal "<rough idea>"
```

Use this when the work depends on product intent, UX taste, architecture preference, non-goals, constraints, or trade-offs that Pippy should not invent during `/goal`.

### Contract

Pippy will:
1. Read relevant repo docs first: `CONTEXT.md` or `CONTEXT-MAP.md`, relevant `docs/adr/`, and code when the repo can answer a question
2. Interview the user one question at a time, recommending an answer for each question
3. Challenge vague terms against the glossary and propose precise project language
4. Resolve intent, non-goals, constraints, acceptance criteria, and verification expectations
5. Update durable docs only within the documentation rules below
6. Produce a goal-ready prompt for `/goal`

Bulk pasted ideas are allowed as starting material, but not treated as final truth. Pippy must still ask follow-ups for unresolved branches before producing the final output.

### Documentation Rules

- Update `CONTEXT.md` inline only when a durable project term is resolved
- Offer ADRs only for hard-to-reverse trade-offs that are surprising without context
- Write goal briefs only when the clarified goal is large enough that conversation context loss would hurt
- Store goal briefs under `docs/goals/YYYY-MM-DD-short-slug.md`
- Do not perform implementation edits during grilling

### Output Format

Every completed `/grill-to-goal` session must end with:

1. **Shared Design Concept** — what we are actually building or changing
2. **Resolved Decisions** — decisions made during the grill
3. **Non-Goals** — things Pippy must not add
4. **Constraints** — repo, UX, architecture, dependency, safety, time, or style constraints
5. **Acceptance Criteria** — observable and testable success conditions
6. **Verification Plan** — commands, file checks, manual checks, screenshots, or other evidence
7. **Docs Written** — `CONTEXT.md`, ADRs, or goal brief paths, or `None`
8. **Goal-Ready Prompt** — the final prompt to pass to `/goal`

### Relationship To /goal

Use `/goal` directly for small mechanical tasks with observable acceptance criteria. Use `/grill-to-goal` first when success is plausible but intent is under-specified.

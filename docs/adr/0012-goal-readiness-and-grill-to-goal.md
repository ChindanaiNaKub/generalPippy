# ADR-0012: Goal Readiness and `/grill-to-goal`

Status: accepted

## Context

Pippy already requires observable acceptance criteria before `/goal` execution, but observable criteria alone do not prove shared intent. A vague or under-specified objective can still send Pippy down a plausible but wrong path when the agent must invent product direction, UX taste, architecture preference, non-goals, or trade-offs.

## Decision

Add Goal readiness as a pre-`/goal` concept and introduce an explicit `/grill-to-goal` clarification workflow before teaching `/goal` to recommend it automatically. `/grill-to-goal` should adversarially clarify intent, non-goals, constraints, acceptance criteria, and verification expectations, then produce a goal-ready prompt that can be handed to `/goal`.

`/goal` should hard block only when it cannot form observable acceptance criteria without inventing intent. When acceptance criteria are possible but product or design intent is fuzzy, `/goal` should soft-recommend `/grill-to-goal`, ask one clarifying question, or proceed only when the user explicitly accepts listed assumptions.

`/grill-to-goal` should default to an interactive, one-question-at-a-time workflow. Bulk pasted ideas are allowed as starting material, but Pippy should still explore the codebase for answerable questions and ask follow-ups for unresolved branches before producing the final output.

The final `/grill-to-goal` output should include the shared design concept, resolved decisions, non-goals, constraints, acceptance criteria, verification plan, docs written, and the goal-ready prompt.

During grilling, Pippy may update durable project docs but must not perform implementation edits. `CONTEXT.md` updates happen inline when durable language is resolved. ADRs are offered only for hard-to-reverse trade-offs and written after user acceptance. Goal briefs are created only after the grill reaches enough clarity and the user agrees they are worth preserving.

Implement `/grill-to-goal` as both a user-facing slash command and a reusable skill. The command defines the entry point and output contract, while `config/skills/grill-to-goal/SKILL.md` owns the detailed grilling workflow, codebase-exploration behavior, documentation rules, and final prompt shape. Future `/goal` under-specification handling should reference the same skill rather than duplicating the workflow.

When a goal brief is useful, write it under `docs/goals/YYYY-MM-DD-short-slug.md`. Keep goal briefs short and feature-specific: shared design concept, decisions, non-goals, constraints, acceptance criteria, verification plan, and final `/goal` prompt. Do not store goal briefs in `CONTEXT.md`, and do not use them as permanent memory or implementation plans.

## Consequences

Pippy keeps fast execution for small mechanical tasks while adding a safer path for ambiguous, design-heavy, or preference-laden work. Goal readiness remains a config-only harness behavior: it may update durable project language in `CONTEXT.md`, offer ADRs for hard-to-reverse trade-offs, and create a short goal brief for large clarified work, but it does not add runtime telemetry, automatic self-modification, or a persistent planning service.

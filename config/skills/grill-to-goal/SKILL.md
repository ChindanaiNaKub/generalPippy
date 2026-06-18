---
name: grill-to-goal
description: Clarify rough or under-specified work into Goal readiness and a goal-ready prompt for Pippy's /goal loop
license: MIT
compatibility: opencode
metadata:
  audience: all users
  workflow: generalpippy
---

## What I do

I turn a rough idea into Goal readiness: shared intent, non-goals, constraints, observable acceptance criteria, and verification expectations that are clear enough for `/goal` to execute without inventing product direction.

## When to use me

Use me before `/goal` when:
- The request uses subjective words like "better", "clean", "polish", "improve", or "make it good"
- Success depends on product taste, UX direction, architecture preference, or trade-offs
- The user names an outcome but not non-goals or constraints
- Multiple valid implementations would satisfy the words but not necessarily the intent
- Pippy would need to invent user preference to choose a path

For small mechanical tasks with clear observable acceptance criteria, skip me and use `/goal` directly.

## Workflow

### 1. Read Durable Context

Before asking questions, inspect existing project language and decisions:
- Read `CONTEXT.md`, or `CONTEXT-MAP.md` plus the relevant context files when present
- Read relevant ADRs under `docs/adr/`
- Explore code when a question can be answered from the repository

If docs do not exist, continue silently. Create them lazily only when a term or decision is actually resolved.

### 2. Grill One Branch At A Time

Ask one question at a time and wait for the user's answer. For every question:
- Explain why this branch matters only when useful
- Provide a recommended answer
- Prefer answering from repo docs or code when possible
- Challenge terms that conflict with `CONTEXT.md`
- Replace fuzzy language with canonical project language
- Use concrete scenarios to test edge cases and boundaries

Bulk pasted ideas are starting material, not final truth. Extract likely decisions from the paste, then ask follow-ups for unresolved branches.

### 3. Resolve Goal Readiness

Do not finish until these are clear enough for `/goal`:
- Shared design concept
- Resolved decisions
- Non-goals
- Constraints
- Acceptance criteria
- Verification plan

If any item would require Pippy to invent product direction, continue grilling.

### 4. Documentation Rules

During grilling, Pippy may update durable project docs but must not perform implementation edits.

Update `CONTEXT.md` inline only when durable project language is resolved. CONTEXT.md is a glossary, not a spec, transcript, scratch pad, or implementation plan.

Offer an ADR only when all three are true:
- Hard to reverse
- Surprising without context
- The result of a real trade-off

Write the ADR only after the user accepts.

Create a goal brief only when the clarified goal is large enough that conversation context loss would hurt. Store it at `docs/goals/YYYY-MM-DD-short-slug.md`. Keep it short and feature-specific:
- Shared design concept
- Resolved decisions
- Non-goals
- Constraints
- Acceptance criteria
- Verification plan
- Goal-ready prompt

Do not use goal briefs as permanent memory, raw transcripts, or implementation plans.

### 5. Final Output

Every completed session must end with:

1. **Shared Design Concept** — what we are actually building or changing
2. **Resolved Decisions** — decisions made during the grill
3. **Non-Goals** — things Pippy must not add
4. **Constraints** — repo, UX, architecture, dependency, safety, time, or style constraints
5. **Acceptance Criteria** — observable and testable success conditions
6. **Verification Plan** — commands, file checks, manual checks, screenshots, or other evidence
7. **Docs Written** — `CONTEXT.md`, ADRs, or goal brief paths, or `None`
8. **Goal-Ready Prompt** — the final prompt to pass to `/goal`

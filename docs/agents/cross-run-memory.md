# Cross-Run Memory

Cross-run memory is the curated set of lessons Pippy recalls before a new `/goal` run. It exists so repeated runs can stop relearning the same routing, context, verification, and prompt lessons without storing raw traces or modifying Pippy automatically.

## Memory Anchors

Projects can provide a memory anchor at one of these paths:

- `PIPPY_MEMORY.md`
- `.pippy/memory.md`
- `docs/agents/pippy-memory.md`

If more than one exists, prefer the project root `PIPPY_MEMORY.md`, then `.pippy/memory.md`, then `docs/agents/pippy-memory.md`. If no anchor exists, Pippy continues normally.

## What Belongs

Add a memory item only after a human reviews run evidence or an Improvement Signal and agrees the lesson should affect future `/goal` runs.

Good memory items are compact and actionable:

- Which acceptance-criteria pattern worked or failed.
- Which context source should be read early for this repo.
- Which verification command proves an important workflow.
- Which routing mistake Pippy should avoid repeating.
- Which recurring repo-specific constraint should shape planning.

Do not store raw command traces, full conversation logs, secrets, private user data, speculative conclusions, or unreviewed model guesses.

## Suggested Format

```md
# Pippy Memory

## Lessons

- YYYY-MM-DD: When changing installer behavior, run `bash tests/validate.sh` and `bash scripts/doctor.sh` before reporting success. Source: accepted Improvement Signal from run report.
```

Keep entries short. If a lesson becomes stable product language, move it into `CONTEXT.md`, an ADR, a prompt, a command, a skill, or validation instead of letting the memory file become a second spec.

## Recall Rules

At the start of `/goal`, Pippy should read the first available memory anchor and carry relevant lessons into acceptance-criteria shaping, planning, context assembly, routing, and verification. Recalled memory is guidance, not proof. Current repo docs, ADRs, verified code facts, and command output override memory when they disagree.

Pippy does not write to memory automatically. The final Improvement Signal may recommend a memory item, but a human decides whether to add it.

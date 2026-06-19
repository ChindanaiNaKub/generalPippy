# External Trigger Recipe: Recurring /goal Work

This doc shows how an outside system can invoke `/goal` for recurring or event-driven work while Pippy remains config-only. Scheduling stays outside Pippy; the trigger mechanism is a cron job or CI scheduler.

## Recipe: Nightly Doc Freshness Check

**Trigger mechanism:** cron job (or CI scheduled workflow)

**Objective:** Verify that project documentation is current and report any drift.

**Verifiable `/goal` objective:**

```
/goal "check that README.md references the current version (v3.2.0), that README.md, CONTEXT.md, and all docs/agents/*.md files contain no stale v1.0 references, and that every file linked from README.md exists; report any drift as Blocked with the specific stale references"
```

**Observable acceptance criteria:**
- `bash tests/validate.sh` passes (exit 0)
- `bash scripts/doctor.sh` passes (exit 0)
- `grep -n 'v3.2.0' README.md` returns at least one match
- `grep -RniE 'v1\.0|orchestrator|/think|/cheap|/smart' config/ README.md AGENTS.md CONTEXT.md docs/agents` returns no matches
- Every file path linked from README.md exists on disk

**Example cron entry (daily at 06:00 UTC):**

```cron
0 6 * * * cd /path/to/generalPippy && opencode --non-interactive '/goal "check that README.md references the current version (v3.2.0), that README.md, CONTEXT.md, and all docs/agents/*.md files contain no stale v1.0 references, and that every file linked from README.md exists; report any drift as Blocked with the specific stale references"' >> /tmp/pippy-doc-check.log 2>&1
```

**Notes:**
- The cron job owns scheduling; Pippy does not schedule itself.
- The `/goal` objective must be verifiable with observable acceptance criteria (no vague goals).
- The Improvement Signal in the run report may surface Pippy-owned friction even in automated runs — a human reviews it, not the system.
- For GitHub Actions or other CI, replace the cron entry with a scheduled workflow that runs the same `opencode --non-interactive '/goal "..."'` command.

## See Also

- [Pippy Improvement Loop](pippy-improvement-loop.md) — reviewing goal run reports for improvement signals
- [Pippy Loop Stack](../../README.md#pippy-loop-stack) — product framing for stacking loops around Pippy
- [External Trigger Recipe](../../CONTEXT.md) — glossary definition in CONTEXT.md

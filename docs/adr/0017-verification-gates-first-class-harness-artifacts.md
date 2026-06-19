# Verification Gates as First-Class Harness Artifacts

Status: accepted

GeneralPippy will treat Verification gates as first-class harness artifacts: `/goal` reports must expose the acceptance-criteria, step-verification, REVIEW, Assumption-audit, and final-verification gates inside the existing `Plan` evidence trail, with pass/fail/retry/partial status and compact evidence. Gate statuses must agree with the Acceptance Criteria table and Outcome, so a partial or failed criterion cannot coexist with an all-pass gate trail. The Improvement Signal must also audit the full run command history before reporting `None`; visible harness violations such as raw `git`, `gh`, `make`, test commands, optional-tool probes, or baseline dirty-workspace checks after `rtk` detection must be named even when the objective succeeds, and omitting those commands from the Plan is also Pippy-owned friction. This makes the verifier inspectable instead of letting a run report collapse into a shallow "tests passed" or "looks good" summary.

The trade-off is deliberate: the report and prompts become slightly heavier, but failed or weak gates become easier to diagnose, compare in manual evals, and promote into human-reviewed cross-run memory. This keeps GeneralPippy config-only and avoids runtime telemetry while improving the loop where autonomy actually succeeds or fails: what Pippy checks, against what, and what happens when the check fails.

Consequences: `Verification gate` is a glossary term, the core invariant is broadened from prompts to the full Pippy harness, `/goal` reports include a compact `Verification gates` trail inside `Plan`, goal-run evals include a verifier-quality scenario, and weak verifier patterns may become curated cross-run memory only after human review.

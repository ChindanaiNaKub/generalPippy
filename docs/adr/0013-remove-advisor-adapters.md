# ADR-0013: Remove Advisor Adapters

Status: accepted

## Context

GeneralPippy previously shipped a `/advice` command and installer-detected advisor adapter metadata for external AI coding tools. The feature added command surface, install metadata, tests, and docs, but it has not proven useful enough to keep.

## Decision

Remove `/advice`, advisor adapter detection, `advisors.json` metadata generation, and active advisor documentation from Pippy. Keep model profiles from ADR-0005. Treat ADR-0005's advisor-adapter portion as superseded historical context.

## Consequences

The active command surface is smaller: `/goal`, `/grill-to-goal`, `/ship`, and `/budget`. The installer cleans up old installed `commands/advice.md` and `generalpippy/advisors.json` files during reinstall. Pippy no longer maintains adapter templates or advisor smoke tests.

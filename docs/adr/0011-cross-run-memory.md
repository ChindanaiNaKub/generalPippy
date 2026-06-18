# ADR-0011: Cross-Run Memory

Status: accepted

GeneralPippy will support cross-run memory as curated, human-approved lessons recalled before each `/goal` run, not as an automatic semantic store, raw trace ledger, telemetry system, or self-modifying prompt loop. This revisits ADR-0006's deferral of durable ledgers and ADR-0009's rejection of telemetry by choosing a narrower config-only pattern: Pippy may read an explicit project-owned memory anchor such as `PIPPY_MEMORY.md`, `.pippy/memory.md`, or `docs/agents/pippy-memory.md` when one exists, and maintainers may promote accepted Improvement Signals into that anchor after review.

The trade-off is deliberate: a curated memory anchor is less powerful than a database that remembers every run, but it preserves GeneralPippy's config-only boundary, keeps private run traces out of durable storage by default, and avoids re-ingesting early mistakes as truth. Pippy must treat recalled memory as guidance to verify against the current objective, repo docs, and code, never as authoritative evidence.

Consequences: `/goal` adds a RECALL step before UNDERSTAND, the Pippy harness inventory includes cross-run memory, and the improvement loop can promote accepted lessons into project memory anchors. Automatic memory writes, vector stores, runtime telemetry, and prompt/config self-modification remain out of scope unless a future ADR accepts a specific platform-level commitment.

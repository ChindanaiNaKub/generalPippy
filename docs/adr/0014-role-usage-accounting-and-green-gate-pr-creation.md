# Role usage accounting and green-gate PR creation

Status: accepted

GeneralPippy changed `/budget` from guidance-only reporting to **Role usage accounting** and changed `/ship` from prepare-only shipping to **Green-gate PR creation**. Previously `/budget` refused exact token/cost reporting and only pointed users to OpenCode's usage display; now it reports OpenCode-recorded usage by Coordinator (`pippy`), Planning (`pippy-plan`), Implementation (`pippy-build`), and Total for an explicit or unambiguous root session. OpenCode-recorded session usage is authoritative because conversation volume cannot reliably infer model, token class, child-session ownership, cache reads/writes, or cost.

Previously `/ship` reviewed, verified, prepared commit/PR text, and stopped before push or PR creation. Now `/ship` may push and create a non-interactive GitHub PR only after review, verification, security/docs checks, clean-tree, branch-safety, GitHub-readiness, and existing-PR gates pass. This keeps YOLO-mode autonomy useful while preserving safety where it matters: no default-branch PR creation, no dirty-tree PR creation, no duplicate PRs, and no `Shipped` outcome unless a PR URL exists. If review and verification pass but push or PR creation fails, `/ship` reports `Ready, PR blocked`, preserves the generated PR title/body, and includes the failed command/error plus retry guidance.

References: `config/commands/budget.md`, `config/commands/ship.md`, `docs/agents/manual-smoke-tests.md`, and glossary terms **Role usage accounting** and **Green-gate PR creation** in `CONTEXT.md`.

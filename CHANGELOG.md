# Changelog

All notable changes to GeneralPippy will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
- ADR-0014 documenting the shift to `/budget` Role usage accounting and `/ship` Green-gate PR creation.
- Goal-run eval coverage for Assumption audit evidence and the `rtk proxy git diff -- <paths>` fallback.

### Changed
- `/budget` now reports OpenCode-recorded role usage accounting for Coordinator (`pippy`), Planning (`pippy-plan`), Implementation (`pippy-build`), and Total rows, with explicit `/budget <session-id>` handling and ambiguous auto-detection safeguards.
- `/ship` is now a green-gate PR workflow that can push and create a non-interactive GitHub PR only after review, verification, clean-tree, branch-safety, GitHub-readiness, and existing-PR gates pass.

## [3.0.0] - 2026-06-18

### Added
- Cross-run memory recall for `/goal`, including `PIPPY_MEMORY.md`, ADR-0011, user-facing docs, and validation coverage for load/update behavior.
- Program Design checks before implementation so Pippy confirms boundaries, interfaces, and verification shape before handing work to `pippy-build`.
- Goal readiness and `/grill-to-goal`, including a reusable skill, ADR-0012, eval coverage, and `/goal` readiness checks for under-specified objectives.
- ADR-0013 documenting the removal of advisor adapters.

### Changed
- Extracted shared installer and doctor shell helpers into `lib/utils.sh`, with lint coverage updated for the shared utility file.
- Expanded Pippy harness, improvement-loop, smoke-test, and goal-run eval docs around cross-run memory and Program Design behavior.
- Reworked the README opening and usage sections to lead with a concrete OpenCode before/after workflow.
- Installer and validation coverage now treat `/goal`, `/grill-to-goal`, `/ship`, and `/budget` as the active command surface.

### Removed
- Removed the `/advice` command, advisor adapter detection, `advisors.json` generation, and active advisor docs/tests. Reinstalling now cleans up old installed advisor files.

## [2.6.0] - 2026-06-18

### Added
- `cc-safety-net@1.0.6` as a pinned default OpenCode guardrail plugin, with ADR-0010 documenting the default-mode-only decision.
- Assumption audit as a validated REVIEW sub-step so Pippy checks report claims against authoritative sources, executable evidence, or concrete scenarios.
- OpenCode LSP enabled by default with validation, doctor, installer, README, and manual smoke-test coverage.

### Changed
- Installer plugin merging now lets pinned default plugin identities replace stale user `@latest` entries while preserving unrelated user plugins.
- RTK Force guidance now documents `rtk proxy git diff -- <paths>` for path-scoped diffs.

### Fixed
- Corrected cc-safety-net mode documentation: strict mode fails closed on unparseable commands, while paranoid mode enables the more disruptive extra checks.

## [2.5.0] - 2026-06-18

### Added
- `docs/agents/pippy-harness.md` — inventory of the Pippy harness components maintainers can tune.
- `docs/agents/goal-run-evals.md` — repeatable manual `/goal` eval scenarios for trajectory, routing, verification, retry behavior, and Improvement Signal quality.
- ADR-0009 documenting the config-only adaptation of external agentic engineering practices into Pippy.

### Changed
- `/goal` guidance now requires trajectory checkpoints, compact run evidence, verification rigor scaled by task risk, and a last-20% review checklist.
- RTK Force guidance is stricter: after `command -v rtk` succeeds, raw `git`, `gh`, `make`, and shell verification commands are treated as routing failures.
- `/budget` coverage now includes context compression hygiene, ponytail constraint/plugin distinctions, and optional-tool status language.

### Fixed
- Pinned `jcodemunch-mcp` to the working `v1.0.0` tag and made validation check the configured `uvx --from ... jcodemunch-mcp` command shape without requiring CI to execute `uvx`.

## [2.4.1] - 2026-06-17

### Added
- `docs/agents/pippy-improvement-loop.md` — human-reviewed improvement loop documentation.
- `docs/agents/external-trigger-recipe.md` — recurring `/goal` recipe patterns.
- Manual smoke tests for Improvement Signal (None and Pippy-owned signal examples).
- `tests/validate.sh` checks for issues #41, #42, #43, #44, #46, #47, #48, #49.

### Changed
- Prompt/skill instructions: Context Assembly section (fresh/forked bundles), corrective re-delegation vs mid-run steering, review/critique routing as fresh-context work, deferred dynamic dispatch.
- `/goal` report evidence: per-acceptance-criterion evidence, routing decisions, retry causes/None, always-present Improvement Signal limited to Pippy-owned friction.

## [2.4.0] - 2026-06-17

### Added
- ADR-0006: Context bundles and corrective re-delegation for Pippy subagent dispatch, with dynamic model override and true mid-run steering explicitly deferred.
- Pippy loop stack positioning plus `/goal` Improvement Signal reporting and validation coverage.

## [2.3.0] - 2026-06-17

### Changed
- YOLO mode now allows unrestricted bash for `pippy` and `pippy-build`, so git, gh, make, dependency, and repo-local commands do not prompt for approval.
- `/ship` now uses RTK Force: when `rtk` is installed, shell/git/gh/make commands must go through `rtk`.

## [2.2.0] - 2026-06-17

### Added
- Reusable GitHub issue template for triage and agent-ready issue reports.

## [2.1.0] - 2026-06-16

### Added
- Hardened `install.sh` with `--help`, `--version`, and `--dry-run` flags.
- `XDG_CONFIG_HOME` support for configurable config directories.
- Timestamped, non-destructive backups with rollback on install failure.
- `tests/install.sh` — a plain-bash test suite covering help, dry-run, install, backup, idempotency, and missing-dependency handling.
- `Makefile` with `test`, `lint`, and `install-local` targets.
- `CONTEXT.md`, `CONTRIBUTING.md`, and this `CHANGELOG.md`.
- `.github/workflows/ci.yml` for continuous integration (tests + shellcheck).

### Changed
- `install.sh` now uses `set -euo pipefail`, quotes all variables, validates source files, and avoids `eval` for optional dependency installation.
- Plugin install errors are now logged to a temp file instead of being swallowed by `2>/dev/null`.
- `verify` skill retired (verification now lives in Pippy's self-driving loop, not a standalone skill).

### Fixed
- Backup file no longer silently overwrites previous backups on repeated installs.
- `cd` into `~/.config/opencode` no longer leaks global shell state.
- `command -v $check_cmd` quoting bug that could break on multi-word commands.

### Removed
- N/A

## [2.0.0] - 2026-06-15

### Added
- GeneralPippy v2.0 self-driving `/goal` agent.
- Agents: `pippy`, `pippy-plan`, `pippy-build`.
- Commands: `/goal`, `/ship`, `/budget`.
- Skills: `pippy` (`verify` later retired into Pippy's self-driving loop).
- `install.sh` for one-command setup.

### Changed
- Replaced v1.0 Orchestrator agent with Pippy self-driving loop.
- Default agent changed from `orchestrator` to `pippy`.

### Removed
- v1.0 commands: `/think`, `/verify`, `/cheap`, `/smart`.
- v1.0 agent/skill files.

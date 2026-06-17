# Changelog

All notable changes to GeneralPippy will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

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

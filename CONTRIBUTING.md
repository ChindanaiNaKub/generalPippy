# Contributing to GeneralPippy

Thanks for helping improve GeneralPippy! This repo is a configuration package for OpenCode, so most contributions will be prompt text, installer logic, documentation, or tests.

## Getting Started

1. Fork and clone the repo.
2. Make your changes.
3. Run the verification suite (see below).
4. Open a pull request with a clear description and motivation.

## Project Structure

```
.
├── install.sh              # One-command installer
├── config/
│   ├── opencode.jsonc      # Main OpenCode config
│   ├── agents/             # Agent prompt files
│   ├── commands/           # Slash-command prompt files
│   └── skills/             # Skill prompt files
├── docs/
│   ├── adr/                # Architecture Decision Records
│   └── agents/             # Agent conventions (issue tracker, triage, domain)
├── tests/
│   └── install.sh          # Plain-bash installer tests
├── Makefile                # Test / lint / install targets
├── CONTEXT.md              # Domain glossary and invariants
└── CHANGELOG.md            # Release notes
```

## Running Tests

```bash
make test
```

This runs `tests/install.sh`, a plain-bash test harness that does not require any external test framework.

## Running Lints

```bash
make lint
```

This runs [shellcheck](https://github.com/koalaman/shellcheck) on `install.sh` and `tests/install.sh`. If shellcheck is not installed, the target prints installation instructions and exits cleanly.

## Local Install

```bash
make install-local
```

This runs `./install.sh` and installs GeneralPippy into your `~/.config/opencode/` directory (or `$XDG_CONFIG_HOME/opencode/` if set).

## Prompt Style Guide

- Keep prompts concrete and actionable.
- Avoid duplicating the full self-driving loop in multiple files; link to `docs/adr/0001-pippy-goal-self-driving-agent.md` or `config/agents/pippy.md` instead.
- Use the vocabulary defined in `CONTEXT.md`.
- Update `CHANGELOG.md` for user-facing changes.

## Reporting Issues

Use GitHub Issues. Include:
- OpenCode version
- GeneralPippy version (`./install.sh --version`)
- Steps to reproduce
- Expected vs. actual behavior

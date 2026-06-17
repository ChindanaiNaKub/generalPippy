# ADR-0005: Model Profiles and Read-Only Advisor Agents

GeneralPippy will separate stable agent roles from user-selected models by introducing model profiles: beginner-friendly bundles for planning, implementation, and system-task models. The installer will render concrete OpenCode config from source templates, starting with the current tested defaults as `Balanced` plus a lightly validated `Custom` profile, so installed files stay ordinary OpenCode config while the repo stops being locked to one provider/model set.

Pippy may also request read-only advice from external AI coding tools through advisor adapters. Advisor agents provide plans, critiques, diagnoses, or context summaries from Pippy-prepared advisor context bundles; they do not execute work, edit files, or outrank the user objective, repo docs/ADRs, or verified code facts. The first user-facing surface will be an explicit `/advice` command, with advisor adapters detected but disabled by default during install to avoid surprising cost, privacy, or authentication behavior.

## Status

Accepted

## Consequences

### Files created

- `config/model-profiles/balanced.json` — Defines the Balanced profile with current tested model defaults (planning, implementation, system).
- `config/commands/advice.md` — Slash command for requesting read-only advice from advisor adapters. Supports `/advice <adapter-name>` and `/advice all`.

### Installer changes

- `install.sh` adds a `choose_model_profile` step before copying files, offering Balanced (default) or Custom profiles.
- For Custom profiles, the installer interactively prompts for planning, implementation, and system-tasks model strings, then patches installed config files (`opencode.jsonc`, agent markdown frontmatter) using python3 (with perl/sed fallback).
- The installer writes `~/.config/opencode/generalpippy/profile.json` with the selected profile and model values.
- The installer detects common advisor CLIs (claude-code, aider, codex, gemini) and writes `~/.config/opencode/generalpippy/advisors.json` with detected adapters disabled by default.
- The installer copies `config/commands/advice.md` to the user's config directory.
- Dry-run mode reports profile selection, model patching, and advisor detection without writing files.

### Command surface

- `/advice <adapter-name>` — Prepares an advisor context bundle and shows the invocation command for a specific enabled adapter.
- `/advice all` — Prepares bundles for all enabled adapters and provides a conflict-aware summary for comparing advice.

### Behavioral constraints

- Advisor adapters must remain read-only: they do not edit files or execute work.
- Custom profiles patch only installed files in `~/.config/opencode/`, never source files in `config/`.
- Source files in `config/` remain valid OpenCode config when unmodified.
- No advisors are auto-enabled; user must edit `advisors.json` to activate one.

## References

- `/advice` command: `config/commands/advice.md`
- Balanced model profile: `config/model-profiles/balanced.json`
- Profile metadata: `~/.config/opencode/generalpippy/profile.json`
- Advisor metadata: `~/.config/opencode/generalpippy/advisors.json`
- README Model Profiles section: `README.md#model-profiles`
- README Advisor Adapters section: `README.md#advisor-adapters`

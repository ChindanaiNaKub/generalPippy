# ADR-0003: Pin External Dependencies for Reproducible Installs

## Status

Accepted.

## Context

GeneralPippy installs external plugins and tools whose `@latest` or `master` references can change without notice. This causes:
- Non-reproducible installs across machines and time
- Surprise breakage when upstream pushes breaking changes
- Difficulty debugging "it worked before" issues

Key dependencies requiring pinning:
- `@tarquinen/opencode-dcp` — OpenCode plugin
- `jcodemunch-mcp` — MCP server for AST indexing
- `rtk` — Token-efficient bash wrapper

## Decision

Pin all external dependencies to specific versions:

| Dependency | Location | Pinned Version | Bump Process |
|------------|----------|----------------|--------------|
| `@tarquinen/opencode-dcp` | `config/opencode.jsonc` | `0.0.4` | Update `plugin` array entry |
| `jcodemunch-mcp` | `config/opencode.jsonc` | `v1.0.0` (git tag) | Update `--from` URL tag |
| `rtk` | `install.sh` | `1.78.0` | Update `rtk_version` variable |

### How to Bump a Pinned Version

1. **Check upstream releases** — Visit the dependency's GitHub releases page and choose the latest stable release. Avoid pre-release or RC versions unless testing a specific fix.
2. **Update the pin** — Edit the relevant file:
   - `@tarquinen/opencode-dcp`: update the version string in the `plugin` array in `config/opencode.jsonc`
   - `jcodemunch-mcp`: update the git tag in the `--from` URL in `config/opencode.jsonc`
   - `rtk`: update the `rtk_version` variable in `install.sh`
3. **Validate the install** — Run `make all` (which runs `install.sh` and `tests/validate.sh`) to verify nothing breaks. Also run `scripts/doctor.sh` to check config health.
4. **Document the change** — Add a note in `CHANGELOG.md` under the appropriate version heading, and update the version table in this ADR if the pinned version changed.

### Why Not Use `@latest`?

- `@latest` resolves at install time, not at commit time
- Breaking changes in dependencies can silently break GeneralPippy
- Users expect a specific, tested version

### Rollback Safety

The installer backs up existing config before overwriting. If a pinned version causes issues, users can:
1. Edit their `~/.config/opencode/opencode.jsonc` directly
2. Change the plugin/MCP version to a working one
3. Re-run `./install.sh` to apply the change

## Consequences

### Positive
- Reproducible installs across machines and time
- Predictable behavior for debugging
- Clear upgrade path via CHANGELOG

### Negative
- Requires manual bumps when new versions are available
- Users may run outdated versions if they don't update

### Risks
- Pinned version may have undiscovered bugs (mitigated by testing before pinning)
- Upstream may remove old tags (mitigated by using stable release tags)

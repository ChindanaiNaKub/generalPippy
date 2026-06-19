---
description: Check for GeneralPippy updates and run the installer after consent
agent: pippy
---

## Pippy Update

Check whether the installed GeneralPippy harness is behind the latest allowed release channel, then ask before running the installer.

Run the installed shared helper:

```bash
node "${XDG_CONFIG_HOME:-$HOME/.config}/opencode/generalpippy/update-check.mjs" --force --interactive
```

If `node` is not available, try `bun` with the same arguments. If neither runtime is available, inspect these files and report `Blocked` with the missing runtime:

- `${XDG_CONFIG_HOME:-$HOME/.config}/opencode/generalpippy/version.json`
- `${XDG_CONFIG_HOME:-$HOME/.config}/opencode/generalpippy/settings.json`
- `${XDG_CONFIG_HOME:-$HOME/.config}/opencode/generalpippy/update-state.json`
- `${XDG_CONFIG_HOME:-$HOME/.config}/opencode/generalpippy/manifest.json`

The helper owns manifest fetching, version comparison, channel selection, OpenCode compatibility checks, cache bypass, reminder state, skip-version state, and installer command construction. Do not duplicate that logic in the command prompt unless the helper cannot run.

Report:
- installed GeneralPippy version
- selected update channel (`stable` by default, `prerelease` only when opted in)
- latest version from the manifest
- OpenCode compatibility status
- whether the update check is disabled by `GENERALPIPPY_UPDATE_CHECK=0` or local settings
- whether the installer was run

Never update silently. Only run the installer after explicit user consent from the helper prompt. If the helper reports that OpenCode must be updated first, do not run the GeneralPippy installer.

**Usage:** `/pippy-update`

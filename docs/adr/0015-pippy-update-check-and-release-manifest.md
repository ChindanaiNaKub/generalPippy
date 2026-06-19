# Pippy update check and release manifest

Status: accepted

GeneralPippy will support a **Pippy update check** as a narrow runtime-plugin exception to the config-only harness rule: a startup-time OpenCode plugin may compare the installed GeneralPippy harness version with the latest released version and ask before any update is applied. This check must be informational, consent-based, and gracefully offline; it must not silently modify prompts, commands, skills, plugins, or user config.

The latest released GeneralPippy version is sourced from a small `manifest.json` in the repository rather than scraping GitHub Releases or inferring from tags. The manifest is easier to fetch, test, cache, and extend with future compatibility metadata, while GitHub release pages and tags remain useful human-facing release artifacts.

The manifest includes compatibility constraints such as `minimum_opencode_version`. The plugin offers compatible GeneralPippy updates, warns when OpenCode must be updated first, and makes compatibility uncertainty explicit when the local OpenCode version cannot be detected.

When the user consents to update, the plugin launches the published installer command instead of patching files itself. install.sh remains the only updater for installed harness files because it owns backups, rollback, plugin merging, model-profile metadata, obsolete cleanup, and optional dependency checks.

The public one-command installer remains interactive by default so beginners can choose a model profile and optional tools deliberately. Because `curl | bash` consumes stdin, required model-profile prompts read from `/dev/tty` when available. If no terminal is available and no saved profile can be reused, the installer stops with instructions to pass explicit flags such as `--yes --profile budget` or `--profile thorough` rather than silently choosing Budget.

Update reminders are rate-limited by local state in `~/.config/opencode/generalpippy/update-state.json`. The plugin may check at startup with a cache TTL, prompt at most once per day for the same newer version, support "remind later", and suppress a version entirely when the user chooses "skip this version".

Updates preserve the user's saved model profile by default. `install.sh` reads `~/.config/opencode/generalpippy/profile.json` during update and reuses it unless the user asks to reconfigure; missing or corrupt profile metadata falls back to the normal interactive profile prompt.

Updates overwrite **GeneralPippy-owned installed files** with the released harness files while backing up the previous copies and warning when local edits may have been replaced. The installer continues to preserve user plugins through merge behavior and preserves saved model-profile metadata, but direct edits to installed Pippy agents, commands, skills, references, or base config are treated as local patches to back up rather than merge.

Users can disable startup update checks with `GENERALPIPPY_UPDATE_CHECK=0` or with local settings in `~/.config/opencode/generalpippy/settings.json`. Disabling checks stops network lookups and prompts, but the installer still writes version metadata and `doctor.sh` may report the disabled state without treating it as a failure.

The update check starts as a local OpenCode plugin file copied by `install.sh`, not a separate npm plugin dependency. Keeping `config/plugins/generalpippy-update-check.js` versioned with the GeneralPippy release ties plugin behavior to the installed harness, preserves backup/rollback behavior, and avoids creating a second release channel before the feature proves it needs one.

The local plugin may perform a startup network check by fetching only `manifest.json` with a short timeout and a local cache TTL. The check must never block OpenCode startup, must respect opt-out settings, must not send telemetry or device identifiers, and must degrade silently when offline or rate-limited.

Update checks use stable release channel by default. Pre-release versions such as beta or release-candidate harnesses are offered only when the user opts into a prerelease channel through local settings, so beginner installs are not nudged into experimental prompts or plugins.

GeneralPippy will also provide a thin `/pippy-update` command for manual update checks. The command bypasses the startup cache, reports installed/latest/compatibility status, asks before running the installer, and gives users a recoverable path after skipped reminders or disabled automatic prompts.

The startup plugin and `/pippy-update` command share one update-check helper so version comparison, channel selection, compatibility checks, cache handling, reminder suppression, and installer command construction do not drift across two implementations.

References: glossary term **Pippy update check** in `CONTEXT.md`, installer metadata in `~/.config/opencode/generalpippy/`, and ADR-0009/ADR-0010 for the harness-plugin exception pattern.

# OpenCode Reference Notes for Pippy

Use this reference when editing GeneralPippy's OpenCode config, agent files,
provider setup, permissions, references, or troubleshooting guidance.

Source docs checked: 2026-06-17

- References: https://opencode.ai/docs/references/
- Config: https://opencode.ai/docs/config/
- Providers: https://opencode.ai/docs/providers/
- Troubleshooting: https://opencode.ai/docs/troubleshooting/

## References

OpenCode project references are configured under `references` in
`opencode.json` or `opencode.jsonc`. A reference alias can point to a local
directory with `path` or a Git repository with `repository`.

Local `path` values can be relative to the config file, absolute, or relative to
the user's home directory. Git `repository` values can be Git URLs, host/path
references, or GitHub `owner/repo` shorthand, with optional `branch`.

Add a short, specific `description` when agents should know the reference
exists. OpenCode includes described references in agent context. References
without descriptions remain available by direct `@alias` use and autocomplete.

Configured references appear in TUI `@` autocomplete. Use `@alias` for the
reference root or `@alias/` to search inside it.

OpenCode automatically allows configured reference directories through its
external-directory permission boundary. Normal tool permissions still apply:
read-only agents do not gain edit access just because a directory is referenced.

## Config

OpenCode supports JSON and JSONC config. The config schema URL is:

```json
"$schema": "https://opencode.ai/config.json"
```

Config sources are merged. Later sources override earlier conflicting keys while
preserving non-conflicting settings. Standard precedence order:

1. Remote config from `.well-known/opencode`
2. Global config in `~/.config/opencode/opencode.json`
3. Custom config from `OPENCODE_CONFIG`
4. Project `opencode.json`
5. `.opencode` directories for agents, commands, plugins, etc.
6. Inline config from `OPENCODE_CONFIG_CONTENT`
7. Managed config files
8. macOS managed preferences

Global config is appropriate for user-wide providers, models, and permissions.
Project config belongs at the project root. A custom config directory can be set
with `OPENCODE_CONFIG_DIR` and uses the same directory names as `.opencode`.

Useful config fields for GeneralPippy:

- `default_agent`: selected default agent.
- `model` and `small_model`: default and system-task models.
- `provider`: custom provider definitions and provider options.
- `plugin`: npm or local plugins.
- `mcp`: MCP server definitions.
- `permission`: default tool permission rules.
- `compaction`: context compaction settings.
- `formatter`: formatter enablement/configuration.
- `lsp`: language-server enablement/configuration.
- `instructions`: extra instruction files/globs.
- `references`: local/Git reference directories.

OpenCode supports plural config directories: `agents/`, `commands/`, `modes/`,
`plugins/`, `skills/`, `tools/`, and `themes/`. Singular names remain supported
for compatibility.

By default, OpenCode allows operations without explicit approval. Use
`permission` to make specific tools ask or deny. GeneralPippy intentionally uses
YOLO permissions for autonomy while keeping the primary edit boundary in the
agent prompts.

## Providers

OpenCode supports many providers through the AI SDK and Models.dev. To add a
provider, connect credentials with `/connect`, then configure provider-specific
settings in the `provider` section if needed.

Credentials added with `/connect` are stored in
`~/.local/share/opencode/auth.json`.

OpenCode Go is a low-cost subscription provider from the OpenCode team. To use
it, run `/connect`, select OpenCode Go, authenticate at `opencode.ai/auth`, paste
the API key, then run `/models` to inspect available models.

Custom OpenAI-compatible providers can be added by selecting `Other` in
`/connect`, entering a provider id, adding an API key, and defining a provider:

```jsonc
{
  "$schema": "https://opencode.ai/config.json",
  "provider": {
    "myprovider": {
      "npm": "@ai-sdk/openai-compatible",
      "name": "My Provider",
      "options": {
        "baseURL": "https://api.myprovider.com/v1"
      },
      "models": {
        "my-model-name": {
          "name": "My Model"
        }
      }
    }
  }
}
```

Provider options can include `baseURL`, `apiKey`, and `headers`. Prefer
environment-variable expansion for secrets instead of hardcoding keys.

## Troubleshooting

Start troubleshooting with logs and local storage.

Log directory:

- macOS/Linux: `~/.local/share/opencode/log/`
- Windows: `%USERPROFILE%\.local\share\opencode\log`

OpenCode keeps recent timestamped log files. Use `opencode --log-level DEBUG`
for more detailed logs.

Storage directory:

- macOS/Linux: `~/.local/share/opencode/`
- Windows: `%USERPROFILE%\.local\share\opencode`

This includes `auth.json`, `log/`, and `project/` session data.

Useful troubleshooting commands:

```bash
opencode debug config
opencode --log-level DEBUG
opencode uninstall
```

For desktop issues, first fully quit and relaunch the app, restart from the
error screen if present, and temporarily disable plugins by removing the
`plugin` key or setting it to an empty array in global config.

Common provider/model fixes:

- Re-run `/connect` when authentication fails.
- Run `/models` to confirm the configured model exists.
- Check provider package/config when seeing provider initialization or AI SDK
  API call errors.

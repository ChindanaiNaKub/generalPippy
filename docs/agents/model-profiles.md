# Model Profiles

GeneralPippy routes work by role. The installer records the selected profile in `~/.config/opencode/generalpippy/profile.json` and renders ordinary OpenCode agent config from that choice.

## Roles

| Role | What It Does |
|------|--------------|
| Coordination | Runs the primary `pippy` loop: understand, plan, delegate, verify, review, and report. |
| Planning | Runs `pippy-plan` for read-only Program design sketches and stuck-step diagnosis. |
| Implementation | Runs `pippy-build` for file edits, tests, refactors, fixes, and other workspace mutation. |
| System tasks | Handles lightweight support work used by the harness. |

## Budget

Budget is the default public profile. Routine coordination and system tasks use a low-cost model, while stronger planning is reserved for read-only design and diagnosis.

| Role | Model |
|------|-------|
| Coordination | `opencode-go/deepseek-v4-flash` |
| Planning | `opencode-go/kimi-k2.7-code` |
| Implementation | `opencode-go/mimo-v2.5` |
| System tasks | `opencode-go/deepseek-v4-flash` |

## Thorough

Thorough keeps Kimi on coordination and planning for users who prefer stronger default reasoning over lower default spend.

| Role | Model |
|------|-------|
| Coordination | `opencode-go/kimi-k2.7-code` |
| Planning | `opencode-go/kimi-k2.7-code` |
| Implementation | `opencode-go/mimo-v2.5` |
| System tasks | `opencode-go/deepseek-v4-flash` |

## Custom

Custom prompts for all four roles during installation:

- Coordination model
- Planning model
- Implementation model
- System-tasks model

Custom model IDs must be non-empty. GeneralPippy passes them through to OpenCode without provider verification; if a model ID is unavailable, OpenCode reports that at runtime.

## Changing Profiles

Run the installer with `--reconfigure` when you want to change the saved model profile:

```bash
curl -fsSL https://raw.githubusercontent.com/ChindanaiNaKub/generalPippy/main/install.sh | bash -s -- --reconfigure
```

For exact usage and cost after a run, use OpenCode's session usage display or `/budget`. Conversation length alone is not a reliable way to infer model usage, token class, cache usage, child-session ownership, or cost.

# ADR-0010: Default cc-safety-net Guardrail Plugin

Status: accepted

GeneralPippy will install `cc-safety-net@1.0.6` as a pinned default OpenCode plugin through its `plugin` array. This deliberately revisits ADR-0009's earlier deferral of runtime guardrail hooks: Pippy's YOLO mode still needs low-friction bash, but known destructive filesystem and git commands should be blocked by a reviewed platform-level guardrail rather than prompt instructions alone.

The plugin runs in its default mode only. Stricter `CC_SAFETY_NET_*` modes are user/project opt-ins because they can block legitimate build, test, install, or worktree workflows. GeneralPippy will not run `opencode plugin -g cc-safety-net`; keeping the dependency in `config/opencode.jsonc` preserves reproducible installs, version pinning, plugin merge behavior, backups, and rollback through `install.sh`.

Consequences: Pippy's safety model becomes "YOLO permissions plus default destructive-command guardrail" instead of workflow-only safety. The trade-off is a new platform-level dependency that can block commands, so version bumps must follow ADR-0003's pinned-dependency process and include validation plus a manual smoke test for a blocked destructive command.

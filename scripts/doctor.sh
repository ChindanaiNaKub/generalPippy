#!/bin/bash
# pippy-doctor — validate installed GeneralPippy config.
# Returns non-zero on problems. Safe to run any time.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

ERRORS=0

error() {
  echo "  ❌ $1"
  ((ERRORS++)) || true
}

ok() {
  echo "  ✅ $1"
}

section() {
  echo ""
  echo "▶ $1"
}

# --- 1. Agent markdown frontmatter ---
section "Agent frontmatter"

for agent in pippy pippy-plan pippy-build; do
  file="$REPO_ROOT/config/agents/$agent.md"
  if [[ ! -f "$file" ]]; then
    error "$agent.md missing"
    continue
  fi
  if head -1 "$file" | grep -q '^---$'; then
    ok "$agent.md has frontmatter"
  else
    error "$agent.md missing frontmatter"
  fi
done

# --- 2. Permission boundaries ---
section "Permission boundaries"

pippy="$REPO_ROOT/config/agents/pippy.md"
pippy_plan="$REPO_ROOT/config/agents/pippy-plan.md"
pippy_build="$REPO_ROOT/config/agents/pippy-build.md"

# Primary pippy: edit deny, bash unrestricted for YOLO mode
if grep -q 'edit: deny' "$pippy" && grep -q '^  bash: allow$' "$pippy"; then
  ok "pippy: edit deny, unrestricted bash for YOLO mode"
else
  error "pippy must deny edit and allow unrestricted bash for YOLO mode"
fi

# pippy: task routing
if grep -q 'pippy-build: allow' "$pippy" && grep -q 'pippy-plan: allow' "$pippy" && grep -q '"\*": deny' "$pippy"; then
  ok "pippy: task routing exposes only pippy-build and pippy-plan"
else
  error "pippy task routing must deny wildcard and allow pippy-build/pippy-plan"
fi

# pippy-plan: edit deny, task deny
if grep -q 'edit: deny' "$pippy_plan" && grep -q 'task: deny' "$pippy_plan"; then
  ok "pippy-plan: read-only, no task delegation"
else
  error "pippy-plan must deny edit and task"
fi

# pippy-build: edit allow, task deny, model correct
if grep -q 'edit: allow' "$pippy_build" && grep -q 'task: deny' "$pippy_build" && grep -q 'opencode-go/mimo-v2.5' "$pippy_build"; then
  ok "pippy-build: implementation agent on mimo-v2.5"
else
  error "pippy-build must allow edit, deny task, use mimo-v2.5"
fi

# pippy-build: bash must be unrestricted for YOLO mode
if grep -q '^  bash: allow$' "$pippy_build"; then
  ok "pippy-build: unrestricted bash for YOLO mode"
else
  error "pippy-build must allow unrestricted bash for YOLO mode"
fi

# pippy-build: YOLO language present
if grep -q "YOLO Bash" "$pippy_build" && grep -q "without approval prompts" "$pippy_build"; then
  ok "pippy-build: YOLO bash documentation present"
else
  error "pippy-build must document YOLO bash model"
fi

# --- 3. Stale v1.0 references ---
section "Stale v1.0 references"

# Exclude docs/adr (legitimate history) and CHANGELOG.md (release history)
matches="$(grep -RniE 'orchestrator|/think|/cheap|/smart' "$REPO_ROOT/config" "$REPO_ROOT/README.md" "$REPO_ROOT/AGENTS.md" 2>/dev/null || true)"
if [[ -z "$matches" ]]; then
  ok "no stale v1.0 references in active config/docs"
else
  error "found stale v1.0 references: $matches"
fi

# --- 4. Pinned dependencies ---
section "Pinned dependencies"

config="$REPO_ROOT/config/opencode.jsonc"
installer="$REPO_ROOT/install.sh"

if grep -q '@latest' "$config"; then
  error "opencode.jsonc contains @latest reference"
else
  ok "no @latest references in opencode.jsonc"
fi

if grep -q 'jcodemunch-mcp.git@v1.0.0' "$config"; then
  ok "jcodemunch MCP is pinned to v1.0.0"
else
  error "jcodemunch MCP must be pinned to working tag v1.0.0"
fi

if grep -q '"command": \["uvx", "--from", "git+https://github.com/jgravelle/jcodemunch-mcp.git@v1.0.0", "jcodemunch-mcp"\]' "$config"; then
  ok "jcodemunch MCP command starts with uvx"
else
  error "jcodemunch MCP command must start with uvx"
fi

if grep -q 'rtk_version=' "$installer" && grep -q 'refs/tags/v' "$installer"; then
  ok "rtk install is pinned"
else
  error "rtk install must be pinned to a release tag"
fi

# --- 4b. OpenCode default tools ---
section "OpenCode default tools"

if grep -q '"formatter"[[:space:]]*:[[:space:]]*true' "$config"; then
  ok "formatter is enabled by default"
else
  error "opencode.jsonc must enable formatter by default"
fi

if grep -q '"lsp"[[:space:]]*:[[:space:]]*true' "$config"; then
  ok "LSP is enabled by default"
else
  error "opencode.jsonc must enable LSP by default"
fi

# --- 5. Stale /verify command references ---
section "No stale /verify command"

# Look for standalone /verify command references (not inline "verify" as a verb)
if grep -rE '/verify' "$REPO_ROOT/config/commands/" 2>/dev/null | grep -v 'verify, and prepare' | grep -v 'verification' | grep -v 'verify each' | grep -v 'verified' | grep -v 'verify.' > /dev/null 2>&1; then
  error "found stale /verify command reference in config/commands/"
else
  ok "no stale /verify command in config/commands/"
fi

# --- 6. Budget command guidance ---
section "Budget command guidance"

budget="$REPO_ROOT/config/commands/budget.md"
if [[ ! -f "$budget" ]]; then
  error "config/commands/budget.md missing"
else
  # ponytail constraint vs ponytail plugin
  if grep -q "ponytail constraint" "$budget" && grep -q "ponytail plugin" "$budget"; then
    ok "budget distinguishes ponytail constraint from ponytail plugin"
  else
    error "budget must distinguish ponytail constraint from ponytail plugin"
  fi

  # optional-tool statuses
  if grep -q "not applicable" "$budget" && grep -q "not visibly exercised" "$budget" && grep -q "missed opportunity" "$budget"; then
    ok "budget defines optional-tool statuses (not applicable, not visibly exercised, missed opportunity)"
  else
    error "budget must define optional-tool statuses: not applicable, not visibly exercised, missed opportunity"
  fi

  # explicit compression recommendation
  if grep -qi "compression recommendation" "$budget"; then
    ok "budget includes explicit compression recommendation"
  else
    error "budget must include an explicit compression recommendation"
  fi

  # Caveman mode vs Caveman CLI
  if grep -q "Caveman mode" "$budget" && grep -q "Caveman CLI" "$budget"; then
    ok "budget distinguishes Caveman mode from Caveman CLI"
  else
    error "budget must distinguish Caveman mode from Caveman CLI"
  fi
fi

# --- 7. Model profiles ---
section "Model profiles"

profile_json="$REPO_ROOT/config/model-profiles/balanced.json"
if [[ ! -f "$profile_json" ]]; then
  error "config/model-profiles/balanced.json missing"
else
  ok "model-profiles/balanced.json exists"

  # Verify expected models using python3 or grep.
  if grep -q '"opencode-go/kimi-k2.7-code"' "$profile_json" && \
     grep -q '"opencode-go/mimo-v2.5"' "$profile_json" && \
     grep -q '"opencode-go/deepseek-v4-flash"' "$profile_json"; then
    ok "balanced.json contains expected model defaults"
  else
    error "balanced.json must contain kimi-k2.7-code, mimo-v2.5, deepseek-v4-flash"
  fi
fi

# --- 8. Advice command ---
section "Advice command"

advice="$REPO_ROOT/config/commands/advice.md"
if [[ ! -f "$advice" ]]; then
  error "config/commands/advice.md missing"
else
  ok "config/commands/advice.md exists"

  if head -1 "$advice" | grep -q '^---$'; then
    ok "advice.md has frontmatter"
  else
    error "advice.md missing frontmatter"
  fi
fi

# --- 9. Decision records ---
section "Decision records"

adr7="$REPO_ROOT/docs/adr/0007-dynamic-model-routing-decision.md"
adr8="$REPO_ROOT/docs/adr/0008-improve-pippy-command-decision.md"

for adr in "$adr7" "$adr8"; do
  label="$(basename "$adr")"
  if [[ ! -f "$adr" ]]; then
    error "$label missing"
    continue
  fi
  ok "$label exists"

  # Check required sections (Status may be "## Status" heading or "Status: accepted" field)
  for section_name in Context Decision Consequences References; do
    if grep -qi "^## $section_name" "$adr"; then
      ok "$label has $section_name"
    else
      error "$label missing $section_name section"
    fi
  done

  # Status can be either a heading or a field
  if grep -qi "^## Status" "$adr" || grep -qi "^Status:" "$adr"; then
    ok "$label has Status"
  else
    error "$label missing Status section"
  fi
done

# --- Summary ---
echo ""
if [[ $ERRORS -eq 0 ]]; then
  echo "✅ All checks passed."
  exit 0
else
  echo "❌ $ERRORS problem(s) found."
  exit 1
fi

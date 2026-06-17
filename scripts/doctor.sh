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

# Primary pippy: edit deny, bash granular (no unrestricted bash: allow)
if grep -q 'edit: deny' "$pippy" && ! grep -q '^  bash: allow$' "$pippy"; then
  ok "pippy: edit deny, no unrestricted bash"
else
  error "pippy must deny edit and avoid unrestricted bash: allow"
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

# pippy-build: bash must be granular (no unrestricted bash: allow)
if grep -q '^  bash: allow$' "$pippy_build"; then
  error "pippy-build must not have unrestricted bash: allow (use gated-action model)"
else
  ok "pippy-build: bash uses granular permissions"
fi

# pippy-build: gated-action language present
if grep -q "Gated Actions" "$pippy_build" && grep -q "Destructive actions" "$pippy_build"; then
  ok "pippy-build: gated-action documentation present"
else
  error "pippy-build must document gated-action model (Destructive actions)"
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

if grep -q 'jcodemunch-mcp.git@' "$config"; then
  ok "jcodemunch MCP is pinned"
else
  error "jcodemunch MCP must be pinned (git@vX.Y.Z)"
fi

if grep -q 'rtk_version=' "$installer" && grep -q 'refs/tags/v' "$installer"; then
  ok "rtk install is pinned"
else
  error "rtk install must be pinned to a release tag"
fi

# --- 5. Stale /verify command references ---
section "No stale /verify command"

# Look for standalone /verify command references (not inline "verify" as a verb)
if grep -rE '/verify' "$REPO_ROOT/config/commands/" 2>/dev/null | grep -v 'verify, and prepare' | grep -v 'verification' | grep -v 'verify each' | grep -v 'verified' | grep -v 'verify.' > /dev/null 2>&1; then
  error "found stale /verify command reference in config/commands/"
else
  ok "no stale /verify command in config/commands/"
fi

# --- Summary ---
echo ""
if [[ $ERRORS -eq 0 ]]; then
  echo "✅ All checks passed."
  exit 0
else
  echo "❌ $ERRORS problem(s) found."
  exit 1
fi

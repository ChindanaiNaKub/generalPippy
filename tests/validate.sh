#!/bin/bash
# Validate GeneralPippy configuration and packaging.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

PASSED=0
FAILED=0

pass() {
  echo "  ✅ $1"
  ((PASSED++)) || true
}

fail() {
  echo "  ❌ $1"
  ((FAILED++)) || true
}

run_test() {
  echo ""
  echo "▶ $1"
}

test_required_files_exist() {
  run_test "all files referenced by install.sh exist"
  local file
  for file in config/opencode.jsonc \
              config/agents/pippy.md config/agents/pippy-plan.md config/agents/pippy-build.md \
              config/commands/goal.md config/commands/ship.md config/commands/budget.md \
              config/skills/pippy/SKILL.md config/skills/verify/SKILL.md; do
    if [[ -f "$REPO_ROOT/$file" ]]; then
      pass "exists: $file"
    else
      fail "missing: $file"
    fi
  done
}

test_opencode_jsonc_valid() {
  run_test "opencode.jsonc is valid JSONC"
  if python3 - "$REPO_ROOT/config/opencode.jsonc" <<'PY'
import json, re, sys
path = sys.argv[1]
with open(path) as f:
    text = f.read()
# Strip // comments and /* */ comments.
# Be careful not to strip URLs like https://example.com.
text = re.sub(r'(?<!\S)//[^\n]*', '', text)
text = re.sub(r'/\*.*?\*/', '', text, flags=re.DOTALL)
try:
    json.loads(text)
    sys.exit(0)
except Exception as e:
    print(e, file=sys.stderr)
    sys.exit(1)
PY
  then
    pass "valid JSONC"
  else
    fail "invalid JSONC"
  fi
}

test_no_stale_v1_references() {
  run_test "no stale v1.0 references in active config/docs"
  # ADRs legitimately discuss v1.0 history, so exclude docs/adr.
  local matches=""
  matches="$(grep -RniE 'orchestrator|/think|/cheap|/smart' "$REPO_ROOT/config" "$REPO_ROOT/README.md" "$REPO_ROOT/AGENTS.md" 2>/dev/null || true)"
  if [[ -z "$matches" ]]; then
    pass "no stale v1.0 references"
  else
    fail "found stale references:\n$matches"
  fi
}

test_markdown_frontmatter() {
  run_test "agent/command/skill markdown files have frontmatter"
  local file
  for file in "$REPO_ROOT"/config/agents/*.md "$REPO_ROOT"/config/commands/*.md "$REPO_ROOT"/config/skills/*/*.md; do
    if [[ -f "$file" ]]; then
      if head -1 "$file" | grep -q '^---$'; then
        pass "frontmatter: $(basename "$file")"
      else
        fail "missing frontmatter: $(basename "$file")"
      fi
    fi
  done
}

test_budget_command_is_guidance_only() {
  run_test "/budget avoids fake cost estimates"
  local file="$REPO_ROOT/config/commands/budget.md"

  if grep -qi "authoritative source" "$file" && grep -qi "Do \\*\\*not\\*\\* estimate" "$file"; then
    pass "budget command states authoritative source and no-estimate rule"
  else
    fail "budget command must state authoritative source and no-estimate rule"
  fi

  if grep -qE '\\$[0-9]+(\\.[0-9]+)?\\s*/\\s*\\$[0-9]+(\\.[0-9]+)?' "$file"; then
    fail "budget command contains static pricing table"
  else
    pass "budget command has no static pricing table"
  fi
}

test_subagent_routing_config() {
  run_test "pippy routing boundary is explicit"
  local pippy="$REPO_ROOT/config/agents/pippy.md"
  local pippy_plan="$REPO_ROOT/config/agents/pippy-plan.md"
  local pippy_build="$REPO_ROOT/config/agents/pippy-build.md"
  local opencode="$REPO_ROOT/config/opencode.jsonc"
  local smoke="$REPO_ROOT/docs/agents/subagent-routing-smoke-test.md"
  local manual_smoke="$REPO_ROOT/docs/agents/manual-smoke-tests.md"

  if grep -q "pippy-build: allow" "$pippy" && grep -q "pippy-plan: allow" "$pippy" && grep -q '"\*": deny' "$pippy"; then
    pass "pippy task permission only exposes intended subagents"
  else
    fail "pippy task permission must deny wildcard and allow pippy-plan/pippy-build"
  fi

  if grep -q "edit: deny" "$pippy" &&
     grep -q "bash:" "$pippy" &&
     grep -q '"\*": ask' "$pippy" &&
     ! grep -q "bash: allow" "$pippy"; then
    pass "primary pippy cannot auto-edit and uses granular bash permissions"
  else
    fail "primary pippy must deny edit and use granular bash instead of bash: allow"
  fi

  if grep -q "Do not implement code in the primary agent" "$pippy" &&
     grep -q "If \`pippy-build\` is unavailable, stop and report \`Blocked\`" "$pippy"; then
    pass "pippy prompt forbids primary implementation fallback"
  else
    fail "pippy prompt must forbid primary implementation fallback"
  fi

  if grep -q "edit: deny" "$pippy_plan" && grep -q '"\*": ask' "$pippy_plan" && grep -q 'git diff\*": allow' "$pippy_plan"; then
    pass "pippy-plan remains read-only with granular bash access"
  else
    fail "pippy-plan must remain read-only with granular bash access"
  fi

  if grep -q 'model: opencode-go/mimo-v2.5' "$pippy_build" &&
     grep -q 'edit: allow' "$pippy_build" &&
     grep -q 'task: deny' "$pippy_build"; then
    pass "pippy-build remains the implementation subagent on opencode-go/mimo-v2.5"
  else
    fail "pippy-build must remain the implementation subagent on opencode-go/mimo-v2.5 and not delegate further"
  fi

  if grep -q 'task: deny' "$pippy_plan"; then
    pass "pippy-plan cannot spawn implementation work directly"
  else
    fail "pippy-plan must not spawn implementation work directly"
  fi

  if grep -q '"agent"' "$opencode"; then
    fail "opencode.jsonc must not redeclare markdown agents with partial JSON stubs"
  else
    pass "opencode.jsonc leaves agent definitions to markdown files"
  fi

  if grep -q "Primary Pippy must not have auto edit permissions" "$smoke" &&
     grep -q "Primary bash should be granular rather than unrestricted" "$smoke" &&
     grep -q "\`pippy-plan\` remains read-only" "$smoke" &&
     grep -q "opencode-go/mimo-v2.5" "$smoke" &&
     grep -q "\`pippy-build\` remains the implementation subagent" "$smoke"; then
    pass "subagent routing smoke test documents the stricter boundary"
  else
    fail "subagent routing smoke test must document the stricter boundary"
  fi

  if [[ -f "$manual_smoke" ]] &&
     grep -q "opencode debug config" "$manual_smoke" &&
     grep -q "pippy.permission.edit" "$manual_smoke" &&
     grep -q "pippy-build.model" "$manual_smoke" &&
     grep -q '/goal "make a harmless one-line documentation wording improvement' "$manual_smoke" &&
     grep -q "/budget" "$manual_smoke"; then
    pass "manual smoke test covers config, routing, and budget checks"
  else
    fail "manual smoke test must cover config, routing, and budget checks"
  fi
}

test_caveman_mode_not_cli_only() {
  run_test "caveman mode is not treated as CLI-only"
  local pippy="$REPO_ROOT/config/agents/pippy.md"
  local budget="$REPO_ROOT/config/commands/budget.md"
  local context="$REPO_ROOT/CONTEXT.md"
  local smoke="$REPO_ROOT/docs/agents/caveman-mode-smoke-test.md"

  if grep -q "Caveman mode: OpenCode command/config mode" "$pippy" &&
     grep -q "Do not ask the user to run" "$pippy"; then
    pass "pippy owns Caveman mode activation"
  else
    fail "pippy must detect and apply OpenCode Caveman mode automatically"
  fi

  if grep -q "Do not report Caveman mode as missing merely because" "$budget"; then
    pass "budget distinguishes Caveman mode from CLI"
  else
    fail "budget must not equate Caveman mode with command -v caveman"
  fi

  if grep -q "Caveman mode" "$context" && grep -q "Caveman CLI" "$context"; then
    pass "domain glossary distinguishes Caveman mode and Caveman CLI"
  else
    fail "CONTEXT.md must distinguish Caveman mode and Caveman CLI"
  fi

  if [[ -f "$smoke" ]] &&
     grep -q "command -v caveman" "$smoke" &&
     grep -q "must not treat that as Caveman mode missing" "$smoke"; then
    pass "caveman smoke test covers OpenCode mode vs CLI"
  else
    fail "caveman smoke test must cover OpenCode mode vs CLI"
  fi
}

main() {
  echo "Running GeneralPippy validation tests..."

  test_required_files_exist
  test_opencode_jsonc_valid
  test_no_stale_v1_references
  test_markdown_frontmatter
  test_budget_command_is_guidance_only
  test_subagent_routing_config
  test_caveman_mode_not_cli_only

  echo ""
  echo "========================="
  echo "Passed: $PASSED"
  echo "Failed: $FAILED"
  echo "========================="

  [[ $FAILED -eq 0 ]]
}

main "$@"

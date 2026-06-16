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

main() {
  echo "Running GeneralPippy validation tests..."

  test_required_files_exist
  test_opencode_jsonc_valid
  test_no_stale_v1_references
  test_markdown_frontmatter
  test_budget_command_is_guidance_only

  echo ""
  echo "========================="
  echo "Passed: $PASSED"
  echo "Failed: $FAILED"
  echo "========================="

  [[ $FAILED -eq 0 ]]
}

main "$@"

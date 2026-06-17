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
              config/skills/pippy/SKILL.md \
              config/references/opencode/REFERENCE.md; do
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
     grep -q "^  bash: allow$" "$pippy"; then
    pass "primary pippy cannot auto-edit and uses unrestricted YOLO bash"
  else
    fail "primary pippy must deny edit and allow unrestricted YOLO bash"
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
     grep -q "Primary bash is unrestricted for YOLO mode" "$smoke" &&
     grep -q "without approval prompts" "$smoke" &&
     grep -q "\`pippy-plan\` remains read-only" "$smoke" &&
     grep -q "opencode-go/mimo-v2.5" "$smoke" &&
     grep -q "\`pippy-build\` remains the implementation subagent" "$smoke"; then
    pass "subagent routing smoke test documents YOLO bash plus routing boundary"
  else
    fail "subagent routing smoke test must document YOLO bash plus routing boundary"
  fi

  if [[ -f "$manual_smoke" ]] &&
     grep -q "opencode debug config" "$manual_smoke" &&
     grep -q "pippy.permission.edit" "$manual_smoke" &&
     grep -q "pippy.permission.bash" "$manual_smoke" &&
     grep -q "pippy-build.model" "$manual_smoke" &&
     grep -q '/goal "make a harmless one-line documentation wording improvement' "$manual_smoke" &&
     grep -q "/budget" "$manual_smoke"; then
    pass "manual smoke test covers config, routing, and budget checks"
  else
    fail "manual smoke test must cover config, routing, and budget checks"
  fi
}

test_opencode_reference_pack() {
  run_test "OpenCode reference pack is configured and packaged"
  local opencode="$REPO_ROOT/config/opencode.jsonc"
  local ref="$REPO_ROOT/config/references/opencode/REFERENCE.md"
  local installer="$REPO_ROOT/install.sh"
  local pippy="$REPO_ROOT/config/agents/pippy.md"
  local build="$REPO_ROOT/config/agents/pippy-build.md"

  if grep -q '"references"' "$opencode" &&
     grep -q '"opencode-docs"' "$opencode" &&
     grep -q './references/opencode' "$opencode"; then
    pass "opencode.jsonc registers opencode-docs reference"
  else
    fail "opencode.jsonc must register the opencode-docs reference"
  fi

  if [[ -f "$ref" ]] &&
     grep -q "https://opencode.ai/docs/references/" "$ref" &&
     grep -q "https://opencode.ai/docs/config/" "$ref" &&
     grep -q "https://opencode.ai/docs/providers/" "$ref" &&
     grep -q "https://opencode.ai/docs/troubleshooting/" "$ref"; then
    pass "reference pack contains linked OpenCode source docs"
  else
    fail "reference pack must include references/config/providers/troubleshooting source links"
  fi

  if grep -q 'config/references/opencode/REFERENCE.md' "$installer" &&
     grep -q 'references/opencode/REFERENCE.md' "$installer"; then
    pass "installer copies OpenCode reference pack"
  else
    fail "installer must copy OpenCode reference pack"
  fi

  if grep -q "@opencode-docs" "$pippy" && grep -q "@opencode-docs" "$build"; then
    pass "pippy agents know when to use @opencode-docs"
  else
    fail "pippy and pippy-build must mention @opencode-docs for OpenCode config work"
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

test_external_deps_are_pinned() {
  run_test "external dependencies are pinned (no @latest or unpinned refs)"
  local config="$REPO_ROOT/config/opencode.jsonc"
  local installer="$REPO_ROOT/install.sh"

  # opencode-dcp must be pinned (not @latest).
  if grep -q '@latest' "$config"; then
    fail "opencode.jsonc contains @latest reference"
  else
    pass "no @latest references in opencode.jsonc"
  fi

  # jcodemunch must have a tag or commit in the URL.
  if grep -q 'jcodemunch-mcp.git@' "$config"; then
    pass "jcodemunch MCP is pinned to a tag/commit"
  else
    fail "jcodemunch MCP source must be pinned (git@vX.Y.Z)"
  fi

  # rtk must be pinned to a specific version in install.sh.
  if grep -q 'rtk_version=' "$installer" && grep -q 'refs/tags/v' "$installer"; then
    pass "rtk install is pinned to a release tag"
  else
    fail "rtk install must be pinned to a specific release tag"
  fi
}

test_pippy_build_bash_permissions() {
  run_test "pippy-build uses unrestricted YOLO bash permissions"
  local file="$REPO_ROOT/config/agents/pippy-build.md"

  if grep -q '^  bash: allow$' "$file"; then
    pass "pippy-build has unrestricted bash: allow"
  else
    fail "pippy-build must have unrestricted bash: allow"
  fi

  if grep -q "YOLO Bash" "$file" && grep -q "without approval prompts" "$file"; then
    pass "pippy-build documents YOLO bash model"
  else
    fail "pippy-build must document YOLO bash model"
  fi

  # Must retain edit: allow
  if grep -q 'edit: allow' "$file"; then
    pass "pippy-build retains edit: allow"
  else
    fail "pippy-build must retain edit: allow"
  fi

  # Must document primary agent edit boundary
  if grep -q "Primary Agent Boundary" "$file" && grep -q "must NOT make edits" "$file"; then
    pass "pippy-build documents primary agent edit boundary"
  else
    fail "pippy-build must document that primary agent must NOT make edits"
  fi
}

test_goal_output_format() {
  run_test "/goal output includes acceptance criteria, plan, improvement signal, and outcome format"
  local goal="$REPO_ROOT/config/commands/goal.md"
  local pippy="$REPO_ROOT/config/agents/pippy.md"
  local skill="$REPO_ROOT/config/skills/pippy/SKILL.md"

  # goal.md must have the four output elements
  if grep -q "Acceptance Criteria" "$goal" && grep -q "Plan" "$goal" && grep -q "Improvement Signal" "$goal" && grep -q "Outcome" "$goal"; then
    pass "goal.md includes acceptance criteria, plan, improvement signal, and outcome"
  else
    fail "goal.md must include acceptance criteria, plan, improvement signal, and outcome"
  fi

  # pippy.md must have the four REPORT elements
  if grep -q "Acceptance Criteria" "$pippy" && grep -q "Plan" "$pippy" && grep -q "Improvement Signal" "$pippy" && grep -q "Outcome" "$pippy"; then
    pass "pippy.md REPORT includes acceptance criteria, plan, improvement signal, and outcome"
  else
    fail "pippy.md REPORT must include acceptance criteria, plan, improvement signal, and outcome"
  fi

  # SKILL.md must have the four output elements
  if grep -q "Acceptance Criteria" "$skill" && grep -q "Plan" "$skill" && grep -q "Improvement Signal" "$skill" && grep -q "Outcome" "$skill"; then
    pass "SKILL.md includes acceptance criteria, plan, improvement signal, and outcome"
  else
    fail "SKILL.md must include acceptance criteria, plan, improvement signal, and outcome"
  fi
}

test_verify_is_part_of_goal() {
  run_test "verification is described as final step of /goal, not standalone"
  local goal="$REPO_ROOT/config/commands/goal.md"
  local skill="$REPO_ROOT/config/skills/pippy/SKILL.md"

  # goal.md must say verification is the final step
  if grep -q "Verification.*FINAL step.*goal" "$goal" || grep -q "FINAL step.*goal" "$goal"; then
    pass "goal.md describes verification as final step of /goal"
  else
    fail "goal.md must describe verification as final step of /goal"
  fi

  # SKILL.md must say verification is the final step
  if grep -q "FINAL step.*goal" "$skill"; then
    pass "SKILL.md describes verification as final step of /goal"
  else
    fail "SKILL.md must describe verification as final step of /goal"
  fi

  # No standalone /verify command in config/commands/
  local verify_files
  verify_files="$(find "$REPO_ROOT/config/commands" -name 'verify*' 2>/dev/null || true)"
  if [[ -z "$verify_files" ]]; then
    pass "no standalone verify command file in config/commands/"
  else
    fail "found stale verify command file(s): $verify_files"
  fi

  # Check for stale /verify references (not inline "verify" as a verb)
  local stale_refs
  stale_refs="$(grep -rn '/verify' "$REPO_ROOT/config/commands/" 2>/dev/null | grep -v 'verify, and prepare' | grep -v 'verification' | grep -v 'verify each' | grep -v 'verified' | grep -v 'verify.' || true)"
  if [[ -z "$stale_refs" ]]; then
    pass "no stale /verify command references"
  else
    fail "found stale /verify references: $stale_refs"
  fi
}

test_ship_guidance() {
  run_test "/ship includes rtk routing, caveman reports, compress, and release confirmation"
  local file="$REPO_ROOT/config/commands/ship.md"

  # #18: rtk force routing
  if grep -q "RTK Force" "$file" &&
     grep -q "MUST route every shell command through \`rtk\`" "$file" &&
     grep -q "rtk gh" "$file" &&
     grep -q "rtk make all" "$file"; then
    pass "/ship forces shell/git/gh/make operations through rtk"
  else
    fail "/ship must force shell/git/gh/make operations through rtk when installed"
  fi

  # #17: caveman-full style
  if grep -q "caveman-full" "$file"; then
    pass "/ship has caveman-full style guidance"
  else
    fail "/ship must include caveman-full style reporting"
  fi

  # #19: early compress
  if grep -q "compress" "$file" && grep -q "context" "$file"; then
    pass "/ship has early context compression guidance"
  else
    fail "/ship must instruct early context compression"
  fi

  # #20: release confirmation
  if grep -q "gh release create" "$file" && grep -q "exit status" "$file"; then
    pass "/ship trusts gh release exit status"
  else
    fail "/ship must trust gh release exit status instead of re-fetching"
  fi
}

test_doctor_script() {
  run_test "scripts/doctor.sh exists and runs"
  local script="$REPO_ROOT/scripts/doctor.sh"

  if [[ -f "$script" ]]; then
    pass "doctor.sh exists"
  else
    fail "doctor.sh missing"
    return
  fi

  if [[ -x "$script" ]]; then
    pass "doctor.sh is executable"
  else
    fail "doctor.sh is not executable"
  fi

  # Run doctor.sh — it should pass on the current repo
  local output
  if output="$(bash "$script" 2>&1)"; then
    pass "doctor.sh exits 0 on current repo"
  else
    fail "doctor.sh exited non-zero on current repo:\n$output"
  fi
}

test_acceptance_criteria_are_verifiable() {
  run_test "#12 acceptance criteria must be observable/testable"
  local goal="$REPO_ROOT/config/commands/goal.md"
  local pippy="$REPO_ROOT/config/agents/pippy.md"

  # goal.md must mention observable/testable criteria and ban vague ones
  if grep -q "observable and testable" "$goal" && grep -qi "vague.*banned\|banned.*vague\|make it better" "$goal"; then
    pass "goal.md states criteria must be observable/testable and bans vague criteria"
  else
    fail "goal.md must state criteria must be observable/testable and ban vague criteria"
  fi

  # pippy.md must mention observable/testable and ban vague
  if grep -q "observable and testable" "$pippy" && grep -qi "vague\|make it better" "$pippy"; then
    pass "pippy.md states criteria must be observable/testable and bans vague criteria"
  else
    fail "pippy.md must state criteria must be observable/testable and ban vague criteria"
  fi
}

test_plan_steps_ordered_scoped() {
  run_test "#13 plan steps must be ordered and scoped"
  local goal="$REPO_ROOT/config/commands/goal.md"
  local pippy="$REPO_ROOT/config/agents/pippy.md"

  # goal.md must mention ordered steps and single deliverable
  if grep -qi "execution order\|in execution order" "$goal" && grep -qi "single.*deliverable\|independently verifiable" "$goal"; then
    pass "goal.md requires ordered steps with single verifiable deliverable"
  else
    fail "goal.md must require ordered steps with single verifiable deliverable"
  fi

  # pippy.md must mention execution order and independently verifiable
  if grep -qi "execution order" "$pippy" && grep -qi "independently verifiable\|single.*deliverable" "$pippy"; then
    pass "pippy.md requires ordered steps with single verifiable deliverable"
  else
    fail "pippy.md must require ordered steps with single verifiable deliverable"
  fi
}

test_outcome_must_be_done_blocked_partial() {
  run_test "#14 outcome must be exactly Done/Blocked/Partial"
  local pippy="$REPO_ROOT/config/agents/pippy.md"
  local skill="$REPO_ROOT/config/skills/pippy/SKILL.md"

  # pippy.md must say the final line must be exactly Done, Blocked, or Partial
  # shellcheck disable=SC2016
  if grep -q "exactly one of" "$pippy" && grep -q '`Done`' "$pippy" && grep -q '`Blocked`' "$pippy" && grep -q '`Partial`' "$pippy"; then
    pass "pippy.md requires exact Done/Blocked/Partial outcome"
  else
    fail "pippy.md must require the final outcome line to be exactly Done, Blocked, or Partial"
  fi

  # pippy.md must say no other labels permitted
  if grep -q "No other outcome labels" "$pippy"; then
    pass "pippy.md explicitly bans other outcome labels"
  else
    fail "pippy.md must explicitly ban other outcome labels"
  fi

  # skill.md must say exactly one of Done/Blocked/Partial
  # shellcheck disable=SC2016
  if grep -q "exactly one of" "$skill" && grep -q '`Done`' "$skill" && grep -q '`Blocked`' "$skill" && grep -q '`Partial`' "$skill"; then
    pass "SKILL.md requires exact Done/Blocked/Partial outcome"
  else
    fail "SKILL.md must require the final outcome line to be exactly Done, Blocked, or Partial"
  fi
}

test_final_verification_gate_required() {
  run_test "#15 plan must always end with final verification gate"
  local goal="$REPO_ROOT/config/commands/goal.md"
  local pippy="$REPO_ROOT/config/agents/pippy.md"
  local skill="$REPO_ROOT/config/skills/pippy/SKILL.md"

  # goal.md must say verification is FINAL and plan must end with it
  if grep -q "FINAL step" "$goal" && grep -qi "plan.*must always end\|always end.*verification\|must always end with this verification" "$goal"; then
    pass "goal.md requires plan to end with final verification gate"
  else
    fail "goal.md must require plan to always end with final verification gate"
  fi

  # pippy.md must say plan must always end with verification
  if grep -qi "plan must always end\|always end with this verification\|no step can skip it" "$pippy"; then
    pass "pippy.md requires plan to end with final verification gate"
  else
    fail "pippy.md must require plan to always end with final verification gate"
  fi

  # skill.md must say plan must always end with verification gate
  if grep -qi "plan must always end" "$skill"; then
    pass "SKILL.md requires plan to end with final verification gate"
  else
    fail "SKILL.md must require plan to always end with final verification gate"
  fi
}

test_ship_budget_efficiency_smoke_test() {
  run_test "#21 /ship budget-efficiency smoke test exists"
  local file="$REPO_ROOT/docs/agents/manual-smoke-tests.md"

  if [[ ! -f "$file" ]]; then
    fail "manual-smoke-tests.md does not exist"
    return
  fi

  # Check for the four required /ship checks
  if grep -q "RTK Force\|rtk git status\|rtk gh\|rtk make all" "$file"; then
    pass "/ship smoke test checks RTK Force for git/gh/make"
  else
    fail "/ship smoke test must check RTK Force for git/gh/make"
  fi

  if grep -qi "compress.*context\|context.*compress\|compression before" "$file"; then
    pass "/ship smoke test checks context compression before final gate"
  else
    fail "/ship smoke test must check context compression before final gate"
  fi

  if grep -qi "caveman-full" "$file"; then
    pass "/ship smoke test checks caveman-full reporting"
  else
    fail "/ship smoke test must check caveman-full reporting"
  fi

  if grep -qi "re-fetch\|re-fetches\|no re-fetch\|does not re-fetch" "$file"; then
    pass "/ship smoke test checks no re-fetch of releases"
  else
    fail "/ship smoke test must check no re-fetch of releases"
  fi
}

test_adr_bump_process() {
  run_test "#29 ADR documents bump process for pinned deps"
  local adr="$REPO_ROOT/docs/adr/0003-pin-external-dependencies.md"

  if [[ ! -f "$adr" ]]; then
    fail "ADR-0003 does not exist"
    return
  fi

  # Must have a bump process or updating section
  if grep -qi "bump process\|how to bump\|updating" "$adr"; then
    pass "ADR contains bump process / updating section"
  else
    fail "ADR must contain a Bump Process or Updating section"
  fi

  # Must mention choosing a new version
  if grep -qi "check upstream\|choose.*version\|latest stable" "$adr"; then
    pass "ADR describes how to choose a new version"
  else
    fail "ADR must describe how to choose a new version"
  fi

  # Must mention where to update (opencode.jsonc, install.sh)
  if grep -qi "opencode.jsonc\|install.sh" "$adr"; then
    pass "ADR specifies where to update pins"
  else
    fail "ADR must specify where to update pins (opencode.jsonc, install.sh)"
  fi

  # Must mention validation (make all, doctor.sh)
  if grep -qi "make all\|doctor\|validate" "$adr"; then
    pass "ADR describes validation steps"
  else
    fail "ADR must describe validation steps (make all, doctor.sh)"
  fi

  # Must mention documenting the change (CHANGELOG)
  if grep -qi "changelog\|CHANGELOG" "$adr"; then
    pass "ADR mentions documenting change in CHANGELOG"
  else
    fail "ADR must mention documenting the change in CHANGELOG"
  fi
}

test_context_assembly() {
  run_test "#41 context assembly is documented in pippy.md and SKILL.md"
  local pippy="$REPO_ROOT/config/agents/pippy.md"
  local skill="$REPO_ROOT/config/skills/pippy/SKILL.md"

  for file in "$pippy" "$skill"; do
    local label
    label="$(basename "$file")"

    if grep -q "Context Assembly" "$file"; then
      pass "$label contains 'Context Assembly'"
    else
      fail "$label must contain 'Context Assembly'"
    fi

    if grep -q "fresh bundle\|Fresh" "$file" && grep -q "forked bundle\|Forked" "$file"; then
      pass "$label describes fresh and forked bundles"
    else
      fail "$label must describe fresh and forked bundles"
    fi

    # First attempt bundle contents
    if grep -qi "first.*attempt\|First implementation attempt" "$file" && grep -q "acceptance criteria" "$file" && grep -q "file paths\|file path" "$file"; then
      pass "$label first-attempt bundle includes acceptance criteria and file paths"
    else
      fail "$label first-attempt bundle must include acceptance criteria and file paths"
    fi

    # Retry bundle contents
    if grep -qi "retry\|bug fix\|forked" "$file" && grep -q "failure output\|prior-attempt" "$file"; then
      pass "$label retry bundle includes failure output and prior-attempt summary"
    else
      fail "$label retry bundle must include failure output and prior-attempt summary"
    fi

    # Review bundle contents
    if grep -qi "review\|critique" "$file" && grep -q "diff" "$file" && grep -q "touched files" "$file" && grep -q "verification command output\|verification.*output" "$file"; then
      pass "$label review bundle includes diff, touched files, verification output"
    else
      fail "$label review bundle must include diff, touched files, verification command output"
    fi

    # Diagnosis bundle contents
    if grep -qi "diagnosis\|stuck-step" "$file" && grep -qi "failure history" "$file" && grep -qi "ranked code context\|ranked.*context" "$file"; then
      pass "$label diagnosis bundle includes failure history and ranked code context"
    else
      fail "$label diagnosis bundle must include failure history and ranked code context"
    fi
  done
}

test_corrective_redelegation() {
  run_test "#43 corrective re-delegation is documented and distinguished from mid-run steering"
  local pippy="$REPO_ROOT/config/agents/pippy.md"
  local skill="$REPO_ROOT/config/skills/pippy/SKILL.md"

  for file in "$pippy" "$skill"; do
    local label
    label="$(basename "$file")"

    if grep -qi "corrective re-delegation\|corrective redelegation" "$file"; then
      pass "$label mentions corrective re-delegation"
    else
      fail "$label must mention corrective re-delegation"
    fi

    if grep -qi "mid-run steering\|mid-run steer\|true mid-run steering" "$file"; then
      pass "$label distinguishes corrective re-delegation from mid-run steering"
    else
      fail "$label must distinguish corrective re-delegation from mid-run steering"
    fi
  done
}

test_review_routing() {
  run_test "#44 review routing classified as fresh-context work"
  local pippy="$REPO_ROOT/config/agents/pippy.md"
  local skill="$REPO_ROOT/config/skills/pippy/SKILL.md"
  local found=false

  for file in "$pippy" "$skill"; do
    if grep -qi "review.*fresh-context\|review.*fresh.context\|Review.*fresh-context\|review.*fresh context" "$file" &&
       grep -q "diff" "$file" &&
       grep -q "touched files" "$file" &&
       grep -q "acceptance criteria" "$file" &&
       grep -q "verification command output\|verification.*output" "$file"; then
      found=true
      pass "$(basename "$file") classifies review as fresh-context with correct bundle contents"
    fi
  done

  if [[ "$found" == false ]]; then
    fail "pippy.md or SKILL.md must classify review as fresh-context work with diff, touched files, acceptance criteria, verification command output"
  fi
}

test_deferred_dispatch() {
  run_test "#42 deferred dynamic dispatch capabilities documented"
  local pippy="$REPO_ROOT/config/agents/pippy.md"
  local skill="$REPO_ROOT/config/skills/pippy/SKILL.md"
  local found=false

  for file in "$pippy" "$skill"; do
    if grep -qi "per-Task model override is deferred\|per-task model override is deferred" "$file"; then
      found=true
      pass "$(basename "$file") states per-Task model override is deferred"
    fi
  done

  if [[ "$found" == false ]]; then
    fail "pippy.md or SKILL.md must state per-Task model override is deferred"
  fi

  # Check deferred capabilities listed
  local combined
  combined="$(cat "$pippy" "$skill")"
  for cap in "mid-run steering\|mid-run steer" "queueing\|queue" "parallel children" "recipe-style dynamic subagent\|recipe-style" "persistent step manifest"; do
    if echo "$combined" | grep -qi "$cap"; then
      pass "deferred capability found: $cap"
    else
      fail "deferred capability missing: $cap"
    fi
  done
}

test_improvement_loop_doc() {
  run_test "#48 pippy-improvement-loop.md exists with required content"
  local doc="$REPO_ROOT/docs/agents/pippy-improvement-loop.md"

  if [[ ! -f "$doc" ]]; then
    fail "docs/agents/pippy-improvement-loop.md does not exist"
    return
  fi
  pass "pippy-improvement-loop.md exists"

  if grep -qi "human-reviewed\|human.reviewed" "$doc"; then
    pass "doc mentions human-reviewed"
  else
    fail "doc must mention human-reviewed"
  fi

  if grep -qi "does.*not.*automatically modify Pippy\|does not automatically modify" "$doc"; then
    pass "doc states it does not automatically modify Pippy"
  else
    fail "doc must state it does not automatically modify Pippy"
  fi

  if grep -qi "Pippy-owned friction\|pippy-owned friction" "$doc" && grep -qi "ordinary project failure\|ordinary.*failure" "$doc"; then
    pass "doc distinguishes Pippy-owned friction from ordinary project failure"
  else
    fail "doc must distinguish Pippy-owned friction from ordinary project failure"
  fi
}

test_external_trigger_recipe() {
  run_test "#49 external-trigger-recipe.md exists with required content"
  local doc="$REPO_ROOT/docs/agents/external-trigger-recipe.md"

  if [[ ! -f "$doc" ]]; then
    fail "docs/agents/external-trigger-recipe.md does not exist"
    return
  fi
  pass "external-trigger-recipe.md exists"

  if grep -qi "cron\|scheduler\|CI\|github actions\|scheduled" "$doc"; then
    pass "doc names an outside trigger mechanism"
  else
    fail "doc must name an outside trigger mechanism (cron/scheduler/CI)"
  fi

  if grep -qi "scheduling.*outside\|outside.*pippy\|scheduling stays outside" "$doc"; then
    pass "doc keeps scheduling outside Pippy"
  else
    fail "doc must state scheduling stays outside Pippy"
  fi

  if grep -q '/goal' "$doc" && grep -qi "verifiable.*objective\|observable.*acceptance\|acceptance criteria" "$doc"; then
    pass "doc includes a verifiable /goal objective with acceptance criteria"
  else
    fail "doc must include a verifiable /goal objective with observable acceptance criteria"
  fi

  if grep -qi "pippy improvement loop\|improvement loop\|loop stack" "$doc"; then
    pass "doc links back to Pippy loop stack / improvement loop"
  else
    fail "doc must link back to Pippy loop stack or improvement loop"
  fi
}

test_improvement_signal_smoke() {
  run_test "#47 manual smoke tests include Improvement Signal examples"
  local file="$REPO_ROOT/docs/agents/manual-smoke-tests.md"

  if [[ ! -f "$file" ]]; then
    fail "manual-smoke-tests.md does not exist"
    return
  fi

  if grep -qi "Improvement Signal: None\|Improvement Signal.*None" "$file"; then
    pass "smoke test includes Improvement Signal: None example"
  else
    fail "smoke test must include an Improvement Signal: None example"
  fi

  if grep -qi "Improvement Signal" "$file" && grep -qi "vague\|rewritten\|context.*compress\|read multiple times\|prior-attempt" "$file"; then
    pass "smoke test includes a valid Pippy-owned improvement signal example"
  else
    fail "smoke test must include a valid Pippy-owned improvement signal example"
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
  test_opencode_reference_pack
  test_caveman_mode_not_cli_only
  test_external_deps_are_pinned
  test_pippy_build_bash_permissions
  test_goal_output_format
  test_verify_is_part_of_goal
  test_ship_guidance
  test_doctor_script
  test_acceptance_criteria_are_verifiable
  test_plan_steps_ordered_scoped
  test_outcome_must_be_done_blocked_partial
  test_final_verification_gate_required
  test_ship_budget_efficiency_smoke_test
  test_adr_bump_process
  test_context_assembly
  test_corrective_redelegation
  test_review_routing
  test_deferred_dispatch
  test_improvement_loop_doc
  test_external_trigger_recipe
  test_improvement_signal_smoke

  echo ""
  echo "========================="
  echo "Passed: $PASSED"
  echo "Failed: $FAILED"
  echo "========================="

  [[ $FAILED -eq 0 ]]
}

main "$@"

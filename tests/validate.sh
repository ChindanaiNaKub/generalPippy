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
              config/commands/grill-to-goal.md config/commands/pippy-update.md \
              config/skills/pippy/SKILL.md \
              config/skills/grill-to-goal/SKILL.md \
              config/references/opencode/REFERENCE.md \
              config/plugins/generalpippy-update-check.js \
              config/generalpippy/update-check.mjs \
              manifest.json \
              config/model-profiles/budget.json \
              config/model-profiles/thorough.json \
              config/model-profiles/balanced.json; do
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

test_budget_command_is_role_usage_accounting() {
  run_test "/budget reports exact role usage accounting without fake estimates"
  local file="$REPO_ROOT/config/commands/budget.md"

  if grep -qi "OpenCode-recorded session usage is authoritative" "$file" && grep -qi "Do \\*\\*not\\*\\* estimate" "$file"; then
    pass "budget command states OpenCode-recorded source and no-estimate rule"
  else
    fail "budget command must state OpenCode-recorded source and no-estimate rule"
  fi

  if grep -q "Coordinator (\`pippy\`)" "$file" &&
     grep -q "Planning (\`pippy-plan\`)" "$file" &&
     grep -q "Implementation (\`pippy-build\`)" "$file" &&
     grep -q "Total" "$file"; then
    pass "budget command defines role usage rows"
  else
    fail "budget command must define Coordinator, Planning, Implementation, and Total rows"
  fi

  for field in "model" "session count" "input tokens" "output tokens" "cache-read tokens" "cache-write tokens" "cost"; do
    if grep -qi "$field" "$file"; then
      pass "budget command includes $field"
    else
      fail "budget command must include $field in each role row"
    fi
  done

  if grep -q "| Role | Model | Sessions | Input Tokens | Output Tokens | Cache-Read Tokens | Cache-Write Tokens | Cost |" "$file" &&
     grep -q "Do not omit \`Cost\`" "$file"; then
    pass "budget command includes explicit cost-bearing table template"
  else
    fail "budget command must include an explicit role accounting table template with Cost"
  fi

  if grep -q "Do \\*\\*not\\*\\* say implementation happened directly on a strong model merely because Coordinator cost is high" "$file" &&
     grep -q "Only report implementation bypass" "$file"; then
    pass "budget command distinguishes coordinator cost from implementation bypass"
  else
    fail "budget command must not blame implementation bypass from coordinator cost alone"
  fi

  if grep -q "/budget <session-id>" "$file" &&
     grep -qi "ambiguous" "$file" &&
     grep -qi "stop instead of guessing" "$file"; then
    pass "budget command documents historical session ids and ambiguous auto-detection"
  else
    fail "budget command must document /budget <session-id> and ambiguous auto-detection behavior"
  fi

  if grep -q "opencode db path" "$file" &&
     grep -q "opencode db --format json" "$file" &&
     grep -q "from session" "$file" &&
     grep -q "parent_id = '<root-session-id>'" "$file"; then
    pass "budget command reads OpenCode session DB before blocking"
  else
    fail "budget command must query OpenCode's session DB before reporting exact accounting as blocked"
  fi

  if grep -qE '\\$[0-9]+(\\.[0-9]+)?\\s*/\\s*\\$[0-9]+(\\.[0-9]+)?' "$file"; then
    fail "budget command contains static pricing table"
  else
    pass "budget command has no static pricing table"
  fi

  # ponytail constraint vs ponytail plugin distinction
  if grep -q "ponytail constraint" "$file" && grep -q "ponytail plugin" "$file"; then
    pass "budget command distinguishes ponytail constraint from ponytail plugin"
  else
    fail "budget command must distinguish ponytail constraint from ponytail plugin"
  fi

  # optional-tool statuses: not applicable / not visibly exercised / missed opportunity
  if grep -q "not applicable" "$file" && grep -q "not visibly exercised" "$file" && grep -q "missed opportunity" "$file"; then
    pass "budget command defines optional-tool statuses (not applicable, not visibly exercised, missed opportunity)"
  else
    fail "budget command must define optional-tool statuses: not applicable, not visibly exercised, missed opportunity"
  fi

  # explicit compression recommendation
  if grep -qi "compression recommendation" "$file"; then
    pass "budget command includes explicit compression recommendation"
  else
    fail "budget command must include an explicit compression recommendation"
  fi

  # Caveman mode vs Caveman CLI distinction
  if grep -q "Caveman mode" "$file" && grep -q "Caveman CLI" "$file"; then
    pass "budget command distinguishes Caveman mode from Caveman CLI"
  else
    fail "budget command must distinguish Caveman mode from Caveman CLI"
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

  if grep -q "edit: deny" "$pippy_plan" && grep -q '"\*": ask' "$pippy_plan" && grep -q '"rtk \*": allow' "$pippy_plan"; then
    pass "pippy-plan remains read-only with granular rtk bash access"
  else
    fail "pippy-plan must remain read-only with granular rtk bash access"
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
     grep -q "profile.json" "$manual_smoke" &&
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

test_opencode_default_tools() {
  run_test "OpenCode formatter and LSP defaults are enabled"
  local opencode="$REPO_ROOT/config/opencode.jsonc"
  local readme="$REPO_ROOT/README.md"
  local smoke="$REPO_ROOT/docs/agents/manual-smoke-tests.md"
  local installer="$REPO_ROOT/install.sh"

  if grep -q '"formatter"[[:space:]]*:[[:space:]]*true' "$opencode"; then
    pass "opencode.jsonc enables formatter"
  else
    fail "opencode.jsonc must enable formatter by default"
  fi

  if grep -q '"lsp"[[:space:]]*:[[:space:]]*true' "$opencode"; then
    pass "opencode.jsonc enables LSP"
  else
    fail "opencode.jsonc must enable LSP by default"
  fi

  if grep -q "LSP servers" "$readme" && grep -q "Built-in language servers are enabled by default" "$readme"; then
    pass "README documents LSP default"
  else
    fail "README must document that LSP servers are enabled by default"
  fi

  if grep -q "lsp" "$smoke" && grep -q "\`lsp\` is \`true\`" "$smoke"; then
    pass "manual smoke test checks resolved LSP config"
  else
    fail "manual smoke test must check resolved lsp=true"
  fi

  if grep -q "lsp" "$installer" && grep -q "Built-in language servers enabled" "$installer"; then
    pass "installer reports LSP default"
  else
    fail "installer must report that LSP servers are enabled"
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
  if grep -q 'jcodemunch-mcp.git@v1.0.0' "$config"; then
    pass "jcodemunch MCP is pinned to v1.0.0"
  else
    fail "jcodemunch MCP source must be pinned to working tag v1.0.0"
  fi

  if grep -q '"command": \["uvx", "--from", "git+https://github.com/jgravelle/jcodemunch-mcp.git@v1.0.0", "jcodemunch-mcp"\]' "$config"; then
    pass "jcodemunch MCP pinned command starts with uvx"
  else
    fail "jcodemunch MCP pinned command must start with uvx"
  fi

  # rtk must be pinned to a specific version in install.sh.
  if grep -q 'rtk_version=' "$installer" && grep -q 'refs/tags/v' "$installer"; then
    pass "rtk install is pinned to a release tag"
  else
    fail "rtk install must be pinned to a specific release tag"
  fi
}

test_cc_safety_net_pinned() {
  run_test "cc-safety-net@1.0.6 is pinned in config, installer, and ADR"
  local config="$REPO_ROOT/config/opencode.jsonc"
  local installer="$REPO_ROOT/install.sh"
  local adr="$REPO_ROOT/docs/adr/0003-pin-external-dependencies.md"
  local readme="$REPO_ROOT/README.md"
  local manual_smoke="$REPO_ROOT/docs/agents/manual-smoke-tests.md"

  if grep -q 'cc-safety-net@1.0.6' "$config"; then
    pass "opencode.jsonc contains cc-safety-net@1.0.6"
  else
    fail "opencode.jsonc must contain cc-safety-net@1.0.6"
  fi

  if grep -q 'cc-safety-net@1.0.6' "$installer"; then
    pass "install.sh contains cc-safety-net@1.0.6"
  else
    fail "install.sh must contain cc-safety-net@1.0.6 in pinned plugins"
  fi

  if grep -q 'cc-safety-net' "$adr" && grep -q '1.0.6' "$adr"; then
    pass "ADR-0003 contains cc-safety-net pin at 1.0.6"
  else
    fail "ADR-0003 must document cc-safety-net as pinned to 1.0.6"
  fi

  if grep -q 'https://github.com/kenryu42/cc-safety-net' "$readme"; then
    pass "README links to cc-safety-net upstream"
  else
    fail "README must link to https://github.com/kenryu42/cc-safety-net"
  fi

  if grep -q 'opencode plugin -g' "$installer"; then
    fail "install.sh must not install cc-safety-net through opencode plugin -g"
  else
    pass "install.sh does not use global opencode plugin install"
  fi

  if grep -q 'CC_SAFETY_NET_STRICT' "$manual_smoke" &&
     grep -qi 'fails closed' "$manual_smoke" &&
     grep -qi 'cannot be safely analyzed' "$manual_smoke" &&
     grep -q 'CC_SAFETY_NET_PARANOID' "$manual_smoke" &&
     grep -qi 'interpreter one-liner' "$manual_smoke" &&
     grep -q 'CC_SAFETY_NET_WORKTREE' "$manual_smoke" &&
     grep -qi 'proven linked worktrees' "$manual_smoke"; then
    pass "manual smoke docs describe cc-safety-net modes accurately"
  else
    fail "manual smoke docs must describe strict/paranoid/worktree modes according to upstream cc-safety-net behavior"
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
  local context="$REPO_ROOT/CONTEXT.md"
  local improvement_loop="$REPO_ROOT/docs/agents/pippy-improvement-loop.md"

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

  # Plan must carry trajectory evidence without adding a fifth report field.
  for file in "$goal" "$pippy" "$skill"; do
    local label
    label="$(basename "$file")"
    if grep -q "trajectory checkpoints" "$file" &&
       grep -qi "cross-run memory" "$file" &&
       grep -qi "recalled memory" "$file" &&
       grep -q "explored" "$file" &&
       grep -q "delegated edits to \`pippy-build\`" "$file" &&
       grep -q "verified each step" "$file" &&
       grep -q "reviewed diff" "$file" &&
       grep -q "final-verified" "$file"; then
      pass "$label Plan includes trajectory checkpoints"
    else
      fail "$label Plan must include trajectory checkpoints inside the existing Plan field"
    fi
  done

  for file in "$goal" "$pippy" "$skill"; do
    local label
    label="$(basename "$file")"
    if grep -q "Program design handling" "$file" &&
       grep -q "skipped a needed sketch\|skipped a needed Program design sketch" "$file" &&
       grep -q "passing tests without design evidence" "$file" &&
       grep -qi "pre-existing code\|pre-existing project code" "$file"; then
      pass "$label Improvement Signal covers Pippy-owned Program design misses"
    else
      fail "$label must limit Program design Improvement Signals to Pippy-owned misses"
    fi
  done

  for file in "$goal" "$pippy" "$skill"; do
    local label
    label="$(basename "$file")"
    if grep -qi "malformed or unavailable tool calls" "$file" &&
       grep -q "rtk git ..." "$file" &&
       grep -qi "Pippy-owned friction" "$file"; then
      pass "$label Improvement Signal covers malformed tool calls"
    else
      fail "$label must report malformed or unavailable tool calls as Pippy-owned friction"
    fi
  done

  # Run evidence must stay compact and report-local, not become telemetry.
  for file in "$goal" "$pippy" "$skill" "$improvement_loop"; do
    local label
    label="$(basename "$file")"
    if grep -qi "run evidence" "$file" &&
       grep -qi "commands run" "$file" &&
       grep -qi "verification outputs" "$file" &&
       grep -qi "routing decisions" "$file" &&
       grep -qi "retry causes" "$file" &&
       grep -qi "final evidence" "$file" &&
       grep -qi "raw trace" "$file" &&
       grep -qi "telemetry store" "$file"; then
      pass "$label defines compact run evidence"
    else
      fail "$label must define compact run evidence without raw trace or telemetry-store semantics"
    fi
  done

  if grep -q "Run evidence" "$context" &&
     grep -qi "commands run" "$context" &&
     grep -qi "verification outputs" "$context" &&
     grep -qi "routing decisions" "$context" &&
     grep -qi "retry causes" "$context" &&
     grep -qi "final evidence" "$context" &&
     grep -qi "telemetry store" "$context"; then
    pass "CONTEXT.md defines Run evidence"
  else
    fail "CONTEXT.md must define Run evidence as compact report-local evidence, not telemetry"
  fi
}

test_cross_run_memory() {
  run_test "#53 cross-run memory is config-only, human-reviewed, and recalled before /goal planning"
  local context="$REPO_ROOT/CONTEXT.md"
  local goal="$REPO_ROOT/config/commands/goal.md"
  local pippy="$REPO_ROOT/config/agents/pippy.md"
  local skill="$REPO_ROOT/config/skills/pippy/SKILL.md"
  local doc="$REPO_ROOT/docs/agents/cross-run-memory.md"
  local harness="$REPO_ROOT/docs/agents/pippy-harness.md"
  local improvement="$REPO_ROOT/docs/agents/pippy-improvement-loop.md"
  local adr="$REPO_ROOT/docs/adr/0011-cross-run-memory.md"

  if [[ -f "$doc" && -f "$adr" ]]; then
    pass "cross-run memory doc and ADR exist"
  else
    fail "cross-run memory must have docs/agents/cross-run-memory.md and ADR-0011"
  fi

  if grep -q "Cross-run memory" "$context" &&
     grep -qi "human-approved" "$context" &&
     grep -qi "raw traces" "$context" &&
     grep -qi "telemetry" "$context"; then
    pass "CONTEXT.md defines Cross-run memory"
  else
    fail "CONTEXT.md must define Cross-run memory as human-approved and not telemetry/raw traces"
  fi

  for file in "$goal" "$pippy" "$skill"; do
    local label
    label="$(basename "$file")"
    if grep -q "PIPPY_MEMORY.md" "$file" &&
       grep -q ".pippy/memory.md" "$file" &&
       grep -q "docs/agents/pippy-memory.md" "$file" &&
       grep -qi "guidance, not proof\|not proof" "$file" &&
       grep -qi "must not write memory automatically\|Do not create, edit, or append memory automatically" "$file"; then
      pass "$label defines recall anchors and no-auto-write rule"
    else
      fail "$label must define memory anchors, guidance-not-proof, and no automatic writes"
    fi
  done

  if grep -qi "Cross-run memory" "$harness" &&
     grep -qi "Cross-Run Memory" "$improvement" &&
     grep -qi "does not.*automatically write durable memory\|does not automatically write" "$improvement" &&
     grep -qi "automatic semantic store\|semantic store" "$adr" &&
     grep -qi "config-only" "$adr"; then
    pass "harness, improvement loop, and ADR preserve config-only memory boundary"
  else
    fail "cross-run memory docs must preserve config-only, human-reviewed boundary"
  fi
}

test_goal_rtk_force() {
  run_test "/goal enforces RTK Force after rtk detection"
  local goal="$REPO_ROOT/config/commands/goal.md"
  local pippy="$REPO_ROOT/config/agents/pippy.md"
  local skill="$REPO_ROOT/config/skills/pippy/SKILL.md"
  local evals="$REPO_ROOT/docs/agents/goal-run-evals.md"

  for file in "$goal" "$pippy" "$skill"; do
    local label
    label="$(basename "$file")"
    if grep -q "command -v rtk" "$file" &&
       grep -qi "only allowed raw.*detection command\|only allowed raw shell command" "$file" &&
       grep -q "RTK-locked" "$file" &&
       grep -qi "no exploration grace period" "$file" &&
       grep -q "rtk git status --short" "$file" &&
       grep -q "rtk git log" "$file" &&
       grep -q "rtk git diff" "$file" &&
       grep -q "rtk proxy git diff -- <paths>" "$file" &&
       grep -q "rtk run command -v caveman" "$file" &&
       grep -qi "Raw.*git.*any kind\|raw.*git.*any kind" "$file" &&
       grep -qi "Improvement Signal\|Pippy-owned routing failure" "$file"; then
      pass "$label forces rtk after detection"
    else
      fail "$label must enter RTK-locked state after raw command -v rtk and force rtk for later shell/git/probe commands"
    fi
  done

  if grep -q "RTK Force" "$evals" &&
     grep -q "command -v rtk" "$evals" &&
     grep -q "RTK-locked" "$evals" &&
     grep -qi "no exploration grace period" "$evals" &&
     grep -q "rtk git status --short" "$evals" &&
     grep -q "rtk git log" "$evals" &&
     grep -q "rtk run command -v caveman" "$evals" &&
     grep -qi "baseline dirty-workspace checks" "$evals" &&
     grep -qi "raw.*git.*any kind" "$evals"; then
    pass "goal-run evals catch raw git after rtk detection"
  else
    fail "goal-run evals must catch raw git/probe/baseline commands after rtk detection"
  fi
}

test_goal_verifier_templates() {
  run_test "/goal defines task-type Verifier templates"
  local context="$REPO_ROOT/CONTEXT.md"
  local goal="$REPO_ROOT/config/commands/goal.md"
  local pippy="$REPO_ROOT/config/agents/pippy.md"
  local skill="$REPO_ROOT/config/skills/pippy/SKILL.md"
  local evals="$REPO_ROOT/docs/agents/goal-run-evals.md"

  if grep -q "Verifier template" "$context" &&
     grep -q "task-type-specific evidence checklist" "$context" &&
     grep -q "without becoming separate modes or commands" "$context"; then
    pass "CONTEXT.md defines Verifier template"
  else
    fail "CONTEXT.md must define Verifier template as a task-type evidence checklist"
  fi

  for file in "$goal" "$pippy" "$skill"; do
    local label
    label="$(basename "$file")"
    if grep -q "Verifier template" "$file" &&
       grep -q "Docs-only" "$file" &&
       grep -q "Code change" "$file" &&
       grep -q "Installer/config" "$file" &&
       grep -q "Public docs/config" "$file" &&
       grep -q "Security/data-loss" "$file" &&
       grep -q "Mixed/unclear" "$file" &&
       grep -q "strictest applicable template" "$file" &&
       grep -q "which Verifier template was selected" "$file" &&
       grep -q "Do not add a separate Verifier template" "$file"; then
      pass "$label defines and reports Verifier templates"
    else
      fail "$label must define task-type Verifier templates and require Plan reporting"
    fi
  done

  if grep -q "Eval 11: Verifier Template Selection" "$evals" &&
     grep -q "Docs-only Verifier template" "$evals" &&
     grep -q "strictest applicable template" "$evals" &&
     grep -q "fifth report field" "$evals"; then
    pass "goal-run evals cover Verifier template selection"
  else
    fail "goal-run evals must cover Verifier template selection"
  fi
}

test_verify_is_part_of_goal() {
  run_test "review and final verification are closing gates of /goal, not standalone"
  local goal="$REPO_ROOT/config/commands/goal.md"
  local skill="$REPO_ROOT/config/skills/pippy/SKILL.md"

  # goal.md must say review and final verification are closing gates
  if grep -qi "Review and final verification are the closing gates" "$goal" && grep -qi "review followed by final verification" "$goal"; then
    pass "goal.md describes review and final verification as /goal closing gates"
  else
    fail "goal.md must describe review and final verification as /goal closing gates"
  fi

  # SKILL.md must say review and final verification are closing gates
  if grep -qi "Review and final verification are the closing gates" "$skill" && grep -qi "review followed by final verification" "$skill"; then
    pass "SKILL.md describes review and final verification as /goal closing gates"
  else
    fail "SKILL.md must describe review and final verification as /goal closing gates"
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

test_assumption_audit_review_gate() {
  run_test "Assumption audit is a validated REVIEW sub-step"
  local goal="$REPO_ROOT/config/commands/goal.md"
  local pippy="$REPO_ROOT/config/agents/pippy.md"
  local skill="$REPO_ROOT/config/skills/pippy/SKILL.md"
  local harness="$REPO_ROOT/docs/agents/pippy-harness.md"
  local improvement="$REPO_ROOT/docs/agents/pippy-improvement-loop.md"
  local context="$REPO_ROOT/CONTEXT.md"

  if grep -q "Assumption audit" "$context" &&
     grep -qi "authoritative source" "$context" &&
     grep -qi "executable evidence" "$context" &&
     grep -qi "concrete scenario" "$context"; then
    pass "CONTEXT.md defines Assumption audit"
  else
    fail "CONTEXT.md must define Assumption audit as source/evidence/scenario checking"
  fi

  for file in "$goal" "$pippy" "$skill"; do
    local label
    label="$(basename "$file")"
    if grep -q "Assumption audit" "$file" &&
       grep -qi "REVIEW" "$file" &&
       grep -qi "authoritative source" "$file" &&
       grep -qi "executable evidence" "$file" &&
       grep -qi "concrete scenario" "$file" &&
       grep -qi "source-check external links" "$file" &&
       grep -qi "package metadata" "$file" &&
       grep -qi "dry-run runnable docs" "$file" &&
       grep -qi "verification rigor\|audit depth" "$file" &&
       grep -qi "Plan.*evidence" "$file" &&
       grep -qi "fifth report field" "$file"; then
      pass "$label includes Assumption audit in REVIEW without adding a report field"
    else
      fail "$label must define Assumption audit as a REVIEW sub-step with scaled source/evidence/scenario checks and no fifth report field"
    fi
  done

  if grep -q "Assumption audit" "$harness" &&
     grep -qi "Verification gates" "$harness" &&
     grep -qi "Plan with run evidence" "$harness"; then
    pass "pippy-harness.md includes Assumption audit in verification/reporting ownership"
  else
    fail "pippy-harness.md must include Assumption audit in verification and reporting ownership"
  fi

  if grep -q "Assumption audit" "$improvement" &&
     grep -qi "missed an unsupported external-link/package claim" "$improvement" &&
     grep -qi "add a specific Assumption audit check" "$improvement"; then
    pass "pippy-improvement-loop.md routes accepted signals into Assumption audit checks"
  else
    fail "pippy-improvement-loop.md must describe Assumption audit misses and accepted audit checks"
  fi
}

test_ship_guidance() {
  run_test "/ship includes green-gate PR creation, harness smoke evals, rtk routing, caveman reports, compress, and release confirmation"
  local file="$REPO_ROOT/config/commands/ship.md"

  if grep -q "Green-Gate PR Creation" "$file" &&
     grep -q "clean-tree gate" "$file" &&
     grep -q "Branch-safety gate" "$file" &&
     grep -q "GitHub-readiness gate" "$file" &&
     grep -q "Existing-PR gate" "$file" &&
     grep -q "Harness smoke eval gate" "$file"; then
    pass "/ship defines green-gate sequence before PR creation"
  else
    fail "/ship must define harness smoke eval, clean-tree, branch-safety, GitHub-readiness, and existing-PR gates"
  fi

  if grep -q "not the default branch" "$file" &&
     grep -q "dirty working tree" "$file" &&
     grep -q "non-interactive" "$file" &&
     grep -q "gh pr create --title" "$file"; then
    pass "/ship forbids unsafe branches/dirty trees and creates PRs non-interactively"
  else
    fail "/ship must refuse default branch/dirty tree PRs and create PRs non-interactively"
  fi

  if grep -q "\`Shipped\`" "$file" &&
     grep -q "PR URL" "$file" &&
     grep -q "\`Ready, PR blocked\`" "$file" &&
     grep -q "failed command" "$file" &&
     grep -q "generated PR title/body" "$file"; then
    pass "/ship defines Shipped and Ready, PR blocked outcomes"
  else
    fail "/ship must define Shipped with PR URL and Ready, PR blocked with retry details"
  fi

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

  if grep -q "scripts/goal-run-smoke-evals.sh --dry-run" "$file" &&
     grep -q "scripts/goal-run-smoke-evals.sh --live" "$file" &&
     grep -q "docs/agents/pippy-harness.md" "$file" &&
     grep -q "Verifier template" "$file" &&
     grep -q "PR body" "$file"; then
    pass "/ship routes harness changes through goal-run smoke eval gate"
  else
    fail "/ship must run dry-run smoke evals for harness changes and run/recommend live evals for verifier/report-shape prompt changes"
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

  if grep -q "PROFILE_METADATA" "$script" &&
     grep -q "coordination role renders as" "$script" &&
     grep -q "planning role renders as" "$script" &&
     grep -q "implementation role renders as" "$script" &&
     grep -q "system-task role renders as" "$script"; then
    pass "doctor.sh validates role models from profile metadata"
  else
    fail "doctor.sh must validate role models from profile metadata"
  fi
}

test_acceptance_criteria_are_verifiable() {
  run_test "#12 acceptance criteria must be observable/testable"
  local goal="$REPO_ROOT/config/commands/goal.md"
  local pippy="$REPO_ROOT/config/agents/pippy.md"
  local skill="$REPO_ROOT/config/skills/pippy/SKILL.md"

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

  for file in "$goal" "$pippy" "$skill"; do
    local label
    label="$(basename "$file")"
    if grep -qi "Scale verification rigor to task risk" "$file" &&
       grep -qi "release prep" "$file" &&
       grep -qi "auth" "$file" &&
       grep -qi "security" "$file" &&
       grep -qi "data loss" "$file" &&
       grep -qi "installer behavior" "$file" &&
       grep -qi "permissions" "$file" &&
       grep -qi "public docs/config" "$file" &&
       grep -qi "low-risk prototype" "$file" &&
       grep -qi "separate mode flag" "$file"; then
      pass "$label scales verification rigor through acceptance criteria"
    else
      fail "$label must scale verification rigor to task risk without adding a separate mode flag"
    fi
  done
}

test_goal_readiness_and_grill_to_goal() {
  run_test "Goal readiness and /grill-to-goal are documented, packaged, and reusable"
  local command="$REPO_ROOT/config/commands/grill-to-goal.md"
  local skill="$REPO_ROOT/config/skills/grill-to-goal/SKILL.md"
  local goal="$REPO_ROOT/config/commands/goal.md"
  local pippy="$REPO_ROOT/config/agents/pippy.md"
  local pippy_skill="$REPO_ROOT/config/skills/pippy/SKILL.md"
  local context="$REPO_ROOT/CONTEXT.md"
  local adr="$REPO_ROOT/docs/adr/0012-goal-readiness-and-grill-to-goal.md"
  local evals="$REPO_ROOT/docs/agents/goal-run-evals.md"
  local installer="$REPO_ROOT/install.sh"

  if [[ -f "$command" ]] && [[ -f "$skill" ]]; then
    pass "/grill-to-goal command and skill exist"
  else
    fail "/grill-to-goal command and skill must exist"
  fi

  if grep -q "Shared Design Concept" "$command" &&
     grep -q "Goal-Ready Prompt" "$command" &&
     grep -q "Do not perform implementation edits during grilling" "$command"; then
    pass "grill-to-goal command defines output and no-implementation contract"
  else
    fail "grill-to-goal command must define output and no-implementation contract"
  fi

  if grep -q "Ask one question at a time" "$skill" &&
     grep -q "CONTEXT.md is a glossary" "$skill" &&
     grep -q "docs/goals/YYYY-MM-DD-short-slug.md" "$skill"; then
    pass "grill-to-goal skill defines interactive docs-aware workflow"
  else
    fail "grill-to-goal skill must define interactive docs-aware workflow and goal brief path"
  fi

  for file in "$goal" "$pippy" "$pippy_skill"; do
    local label
    label="$(basename "$file")"
    if grep -q "Goal readiness" "$file" &&
       grep -q "/grill-to-goal" "$file" &&
       grep -q "inventing product direction" "$file"; then
      pass "$label checks Goal readiness before planning"
    else
      fail "$label must check Goal readiness and recommend /grill-to-goal for invented product direction"
    fi
  done

  if grep -q "Goal readiness" "$context" &&
     grep -q "Goal-ready prompt" "$context" &&
     grep -q "Goal brief" "$context"; then
    pass "CONTEXT.md defines Goal readiness terms"
  else
    fail "CONTEXT.md must define Goal readiness, Goal-ready prompt, and Goal brief"
  fi

  if grep -q "Status: accepted" "$adr" &&
     grep -q "slash command and a reusable skill" "$adr" &&
     grep -q "docs/goals/YYYY-MM-DD-short-slug.md" "$adr"; then
    pass "ADR-0012 records Goal readiness decision"
  else
    fail "ADR-0012 must record Goal readiness command/skill and brief path decision"
  fi

  if grep -q "Eval 8: Goal Readiness Clarification" "$evals" &&
     grep -q "make the settings screen better" "$evals"; then
    pass "goal-run evals cover Goal readiness clarification"
  else
    fail "goal-run evals must include Goal readiness clarification scenario"
  fi

  if grep -q 'config/commands/grill-to-goal.md' "$installer" &&
     grep -q 'config/skills/grill-to-goal/SKILL.md' "$installer"; then
    pass "install.sh includes grill-to-goal command and skill"
  else
    fail "install.sh must copy grill-to-goal command and skill"
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
  run_test "#15 plan must always end with review and final verification gates"
  local goal="$REPO_ROOT/config/commands/goal.md"
  local pippy="$REPO_ROOT/config/agents/pippy.md"
  local skill="$REPO_ROOT/config/skills/pippy/SKILL.md"

  # goal.md must say the plan ends with review followed by final verification
  if grep -qi "plan must always end with review followed by final verification" "$goal"; then
    pass "goal.md requires plan to end with review and final verification gates"
  else
    fail "goal.md must require plan to end with review followed by final verification"
  fi

  # pippy.md must say plan must always end with verification
  if grep -qi "plan must always end\|always end with this verification\|no step can skip it" "$pippy"; then
    pass "pippy.md requires plan to end with final verification gate"
  else
    fail "pippy.md must require plan to always end with final verification gate"
  fi

  # skill.md must say the plan ends with review followed by final verification
  if grep -qi "plan must always end with review followed by final verification" "$skill"; then
    pass "SKILL.md requires plan to end with review and final verification gates"
  else
    fail "SKILL.md must require plan to end with review followed by final verification"
  fi
}

test_ship_budget_efficiency_smoke_test() {
  run_test "#21 /ship green-gate and budget-efficiency smoke test exists"
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
    pass "/ship smoke test checks context compression before closing gates"
  else
    fail "/ship smoke test must check context compression before closing gates"
  fi

  if grep -qi "caveman-full" "$file"; then
    pass "/ship smoke test checks caveman-full reporting"
  else
    fail "/ship smoke test must check caveman-full reporting"
  fi

  if grep -q "Green-gate sequence" "$file" &&
     grep -q "Auto-PR success" "$file" &&
     grep -q "Blocked PR outcome" "$file" &&
     grep -q "\`Shipped\`" "$file" &&
     grep -q "\`Ready, PR blocked\`" "$file"; then
    pass "/ship smoke test covers successful and blocked auto-PR behavior"
  else
    fail "/ship smoke test must cover successful auto-PR behavior and blocked PR behavior"
  fi

  if grep -qi "re-fetch\|re-fetches\|no re-fetch\|does not re-fetch" "$file"; then
    pass "/ship smoke test checks no re-fetch of releases"
  else
    fail "/ship smoke test must check no re-fetch of releases"
  fi

  if grep -q "Harness smoke eval gate" "$file" &&
     grep -q "scripts/goal-run-smoke-evals.sh --dry-run" "$file" &&
     grep -q "scripts/goal-run-smoke-evals.sh --live" "$file" &&
     grep -q "Verifier template" "$file"; then
    pass "/ship smoke test checks harness goal-run smoke eval gate"
  else
    fail "/ship smoke test must cover dry-run and live goal-run smoke eval expectations for harness changes"
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

    if grep -q "Program design sketch" "$file" && grep -qi "when present" "$file"; then
      pass "$label first-attempt bundle includes Program design sketch when present"
    else
      fail "$label first-attempt bundle must include Program design sketch when present"
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

test_program_design_sketch_routing() {
  run_test "Program design sketch is conditional, read-only, and routed through pippy-plan"
  local context="$REPO_ROOT/CONTEXT.md"
  local pippy="$REPO_ROOT/config/agents/pippy.md"
  local skill="$REPO_ROOT/config/skills/pippy/SKILL.md"
  local goal="$REPO_ROOT/config/commands/goal.md"
  local plan="$REPO_ROOT/config/agents/pippy-plan.md"
  local build="$REPO_ROOT/config/agents/pippy-build.md"
  local harness="$REPO_ROOT/docs/agents/pippy-harness.md"
  local adr6="$REPO_ROOT/docs/adr/0006-dynamic-subagent-dispatch.md"

  if grep -q "Design-sensitive change" "$context" &&
     grep -q "Program design sketch" "$context"; then
    pass "CONTEXT.md defines design-sensitive change and Program design sketch"
  else
    fail "CONTEXT.md must define design-sensitive change and Program design sketch"
  fi

  for file in "$pippy" "$skill" "$goal"; do
    local label
    label="$(basename "$file")"
    if grep -q "Program design sketch" "$file" &&
       grep -q "design-sensitive" "$file" &&
       grep -qi "multi-file" "$file" &&
       grep -qi "small mechanical edits" "$file"; then
      pass "$label gates Program design sketch to design-sensitive changes"
    else
      fail "$label must gate Program design sketch to design-sensitive changes and skip small mechanical edits"
    fi
  done

  if grep -q "Program Design Sketches" "$plan" &&
     grep -q "Responsibility boundaries" "$plan" &&
     grep -q "Dependency direction" "$plan" &&
     grep -q "State ownership" "$plan"; then
    pass "pippy-plan can produce Program design sketches"
  else
    fail "pippy-plan must define a Program Design Sketch output shape"
  fi

  if grep -q "Program design sketch" "$build" && grep -q "pippy-plan" "$build"; then
    pass "pippy-build follows Program design sketches from pippy-plan"
  else
    fail "pippy-build must follow Program design sketches from pippy-plan when present"
  fi

  if grep -q "read-only Program design sketches" "$harness" &&
     grep -q "Program design sketch when present" "$adr6"; then
    pass "harness and ADR-0006 document Program design sketch routing"
  else
    fail "harness and ADR-0006 must document Program design sketch routing"
  fi
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
  local goal="$REPO_ROOT/config/commands/goal.md"
  local context="$REPO_ROOT/CONTEXT.md"
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

  for file in "$goal" "$pippy" "$skill"; do
    local label
    label="$(basename "$file")"
    if grep -qi "review checklist" "$file" &&
       grep -qi "edge cases" "$file" &&
       grep -qi "error handling" "$file" &&
       grep -qi "integration assumptions" "$file" &&
       grep -qi "hallucinated dependencies" "$file" &&
       grep -qi "clever-looking generated code" "$file"; then
      pass "$label includes last-20% review checklist"
    else
      fail "$label must include review checklist for edge cases, error handling, integration assumptions, hallucinated dependencies, and clever-looking generated code"
    fi
  done

  if grep -q "Review checklist" "$context" && grep -qi "last-20% failures" "$context"; then
    pass "CONTEXT.md defines Review checklist"
  else
    fail "CONTEXT.md must define Review checklist"
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
    if grep -qi "$cap" <<< "$combined"; then
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

  if grep -q "Program design handling" "$doc" &&
     grep -q "Program design sketch" "$doc" &&
     grep -q "passing tests without Program design evidence" "$doc" &&
     grep -q "pre-existing design debt" "$doc"; then
    pass "doc distinguishes Pippy-owned Program design misses from pre-existing design debt"
  else
    fail "doc must distinguish Pippy-owned Program design misses from pre-existing design debt"
  fi

  if grep -qi "guardrail candidate" "$doc" &&
     grep -qi "runtime guardrail hooks" "$doc" &&
     grep -qi "repeated run evidence" "$doc" &&
     grep -qi "config-only" "$doc" &&
     grep -qi "platform-level commitment" "$doc"; then
    pass "doc defers runtime guardrail hooks until specific evidence exists"
  else
    fail "doc must defer runtime guardrail hooks and describe guardrail candidates"
  fi

  if grep -q "Guardrail candidate" "$REPO_ROOT/CONTEXT.md" &&
     grep -qi "repeated run evidence" "$REPO_ROOT/CONTEXT.md" &&
     grep -qi "runtime hook" "$REPO_ROOT/CONTEXT.md"; then
    pass "CONTEXT.md defines Guardrail candidate"
  else
    fail "CONTEXT.md must define Guardrail candidate"
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

  if grep -q "Program design" "$file" &&
     grep -q "skipped the Program design REVIEW check" "$file" &&
     grep -q "messy pre-existing code" "$file"; then
    pass "smoke test includes valid and invalid Program design Improvement Signal examples"
  else
    fail "smoke test must include valid and invalid Program design Improvement Signal examples"
  fi
}

test_goal_run_evals_doc() {
  run_test "#51 goal-run eval suite exists with trajectory/routing/retry checks"
  local doc="$REPO_ROOT/docs/agents/goal-run-evals.md"
  local readme="$REPO_ROOT/README.md"
  local context="$REPO_ROOT/CONTEXT.md"
  local smoke="$REPO_ROOT/scripts/goal-run-smoke-evals.sh"

  if [[ ! -f "$doc" ]]; then
    fail "docs/agents/goal-run-evals.md does not exist"
    return
  fi
  pass "goal-run-evals.md exists"

  if grep -qi "manual by design\|config-only" "$doc"; then
    pass "eval doc keeps GeneralPippy config-only"
  else
    fail "eval doc must state evals are manual/config-only"
  fi

  for term in "trajectory" "routing" "verification" "retry" "Improvement Signal"; do
    if grep -qi "$term" "$doc"; then
      pass "eval doc covers $term"
    else
      fail "eval doc must cover $term"
    fi
  done

  if grep -q '/goal' "$doc" && grep -qi "Expected behavior" "$doc" && grep -qi "Failure signals" "$doc"; then
    pass "eval doc includes /goal scenarios with expected behavior and failure signals"
  else
    fail "eval doc must include /goal scenarios with expected behavior and failure signals"
  fi

  if grep -q "Passing Tests, Bad Program Design" "$doc" &&
     grep -q "Program design sketch" "$doc" &&
     grep -q "passing tests" "$doc" &&
     grep -q "overloaded interfaces" "$doc" &&
     grep -q "state ownership" "$doc" &&
     grep -q "skipped a needed sketch" "$doc" &&
     grep -q "pre-existing design debt" "$doc"; then
    pass "eval doc includes passing-tests/bad-program-design scenario"
  else
    fail "eval doc must include a passing-tests/bad-program-design scenario"
  fi

  if grep -q "Assumption Audit And RTK Path Diff Fallback" "$doc" &&
     grep -q "Assumption audit evidence" "$doc" &&
     grep -q "authoritative metadata" "$doc" &&
     grep -q "concrete scenario" "$doc" &&
     grep -q "rtk proxy git diff -- <paths>" "$doc" &&
     grep -q "rtk git diff -- <paths>" "$doc" &&
     grep -q "fifth report field" "$doc"; then
    pass "eval doc includes Assumption audit and RTK path-scoped diff fallback scenario"
  else
    fail "eval doc must include Assumption audit and RTK path-scoped diff fallback scenario"
  fi

  if grep -q "goal-run-evals.md" "$readme"; then
    pass "README links goal-run evals"
  else
    fail "README must link docs/agents/goal-run-evals.md"
  fi

  if grep -q "Goal-run eval suite" "$context"; then
    pass "CONTEXT.md defines Goal-run eval suite"
  else
    fail "CONTEXT.md must define Goal-run eval suite"
  fi

  if [[ -x "$smoke" ]]; then
    pass "goal-run smoke eval runner is executable"
  else
    fail "scripts/goal-run-smoke-evals.sh must exist and be executable"
  fi

  if grep -q "Eval 10" "$smoke" &&
     grep -q "Eval 11" "$smoke" &&
     grep -q -- "--live" "$smoke" &&
     grep -q "Verification gates" "$smoke" &&
     grep -q "Docs-only" "$smoke"; then
    pass "goal-run smoke eval runner covers Eval 10 and Eval 11"
  else
    fail "goal-run smoke eval runner must cover Eval 10/11 verifier smoke checks"
  fi

  if grep -q "goal-run-smoke-evals.sh --dry-run" "$doc" &&
     grep -q "goal-run-smoke-evals.sh --live" "$doc" &&
     grep -q "goal-run-smoke-evals.sh --live" "$readme"; then
    pass "docs describe executable goal-run smoke evals"
  else
    fail "docs must describe dry-run and live goal-run smoke evals"
  fi
}

test_pippy_harness_doc() {
  run_test "#52 pippy harness inventory exists with core components"
  local doc="$REPO_ROOT/docs/agents/pippy-harness.md"
  local readme="$REPO_ROOT/README.md"
  local context="$REPO_ROOT/CONTEXT.md"

  if [[ ! -f "$doc" ]]; then
    fail "docs/agents/pippy-harness.md does not exist"
    return
  fi
  pass "pippy-harness.md exists"

  if grep -qi "config-only" "$doc" &&
     grep -qi "does not add runtime services" "$doc"; then
    pass "harness doc preserves config-only boundary"
  else
    fail "harness doc must preserve config-only boundary"
  fi

  for term in "Agent prompts" "Slash commands" "Skills" "Context assembly" "Subagent routing" "Verification gates" "Verifier templates" "Reporting" "Goal-run evals" "Improvement loop"; do
    if grep -q "$term" "$doc"; then
      pass "harness doc includes $term"
    else
      fail "harness doc must include $term"
    fi
  done

  if grep -q "scripts/goal-run-smoke-evals.sh" "$doc"; then
    pass "harness doc registers goal-run smoke eval runner"
  else
    fail "harness doc must register scripts/goal-run-smoke-evals.sh in the Goal-run evals inventory row"
  fi

  if grep -q "pippy-harness.md" "$readme"; then
    pass "README links pippy harness doc"
  else
    fail "README must link docs/agents/pippy-harness.md"
  fi

  if grep -q "Pippy harness" "$context"; then
    pass "CONTEXT.md defines Pippy harness"
  else
    fail "CONTEXT.md must define Pippy harness"
  fi
}

test_decision_records() {
  run_test "#45/#50 decision records exist with required sections"

  local adr7="$REPO_ROOT/docs/adr/0007-dynamic-model-routing-decision.md"
  local adr8="$REPO_ROOT/docs/adr/0008-improve-pippy-command-decision.md"
  local adr9="$REPO_ROOT/docs/adr/0009-agentic-engineering-harness-adaptation.md"
  local adr14="$REPO_ROOT/docs/adr/0014-role-usage-accounting-and-green-gate-pr-creation.md"

  for adr in "$adr7" "$adr8" "$adr9"; do
    local label
    label="$(basename "$adr")"

    if [[ ! -f "$adr" ]]; then
      fail "$label does not exist"
      continue
    fi
    pass "$label exists"

    # Must have Status (either "## Status" heading or "Status: accepted" field)
    if grep -qi "^## Status\|^Status:" "$adr"; then
      pass "$label has Status"
    else
      fail "$label must have Status section"
    fi

    # Must have Context
    if grep -qi "^## Context" "$adr"; then
      pass "$label has Context"
    else
      fail "$label must have Context section"
    fi

    # Must have Decision
    if grep -qi "^## Decision" "$adr"; then
      pass "$label has Decision"
    else
      fail "$label must have Decision section"
    fi

    # Must have Consequences
    if grep -qi "^## Consequences" "$adr"; then
      pass "$label has Consequences"
    else
      fail "$label must have Consequences section"
    fi

    # Must have References
    if grep -qi "^## References" "$adr"; then
      pass "$label has References"
    else
      fail "$label must have References section"
    fi
  done

  # ADR-0007 specifics
  if grep -qi "defer.*dynamic.*model.*routing\|per-step.*model.*override.*deferred" "$adr7"; then
    pass "ADR-0007 states dynamic model routing is deferred"
  else
    fail "ADR-0007 must state dynamic model routing is deferred"
  fi

  if grep -qi "model profile\|profile.json\|Budget" "$adr7"; then
    pass "ADR-0007 references model profiles"
  else
    fail "ADR-0007 must reference model profiles"
  fi

  if grep -qi "role-based.*routing\|pippy-plan.*pippy-build\|pippy-build.*pippy-plan" "$adr7"; then
    pass "ADR-0007 references role-based subagent routing"
  else
    fail "ADR-0007 must reference role-based subagent routing"
  fi

  # ADR-0008 specifics
  if grep -qi "reject\|do not add\|not add" "$adr8"; then
    pass "ADR-0008 rejects the command"
  else
    fail "ADR-0008 must reject the /improve-pippy command"
  fi

  if grep -qi "human-reviewed\|human.reviewed" "$adr8"; then
    pass "ADR-0008 references human-reviewed improvement"
  else
    fail "ADR-0008 must reference human-reviewed improvement"
  fi

  if grep -qi "Improvement Signal" "$adr8"; then
    pass "ADR-0008 references Improvement Signal"
  else
    fail "ADR-0008 must reference Improvement Signal"
  fi

  # ADR-0009 specifics
  if grep -qi "config-only Pippy harness improvements\|config-only.*harness" "$adr9"; then
    pass "ADR-0009 keeps adaptation config-only"
  else
    fail "ADR-0009 must keep adaptation config-only"
  fi

  for term in "Pippy harness" "Goal-run eval suite" "Verification rigor" "Review checklist" "Run evidence" "Guardrail candidate"; do
    if grep -q "$term" "$adr9"; then
      pass "ADR-0009 references $term"
    else
      fail "ADR-0009 must reference $term"
    fi
  done

  if grep -qi "runtime telemetry\|raw traces" "$adr9" &&
     grep -qi "runtime evaluator\|model benchmark" "$adr9" &&
     grep -qi "OpenCode hook infrastructure\|runtime hooks" "$adr9" &&
     grep -qi "mode flag" "$adr9"; then
    pass "ADR-0009 records rejected runtime alternatives"
  else
    fail "ADR-0009 must record rejected runtime alternatives"
  fi

  if [[ -f "$adr14" ]] &&
     grep -q "Status: accepted" "$adr14" &&
     grep -q "Role usage accounting" "$adr14" &&
     grep -q "Green-gate PR creation" "$adr14" &&
     grep -q "OpenCode-recorded session usage is authoritative" "$adr14" &&
     grep -q "Coordinator (\`pippy\`)" "$adr14" &&
     grep -q "Planning (\`pippy-plan\`)" "$adr14" &&
     grep -q "Implementation (\`pippy-build\`)" "$adr14" &&
     grep -q "clean-tree, branch-safety, GitHub-readiness, and existing-PR gates" "$adr14" &&
     grep -q "\`Shipped\`" "$adr14" &&
     grep -q "\`Ready, PR blocked\`" "$adr14" &&
     grep -q "config/commands/budget.md" "$adr14" &&
     grep -q "config/commands/ship.md" "$adr14" &&
     grep -q "CONTEXT.md" "$adr14"; then
    pass "ADR-0014 records precise budget accounting and green-gate PR creation"
  else
    fail "ADR-0014 must record /budget and /ship behavior changes with command/glossary references"
  fi
}

test_model_profile_metadata() {
  run_test "#34-40 model profile metadata"

  local budget="$REPO_ROOT/config/model-profiles/budget.json"
  local thorough="$REPO_ROOT/config/model-profiles/thorough.json"
  if [[ -f "$budget" && -f "$thorough" ]]; then
    pass "budget.json and thorough.json exist"
    if grep -q '"coordination": "opencode-go/deepseek-v4-flash"' "$budget" &&
       grep -q '"planning": "opencode-go/kimi-k2.7-code"' "$budget" &&
       grep -q '"implementation": "opencode-go/mimo-v2.5"' "$budget" &&
       grep -q '"system": "opencode-go/deepseek-v4-flash"' "$budget" &&
       grep -q '"coordination": "opencode-go/kimi-k2.7-code"' "$thorough"; then
      pass "Budget and Thorough profiles match current defaults"
    else
      fail "Budget/Thorough profiles must define coordination, planning, implementation, and system models"
    fi
  else
    fail "budget.json or thorough.json missing"
  fi

  local installer="$REPO_ROOT/install.sh"
  if [[ ! -f "$REPO_ROOT/config/commands/advice.md" ]] &&
     ! grep -q 'config/commands/advice.md:.*commands/advice.md' "$installer" &&
     ! grep -q 'detect_advisors\|Advisor adapters' "$installer" &&
     grep -q 'commands/advice.md' "$installer" &&
     grep -q 'advisors.json' "$installer"; then
    pass "advisor command and installer metadata are removed"
  else
    fail "advisor command and metadata generation must be removed while stale installed files are cleaned up"
  fi

  # install.sh writes profile.json to generalpippy/.
  if grep -q 'profile.json' "$installer"; then
    pass "install.sh writes profile.json"
  else
    fail "install.sh must write profile.json to generalpippy/"
  fi

  if grep -q "read_required_model" "$installer" &&
     grep -q "Coordination model" "$installer" &&
     grep -q "not provider-verified" "$installer"; then
    pass "install.sh rejects blank Custom models"
  else
    fail "install.sh must reject blank Custom models for all roles"
  fi

  local readme="$REPO_ROOT/README.md"
  local budget="$REPO_ROOT/config/commands/budget.md"
  if grep -q "passes them through to OpenCode without provider verification" "$readme" &&
     grep -q "selected model profile and role-based model routing" "$budget"; then
    pass "docs cover Custom pass-through and profile-aware budget"
  else
    fail "docs must cover Custom pass-through and profile-aware budget"
  fi
}

test_pippy_update_system() {
  run_test "Pippy update system is documented, installed, and consent-based"

  local manifest="$REPO_ROOT/manifest.json"
  local helper="$REPO_ROOT/config/generalpippy/update-check.mjs"
  local plugin="$REPO_ROOT/config/plugins/generalpippy-update-check.js"
  local command="$REPO_ROOT/config/commands/pippy-update.md"
  local installer="$REPO_ROOT/install.sh"
  local readme="$REPO_ROOT/README.md"
  local context="$REPO_ROOT/CONTEXT.md"
  local adr="$REPO_ROOT/docs/adr/0015-pippy-update-check-and-release-manifest.md"
  local doctor="$REPO_ROOT/scripts/doctor.sh"

  if python3 - "$manifest" <<'PY'
import json, sys
with open(sys.argv[1]) as f:
    data = json.load(f)
stable = data.get("stable") or {}
assert data.get("schema_version") == 1
assert stable.get("version")
assert stable.get("minimum_opencode_version")
assert stable.get("install_url", "").endswith("/install.sh")
assert "release_url" in stable
PY
  then
    pass "manifest.json has stable channel, installer URL, and compatibility metadata"
  else
    fail "manifest.json must define stable version, install_url, release_url, and minimum_opencode_version"
  fi

  if grep -q "checkForUpdate" "$helper" &&
     grep -q "GENERALPIPPY_UPDATE_CHECK" "$helper" &&
     grep -q "update_channel" "$helper" &&
     grep -q "dismissed_versions" "$helper" &&
     grep -q "minimum_opencode_version" "$helper" &&
     grep -q "Run installer now" "$helper"; then
    pass "shared helper owns opt-out, channel, skip, compatibility, and consent behavior"
  else
    fail "shared update helper must own update logic and explicit installer consent"
  fi

  if grep -q "../generalpippy/update-check.mjs" "$plugin" &&
     grep -q "server.connected" "$plugin" &&
     grep -q "session.created" "$plugin" &&
     grep -q "/pippy-update" "$plugin"; then
    pass "startup plugin calls shared helper and points to /pippy-update"
  else
    fail "startup plugin must call shared helper at startup and point users to /pippy-update"
  fi

  if grep -q "update-check.mjs" "$command" &&
     grep -q -- "--force --interactive" "$command" &&
     grep -qi "Never update silently" "$command"; then
    pass "/pippy-update command uses shared helper and requires consent"
  else
    fail "/pippy-update must use shared helper with force/interactive behavior and no silent updates"
  fi

  if grep -q "config/commands/pippy-update.md" "$installer" &&
     grep -q "config/plugins/generalpippy-update-check.js" "$installer" &&
     grep -q "config/generalpippy/update-check.mjs" "$installer" &&
     grep -q "manifest.json" "$installer" &&
     grep -q "write_version_metadata" "$installer" &&
     grep -q -- "--profile budget" "$installer" &&
     grep -q "load_saved_profile" "$installer"; then
    pass "installer copies update system, writes version metadata, and preserves saved profile"
  else
    fail "installer must copy update files, write version metadata, support --profile budget, and preserve saved profile"
  fi

  if grep -q "curl -fsSL https://raw.githubusercontent.com/ChindanaiNaKub/generalPippy/main/install.sh | bash" "$readme" &&
     grep -q "/pippy-update" "$readme" &&
     grep -q "GENERALPIPPY_UPDATE_CHECK=0" "$readme"; then
    pass "README documents one-command install, manual update, and opt-out"
  else
    fail "README must document one-command install, /pippy-update, and update-check opt-out"
  fi

  if grep -q "Pippy update check" "$context" &&
     grep -q "GeneralPippy-owned installed file" "$context" &&
     grep -q "/pippy-update" "$context"; then
    pass "CONTEXT.md defines update terms and command surface"
  else
    fail "CONTEXT.md must define update terms and include /pippy-update command"
  fi

  if [[ -f "$adr" ]] &&
     grep -q "Status: accepted" "$adr" &&
     grep -q "manifest.json" "$adr" &&
     grep -q "minimum_opencode_version" "$adr" &&
     grep -q "install.sh remains the only updater" "$adr" &&
     grep -q "stable release channel by default" "$adr" &&
     grep -q "share one update-check helper" "$adr"; then
    pass "ADR-0015 records release manifest and update-check boundaries"
  else
    fail "ADR-0015 must record manifest, compatibility, installer ownership, channel, and shared helper decisions"
  fi

  if grep -q "Pippy update system" "$doctor" &&
     grep -q "version.json" "$doctor" &&
     grep -q "update check disabled" "$doctor"; then
    pass "doctor reports update system and disabled state"
  else
    fail "doctor must report update system, version metadata, and disabled state"
  fi
}

main() {
  echo "Running GeneralPippy validation tests..."

  test_required_files_exist
  test_opencode_jsonc_valid
  test_no_stale_v1_references
  test_markdown_frontmatter
  test_budget_command_is_role_usage_accounting
  test_subagent_routing_config
  test_opencode_reference_pack
  test_opencode_default_tools
  test_caveman_mode_not_cli_only
  test_external_deps_are_pinned
  test_cc_safety_net_pinned
  test_pippy_build_bash_permissions
  test_goal_output_format
  test_cross_run_memory
  test_goal_rtk_force
  test_goal_verifier_templates
  test_verify_is_part_of_goal
  test_assumption_audit_review_gate
  test_ship_guidance
  test_doctor_script
  test_acceptance_criteria_are_verifiable
  test_goal_readiness_and_grill_to_goal
  test_plan_steps_ordered_scoped
  test_outcome_must_be_done_blocked_partial
  test_final_verification_gate_required
  test_ship_budget_efficiency_smoke_test
  test_adr_bump_process
  test_context_assembly
  test_program_design_sketch_routing
  test_corrective_redelegation
  test_review_routing
  test_deferred_dispatch
  test_improvement_loop_doc
  test_external_trigger_recipe
  test_improvement_signal_smoke
  test_goal_run_evals_doc
  test_pippy_harness_doc
  test_decision_records
  test_model_profile_metadata
  test_pippy_update_system

  echo ""
  echo "========================="
  echo "Passed: $PASSED"
  echo "Failed: $FAILED"
  echo "========================="

  [[ $FAILED -eq 0 ]]
}

main "$@"

#!/bin/bash
# Run or preview the highest-signal goal-run smoke evals.
#
# Default mode is dry-run so validation and contributors can inspect the live
# OpenCode commands without spending model budget or modifying installed config.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

MODE="dry-run"
KEEP_WORKTREES=0
INSTALL_FIRST=1
EVALS=()

declare -A EVAL_NAMES=(
  [10]="Verifier Quality"
  [11]="Verifier Template Selection"
)

declare -A EVAL_PROMPTS=(
  [10]="make a harmless documentation change, then report Done only if the diff proves the exact requested behavior changed and no unrelated files changed"
  [11]="make a harmless docs-only wording change, then report which verifier template was used and why its evidence was sufficient"
)

usage() {
  cat <<'USAGE'
Usage: scripts/goal-run-smoke-evals.sh [--dry-run|--live] [--eval 10|--eval 11] [--skip-install] [--keep-worktrees]

Options:
  --dry-run          Print the Eval 10/11 live commands without running OpenCode (default).
  --live             Install this checkout, run selected evals in temp worktrees, and smoke-check reports.
  --eval N           Select an eval to run or print. Can be repeated. Supported: 10, 11.
  --skip-install     In --live mode, use the currently installed GeneralPippy config.
  --keep-worktrees   In --live mode, keep temp worktrees and logs for inspection.
  -h, --help         Show this help.
USAGE
}

die() {
  echo "❌ $*" >&2
  exit 1
}

ok() {
  echo "✅ $*"
}

rtk_cmd=()
if command -v rtk >/dev/null 2>&1; then
  rtk_cmd=(rtk)
fi

run_wrapped() {
  "${rtk_cmd[@]}" "$@"
}

strip_ansi() {
  perl -pe 's/\e\[[0-9;?]*[ -\/]*[@-~]//g'
}

add_eval() {
  local eval_id="$1"
  if [[ -z "${EVAL_NAMES[$eval_id]:-}" ]]; then
    die "unsupported eval: $eval_id"
  fi
  EVALS+=("$eval_id")
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --dry-run)
      MODE="dry-run"
      shift
      ;;
    --live)
      MODE="live"
      shift
      ;;
    --eval)
      [[ $# -ge 2 ]] || die "--eval requires a number"
      add_eval "$2"
      shift 2
      ;;
    --skip-install)
      INSTALL_FIRST=0
      shift
      ;;
    --keep-worktrees)
      KEEP_WORKTREES=1
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      die "unknown option: $1"
      ;;
  esac
done

if [[ ${#EVALS[@]} -eq 0 ]]; then
  EVALS=(10 11)
fi

print_dry_run() {
  echo "Goal-run smoke evals (dry-run)"
  echo ""
  echo "Run live with:"
  echo "  scripts/goal-run-smoke-evals.sh --live"
  echo ""
  for eval_id in "${EVALS[@]}"; do
    echo "Eval $eval_id: ${EVAL_NAMES[$eval_id]}"
    echo "  /goal \"${EVAL_PROMPTS[$eval_id]}\""
  done
}

assert_contains() {
  local file="$1"
  local pattern="$2"
  local message="$3"
  if grep -Eqi "$pattern" "$file"; then
    ok "$message"
  else
    die "$message not found"
  fi
}

write_report_slice() {
  local clean_log="$1"
  local report_log="$2"

  if grep -Eqi '^##[[:space:]]+REPORT[[:space:]]*$' "$clean_log"; then
    awk '
      BEGIN { in_report = 0 }
      /^##[[:space:]]+REPORT[[:space:]]*$/ { in_report = 1 }
      in_report { print }
    ' "$clean_log" >"$report_log"
  else
    cp "$clean_log" "$report_log"
  fi
}

assert_report_shape() {
  local report_log="$1"

  assert_contains "$report_log" "Acceptance Criteria" "report includes Acceptance Criteria"
  assert_contains "$report_log" "Plan" "report includes Plan"
  assert_contains "$report_log" "Improvement Signal" "report includes Improvement Signal"
  assert_contains "$report_log" "Outcome" "report includes Outcome"

  local numbered_sections
  numbered_sections="$(grep -Ec '^#{2,4}[[:space:]]+[1-9]\.' "$report_log" || true)"
  if [[ "$numbered_sections" -gt 4 ]]; then
    die "report has more than four numbered sections"
  fi
}

assert_eval_output() {
  local eval_id="$1"
  local clean_log="$2"
  local report_log
  report_log="$(mktemp -t "generalPippy-eval${eval_id}-report.XXXXXX")"
  write_report_slice "$clean_log" "$report_log"

  assert_report_shape "$report_log"

  case "$eval_id" in
    10)
      assert_contains "$clean_log" "Verification gates" "Eval 10 reports Verification gates"
      assert_contains "$clean_log" "exact|diff" "Eval 10 cites exact diff evidence"
      assert_contains "$clean_log" "unrelated" "Eval 10 checks unrelated changes"
      ;;
    11)
      assert_contains "$clean_log" "Verifier template|Verifier Template" "Eval 11 reports Verifier template"
      assert_contains "$clean_log" "Docs-only" "Eval 11 selects Docs-only"
      if grep -Eqi '^#{2,4}[[:space:]]+[1-9]\..*Verifier template|^#{2,4}[[:space:]]+[1-9]\..*Verifier Template' "$report_log"; then
        rm -f "$report_log"
        die "Eval 11 put verifier-template rationale in a separate numbered report section"
      fi
      ;;
  esac

  rm -f "$report_log"
}

run_live_eval() {
  local eval_id="$1"
  local worktree
  worktree="$(mktemp -d -t "generalPippy-eval${eval_id}.XXXXXX")"
  local raw_log="$worktree/eval-${eval_id}.raw.log"
  local clean_log="$worktree/eval-${eval_id}.log"

  echo ""
  echo "▶ Eval $eval_id: ${EVAL_NAMES[$eval_id]}"
  echo "  worktree: $worktree"

  run_wrapped git worktree add --detach "$worktree" HEAD >/dev/null

  set +e
  run_wrapped opencode run --dir "$worktree" --command goal "${EVAL_PROMPTS[$eval_id]}" >"$raw_log" 2>&1
  local status=$?
  set -e

  strip_ansi <"$raw_log" >"$clean_log"

  if [[ $status -ne 0 ]]; then
    echo "Log: $clean_log" >&2
    die "Eval $eval_id opencode run failed with exit $status"
  fi

  assert_eval_output "$eval_id" "$clean_log"
  ok "Eval $eval_id smoke checks passed"

  if [[ "$KEEP_WORKTREES" -eq 0 ]]; then
    run_wrapped git worktree remove --force "$worktree" >/dev/null
  else
    echo "Kept worktree and logs: $worktree"
  fi
}

run_live() {
  command -v opencode >/dev/null 2>&1 || die "opencode is required for --live"

  cd "$REPO_ROOT"

  if [[ "$INSTALL_FIRST" -eq 1 ]]; then
    echo "▶ Installing current checkout before live evals"
    run_wrapped ./install.sh
  else
    echo "▶ Skipping install; using currently installed GeneralPippy config"
  fi

  for eval_id in "${EVALS[@]}"; do
    run_live_eval "$eval_id"
  done
}

case "$MODE" in
  dry-run)
    print_dry_run
    ;;
  live)
    run_live
    ;;
esac

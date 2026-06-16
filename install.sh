#!/bin/bash
# GeneralPippy v2.2 — Self-Driving Goal Agent for OpenCode
# Install script: copies config files to ~/.config/opencode/

set -euo pipefail

VERSION="2.2.0"
DRY_RUN=0

# XDG Base Directory support: https://specifications.freedesktop.org/basedir-spec/basedir-spec-latest.html
CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
OPENCODE_CONFIG="$CONFIG_HOME/opencode"

# Files copied by this installer. Order matters for rollback: backups first, then targets.
declare -a COPY_TARGETS=(
  "config/opencode.jsonc:$OPENCODE_CONFIG/opencode.jsonc"
  "config/agents/pippy.md:$OPENCODE_CONFIG/agents/pippy.md"
  "config/agents/pippy-plan.md:$OPENCODE_CONFIG/agents/pippy-plan.md"
  "config/agents/pippy-build.md:$OPENCODE_CONFIG/agents/pippy-build.md"
  "config/commands/goal.md:$OPENCODE_CONFIG/commands/goal.md"
  "config/commands/ship.md:$OPENCODE_CONFIG/commands/ship.md"
  "config/commands/budget.md:$OPENCODE_CONFIG/commands/budget.md"
  "config/skills/pippy/SKILL.md:$OPENCODE_CONFIG/skills/pippy/SKILL.md"
  "config/skills/verify/SKILL.md:$OPENCODE_CONFIG/skills/verify/SKILL.md"
)

# v1.0 files to remove
declare -a OBSOLETE_FILES=(
  "$OPENCODE_CONFIG/agents/orchestrator.md"
  "$OPENCODE_CONFIG/agents/orchestrator-plan.md"
  "$OPENCODE_CONFIG/agents/orchestrator-build.md"
  "$OPENCODE_CONFIG/commands/think.md"
  "$OPENCODE_CONFIG/commands/verify.md"
  "$OPENCODE_CONFIG/commands/cheap.md"
  "$OPENCODE_CONFIG/commands/smart.md"
  "$OPENCODE_CONFIG/skills/orchestrate"
)

# Tracks files we backed up so we can restore on failure: target:backup_path
declare -a BACKUPS=()

usage() {
  cat <<EOF
Usage: $0 [OPTIONS]

Install GeneralPippy configuration for OpenCode.

Options:
  -h, --help      Show this help message
  -v, --version   Show version
  -n, --dry-run   Show what would be done without making changes

Examples:
  $0
  $0 --dry-run
EOF
}

version() {
  echo "GeneralPippy installer v$VERSION"
}

log() {
  echo "$@" >&2
}

error() {
  log "❌ $*"
  exit 1
}

warn() {
  log "⚠️  $*"
}

info() {
  log "ℹ️  $*"
}

success() {
  log "✅ $*"
}

parse_args() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      -h|--help)
        usage
        exit 0
        ;;
      -v|--version)
        version
        exit 0
        ;;
      -n|--dry-run)
        DRY_RUN=1
        shift
        ;;
      *)
        error "Unknown option: $1"
        ;;
    esac
  done
}

check_dependency() {
  local name="$1"
  local cmd="$2"

  if ! command -v "$cmd" &> /dev/null; then
    error "$name is not installed.\n   Install it from the project README."
  fi
  success "$name found"
}

require_source_files() {
  local missing=0
  local pair
  local src

  for pair in "${COPY_TARGETS[@]}"; do
    src="${pair%%:*}"
    if [[ ! -f "$src" ]]; then
      warn "Missing source file: $src"
      missing=1
    fi
  done

  if [[ $missing -eq 1 ]]; then
    error "One or more source files are missing. The repo may be incomplete."
  fi
}

backup_existing() {
  local target="$1"

  if [[ ! -e "$target" ]]; then
    return 0
  fi

  local backup_path
  backup_path="${target}.backup.$(date +%Y%m%d%H%M%S%N)"
  if [[ $DRY_RUN -eq 1 ]]; then
    info "Would back up $target -> $backup_path"
    return 0
  fi

  cp -a "$target" "$backup_path"
  BACKUPS+=("$target:$backup_path")
  log "💾 Backed up $target -> $backup_path"
}

rollback() {
  [[ ${#BACKUPS[@]} -eq 0 ]] && return 0
  warn "Installation failed. Rolling back ${#BACKUPS[@]} backup(s)..."
  local pair
  local target
  local backup
  for pair in "${BACKUPS[@]}"; do
    target="${pair%%:*}"
    backup="${pair##*:}"
    if [[ -e "$backup" ]]; then
      rm -rf "$target"
      cp -a "$backup" "$target"
      log "  Restored $target from $backup"
    fi
  done
}

cleanup_obsolete() {
  local path
  for path in "${OBSOLETE_FILES[@]}"; do
    if [[ -e "$path" ]]; then
      if [[ $DRY_RUN -eq 1 ]]; then
        info "Would remove obsolete: $path"
      else
        rm -rf "$path"
        log "🗑️  Removed obsolete: $path"
      fi
    fi
  done
}

copy_files() {
  local pair
  local src
  local dst
  local dst_dir

  for pair in "${COPY_TARGETS[@]}"; do
    src="${pair%%:*}"
    dst="${pair##*:}"
    dst_dir="$(dirname "$dst")"

    if [[ $DRY_RUN -eq 1 ]]; then
      info "Would copy $src -> $dst"
      continue
    fi

    mkdir -p "$dst_dir"
    backup_existing "$dst"
    cp -a "$src" "$dst"
    log "📝 Copied $src -> $dst"
  done
}

install_plugins() {
  local package_json="$OPENCODE_CONFIG/package.json"

  if [[ ! -f "$package_json" ]]; then
    info "No package.json found in $OPENCODE_CONFIG; skipping plugin install."
    return 0
  fi

  if [[ $DRY_RUN -eq 1 ]]; then
    info "Would run: npm install --prefix $OPENCODE_CONFIG"
    return 0
  fi

  log "📦 Installing plugins..."
  # Capture output to a log but still surface it on failure.
  local npm_log
  npm_log="$(mktemp)"
  if (cd "$OPENCODE_CONFIG" && npm install >"$npm_log" 2>&1); then
    success "Plugins installed"
  else
    warn "npm install failed. See $npm_log for details."
    warn "Plugins may need manual installation."
  fi
}

prompt_yes_no() {
  local prompt="$1"
  local reply
  read -r -p "$prompt" reply
  [[ "$reply" =~ ^[Yy](es)?$ ]]
}

install_rtk() {
  curl -fsSL https://raw.githubusercontent.com/rtk-ai/rtk/refs/heads/master/install.sh | sh \
    && rtk init -g --opencode
}

install_optional() {
  local name="$1"
  local check_cmd="$2"
  local install_fn="$3"

  if command -v "$check_cmd" &> /dev/null; then
    success "$name found"
    return 0
  fi

  warn "$name not found."
  if [[ $DRY_RUN -eq 1 ]]; then
    info "Would prompt to install $name"
    return 0
  fi

  if prompt_yes_no "   Install $name? (y/N) "; then
    log "   Installing $name..."
    if "$install_fn"; then
      success "$name installed"
    else
      warn "Failed to install $name — Pippy will degrade gracefully"
    fi
  else
    info "Skipping $name — Pippy will degrade gracefully"
  fi
}

report_caveman_mode() {
  local config_home="${XDG_CONFIG_HOME:-$HOME/.config}"
  local opencode_config="$config_home/opencode"
  local command_file="$opencode_config/commands/caveman.md"
  local agents_file="$opencode_config/AGENTS.md"

  if [[ -f "$command_file" ]] || { [[ -f "$agents_file" ]] && grep -q "caveman-begin" "$agents_file"; }; then
    success "Caveman mode found"
    return 0
  fi

  warn "Caveman mode not found."
  info "Caveman mode is optional OpenCode config, not required shell CLI."
  info "Install or copy a /caveman OpenCode command if you want automatic terse output."
}

report_optional_manual() {
  local name="$1"
  local check_cmd="$2"
  local install_url="$3"

  if command -v "$check_cmd" &> /dev/null; then
    success "$name found"
    return 0
  fi

  warn "$name not found."
  info "$name is optional. Install it separately if you want that integration:"
  info "  $install_url"
}

main() {
  parse_args "$@"

  log "🐱 GeneralPippy v$VERSION — Installing Self-Driving Goal Agent..."
  log ""

  # Trap rollback on any error, but only in real mode.
  if [[ $DRY_RUN -eq 0 ]]; then
    trap rollback ERR
  fi

  log "🔍 Checking core dependencies..."
  check_dependency "opencode" "opencode"
  check_dependency "uv" "uv"
  check_dependency "npm" "npm"
  log ""

  log "📁 Preparing directories..."
  if [[ $DRY_RUN -eq 1 ]]; then
    info "Would create: $OPENCODE_CONFIG/{agents,commands,skills/pippy,skills/verify}"
  else
    mkdir -p "$OPENCODE_CONFIG/agents" \
             "$OPENCODE_CONFIG/commands" \
             "$OPENCODE_CONFIG/skills/pippy" \
             "$OPENCODE_CONFIG/skills/verify"
  fi
  log ""

  log "🔍 Validating source files..."
  require_source_files
  log ""

  log "📝 Copying config files..."
  copy_files
  success "Files copied"
  log ""

  log "🧹 Cleaning up obsolete v1.0 files..."
  cleanup_obsolete
  log ""

  log "🔍 Checking optional dependencies..."
  install_optional "rtk" "rtk" install_rtk
  report_caveman_mode
  report_optional_manual "Caveman CLI" "caveman" "https://github.com/JuliusBrussee/caveman"
  log ""

  info "ponytail is optional but cannot be auto-installed."
  info "To use it, clone https://github.com/DietrichGebert/ponytail and add"
  info "its .opencode/plugins/ponytail.mjs path to your opencode.jsonc plugins."
  log ""

  install_plugins

  log ""
  log "🎉 GeneralPippy v$VERSION installed successfully!"
  log ""
  log "Next steps:"
  log "  1. Run 'opencode' to start"
  log "  2. Pippy is now your default agent"
  log "  3. Use /goal \"<objective>\" to start a self-driving task"
  log "  4. Use /ship to prepare for PR"
  log "  5. Use OpenCode's usage display for exact tokens/cost, and /budget for routing guidance"
  log ""
  log "Models configured:"
  log "  • Planning: opencode-go/kimi-k2.7-code (strong)"
  log "  • Implementation: opencode-go/mimo-v2.5 (cheap)"
  log "  • System tasks: opencode-go/deepseek-v4-flash (cheapest)"
  log ""
  log "Plugins configured:"
  log "  • jcodemunch-mcp — AST code indexing"
  log "  • opencode-dcp — Dynamic context pruning"
  log ""
  log "Optional tools (install for best experience):"
  log "  • rtk — Token-efficient bash wrapper"
  log "  • Caveman mode — Terse OpenCode responses and compressed build output"
  log "  • Caveman CLI — Optional shell executable for extra compression workflows"
  log "  • ponytail — Lazy senior-dev planning constraint (manual install)"
  log ""
  log "For more info: https://github.com/ChindanaiNaKub/generalPippy"

  # Success: keep backups as restore points, but disable the rollback trap.
  trap - ERR
}

main "$@"

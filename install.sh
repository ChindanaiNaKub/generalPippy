#!/bin/bash
# GeneralPippy v2.4 — Self-Driving Goal Agent for OpenCode
# Install script: copies config files to ~/.config/opencode/

set -euo pipefail

VERSION="2.4.0"
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
  "$OPENCODE_CONFIG/skills/verify"
)

# Tracks files we backed up so we can restore on failure: target:backup_path
declare -a BACKUPS=()

# Tracks paths we created during this install run (for rollback on failure).
# Format: "path:type" where type is "file" or "dir"
declare -a CREATED_PATHS=()

# GeneralPippy's pinned plugin list. User plugins are merged on top.
PINNED_PLUGINS=(
  "@tarquinen/opencode-dcp@0.0.4"
)

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
  local exit_code=$?
  [[ $exit_code -eq 0 ]] && return 0

  warn "Installation failed (exit code $exit_code). Rolling back..."

  # Restore backed-up files first.
  if [[ ${#BACKUPS[@]} -gt 0 ]]; then
    warn "Restoring ${#BACKUPS[@]} backup(s)..."
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
  fi

  # Remove any files/dirs we created during this run (newest first for dirs).
  if [[ ${#CREATED_PATHS[@]} -gt 0 ]]; then
    warn "Removing ${#CREATED_PATHS[@]} newly-created path(s)..."
    local entry
    local cpath
    local ctype
    # Remove files before directories (reverse order handles nesting).
    local i
    for (( i=${#CREATED_PATHS[@]}-1; i>=0; i-- )); do
      entry="${CREATED_PATHS[$i]}"
      cpath="${entry%%:*}"
      ctype="${entry##*:}"
      if [[ -e "$cpath" ]]; then
        rm -rf "$cpath"
        log "  Removed $ctype: $cpath"
      fi
    done
  fi
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

merge_plugins() {
  # Merge user's existing plugins with GeneralPippy's pinned list.
  # Writes a new opencode.jsonc to the target path.
  local dst="$1"

  # Copy the pinned config as base.
  cp -a "config/opencode.jsonc" "$dst"

  # Find the most recent backup to extract user plugins.
  local latest_backup=""
  for f in "${dst}".backup.*; do
    if [[ -f "$f" ]]; then
      latest_backup="$f"
      break
    fi
  done

  if [[ -z "$latest_backup" ]]; then
    info "No existing plugins to merge (no backup found)."
    return 0
  fi

  # Extract user plugin strings from the backup file (bash-only, no python3 needed).
  local user_plugins=()
  local in_plugin_array=0
  local line
  while IFS= read -r line; do
    if [[ "$line" =~ \"plugin\"[[:space:]]*: ]]; then
      in_plugin_array=1
      continue
    fi
    if [[ $in_plugin_array -eq 1 ]]; then
      # Extract quoted string from the line.
      if [[ "$line" =~ \[ ]]; then continue; fi  # Skip opening bracket
      if [[ "$line" =~ \] ]]; then break; fi      # End of array
      local plugin
      plugin="$(echo "$line" | sed -E 's/^[[:space:]]*"([^"]*)".*/\1/' | sed -E "s/^[[:space:]]*'([^']*)'.*/\1/")"
      if [[ -n "$plugin" ]]; then
        user_plugins+=("$plugin")
      fi
    fi
  done < "$latest_backup"

  if [[ ${#user_plugins[@]} -eq 0 ]]; then
    info "No user plugins found in backup."
    return 0
  fi

  # Build merged list: pinned first, then user plugins not already present.
  local merged=()
  local seen=()
  local p
  for p in "${PINNED_PLUGINS[@]}" "${user_plugins[@]}"; do
    local already=0
    local s
    for s in "${seen[@]+"${seen[@]}"}"; do
      if [[ "$s" == "$p" ]]; then
        already=1
        break
      fi
    done
    if [[ $already -eq 0 ]]; then
      merged+=("$p")
      seen+=("$p")
    fi
  done

  # If merged is identical to pinned, no user plugins were added.
  if [[ ${#merged[@]} -eq ${#PINNED_PLUGINS[@]} ]]; then
    info "No new user plugins to merge."
    return 0
  fi

  # Use python3 if available for reliable JSONC editing; otherwise use sed.
  if command -v python3 &> /dev/null; then
    python3 - "$dst" "$latest_backup" <<'PY'
import json, re, sys

target_path = sys.argv[1]
backup_path = sys.argv[2]

def extract_plugins(text):
    """Extract plugin strings from JSONC text."""
    text = re.sub(r'(?<!\S)//[^\n]*', '', text)
    text = re.sub(r'/\*.*?\*/', '', text, flags=re.DOTALL)
    try:
        data = json.loads(text)
        return data.get("plugin", [])
    except Exception:
        return []

with open(backup_path) as f:
    user_plugins = extract_plugins(f.read())

if not user_plugins:
    sys.exit(0)

with open(target_path) as f:
    target_text = f.read()

target_plugins = extract_plugins(target_text)

seen = set()
merged = []
for p in target_plugins:
    if p not in seen:
        seen.add(p)
        merged.append(p)
for p in user_plugins:
    if p not in seen:
        seen.add(p)
        merged.append(p)

if merged == target_plugins:
    sys.exit(0)

entries = ",\n".join(f'    "{p}"' for p in merged)
plugin_block = f'"plugin": [\n{entries}\n  ]'

new_text = re.sub(r'"plugin"\s*:\s*\[.*?\]', plugin_block, target_text, flags=re.DOTALL)

with open(target_path, 'w') as f:
    f.write(new_text)
PY
  else
    # Fallback: perl-based replacement for environments without python3.
    # Build the new plugin array with proper commas.
    local new_array='"plugin": [\n'
    local i
    for (( i=0; i<${#merged[@]}; i++ )); do
      if [[ $i -gt 0 ]]; then new_array+=","; fi
      new_array+=$'\n    "'"${merged[$i]}"'"'
    done
    new_array+=$'\n  ]'

    # Use perl for multiline replacement (more reliable than sed for this).
    if command -v perl &> /dev/null; then
      # Escape the replacement string for perl.
      local escaped
      escaped="$(printf '%s' "$new_array" | perl -e 'use File::Slurp; local $/; $_=<>; s/\\/\\\\/g; s/\//\\\//g; s/\$/\\\$/g; s/\n/\\n/g; print')"
      perl -i -0pe "s/\"plugin\"\\s*:\\s*\\[.*?\\]/$escaped/s" "$dst"
    else
      warn "Cannot merge plugins: need python3 or perl."
      cp -a "config/opencode.jsonc" "$dst"
      return 0
    fi
  fi

  log "🔀 Merged plugins: pinned + user additions"
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

    # Track whether we're creating the directory or it already existed.
    if [[ ! -d "$dst_dir" ]]; then
      mkdir -p "$dst_dir"
      CREATED_PATHS+=("$dst_dir:dir")
    else
      mkdir -p "$dst_dir"
    fi

    backup_existing "$dst"

    # Special handling for opencode.jsonc: merge user plugins with pinned list.
    if [[ "$src" == "config/opencode.jsonc" ]] && [[ -f "$dst" ]]; then
      merge_plugins "$dst"
    else
      cp -a "$src" "$dst"
    fi
    CREATED_PATHS+=("$dst:file")
    log "📝 Copied $src -> $dst"
  done
}

install_plugins() {
  local package_json="$OPENCODE_CONFIG/package.json"

  if [[ ! -f "$package_json" ]]; then
    info "No package.json found in $OPENCODE_CONFIG; skipping plugin install."
    return 0
  fi

  # Only check for npm when we actually need it (#24).
  if ! command -v npm &> /dev/null; then
    warn "npm not found. Plugins require npm for installation."
    warn "Install npm from https://nodejs.org/ to enable plugin support."
    warn "Plugins may need manual installation."
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
  # Pin rtk to a specific release for reproducible installs (#27).
  local rtk_version="1.78.0"
  local rtk_url="https://raw.githubusercontent.com/rtk-ai/rtk/refs/tags/v${rtk_version}/install.sh"

  info "Installing rtk v${rtk_version}..."
  if curl -fsSL "$rtk_url" | sh; then
    rtk init -g --opencode
  else
    warn "Failed to download rtk v${rtk_version} from $rtk_url"
    return 1
  fi
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
    trap 'rollback' ERR
  fi

  log "🔍 Checking core dependencies..."
  check_dependency "opencode" "opencode"
  check_dependency "uv" "uv"
  # npm is only required when plugin installation is needed (#24).
  # The check happens inside install_plugins when package.json is present.
  log ""

  log "📁 Preparing directories..."
  if [[ $DRY_RUN -eq 1 ]]; then
    info "Would create: $OPENCODE_CONFIG/{agents,commands,skills/pippy}"
  else
    local _dirs=(
      "$OPENCODE_CONFIG"
      "$OPENCODE_CONFIG/agents"
      "$OPENCODE_CONFIG/commands"
      "$OPENCODE_CONFIG/skills/pippy"
    )
    local _d
    for _d in "${_dirs[@]}"; do
      if [[ ! -d "$_d" ]]; then
        mkdir -p "$_d"
        CREATED_PATHS+=("$_d:dir")
      fi
    done
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

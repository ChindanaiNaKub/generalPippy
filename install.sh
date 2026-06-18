#!/bin/bash
# GeneralPippy v2.6.0 — Self-Driving Goal Agent for OpenCode
# Install script: copies config files to ~/.config/opencode/

set -euo pipefail

# Resolve repo root for sourcing shared utilities.
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/utils.sh
source "$REPO_ROOT/lib/utils.sh"

VERSION="2.6.0"
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
  "config/commands/grill-to-goal.md:$OPENCODE_CONFIG/commands/grill-to-goal.md"
  "config/skills/pippy/SKILL.md:$OPENCODE_CONFIG/skills/pippy/SKILL.md"
  "config/skills/grill-to-goal/SKILL.md:$OPENCODE_CONFIG/skills/grill-to-goal/SKILL.md"
  "config/references/opencode/REFERENCE.md:$OPENCODE_CONFIG/references/opencode/REFERENCE.md"
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
  "$OPENCODE_CONFIG/commands/advice.md"
  "$OPENCODE_CONFIG/skills/orchestrate"
  "$OPENCODE_CONFIG/skills/verify"
  "$OPENCODE_CONFIG/generalpippy/advisors.json"
)

# Tracks files we backed up so we can restore on failure: target:backup_path
declare -a BACKUPS=()

# Tracks paths we created during this install run (for rollback on failure).
# Format: "path:type" where type is "file" or "dir"
declare -a CREATED_PATHS=()

# GeneralPippy's pinned plugin list. User plugins are merged on top.
PINNED_PLUGINS=(
  "@tarquinen/opencode-dcp@0.0.4"
  "cc-safety-net@1.0.6"
)

# Default models for the Balanced profile.
BALANCED_PLANNING_MODEL="opencode-go/kimi-k2.7-code"
BALANCED_IMPLEMENTATION_MODEL="opencode-go/mimo-v2.5"
BALANCED_SYSTEM_MODEL="opencode-go/deepseek-v4-flash"

# Metadata directory under OPENCODE_CONFIG.
GENERALPIPPY_DIR="$OPENCODE_CONFIG/generalpippy"

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

plugin_identity() {
  local plugin="$1"

  if [[ "$plugin" =~ ^@[^/]+/[^/@]+@[^/]+$ ]] || [[ "$plugin" =~ ^[^/@]+@[^/]+$ ]]; then
    printf '%s\n' "${plugin%@*}"
  else
    printf '%s\n' "$plugin"
  fi
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

  # Build merged list: pinned first, then user plugins that do not conflict
  # with a pinned package identity. This lets pinned defaults replace stale
  # user entries like @latest without dropping unrelated custom plugins.
  local merged=()
  local seen_ids=()
  local p
  for p in "${PINNED_PLUGINS[@]}" "${user_plugins[@]}"; do
    local already=0
    local identity
    identity="$(plugin_identity "$p")"
    local s
    for s in "${seen_ids[@]+"${seen_ids[@]}"}"; do
      if [[ "$s" == "$identity" ]]; then
        already=1
        break
      fi
    done
    if [[ $already -eq 0 ]]; then
      merged+=("$p")
      seen_ids+=("$identity")
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

def plugin_identity(plugin):
    if re.match(r"^@[^/]+/[^/@]+@[^/]+$", plugin) or re.match(r"^[^/@]+@[^/]+$", plugin):
        return plugin.rsplit("@", 1)[0]
    return plugin

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
    identity = plugin_identity(p)
    if identity not in seen:
        seen.add(identity)
        merged.append(p)
for p in user_plugins:
    identity = plugin_identity(p)
    if identity not in seen:
        seen.add(identity)
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

read_required_model() {
  # Prompt for a Custom profile model value. Blank values are invalid for Custom.
  local prompt="$1"
  local dest_var="$2"
  local input=""

  while true; do
    input=""
    if ! read -r -p "  $prompt: " input; then
      warn "Model string cannot be empty."
      return 1
    fi
    if [[ -n "$input" ]]; then
      printf -v "$dest_var" '%s' "$input"
      return 0
    fi
    warn "Model string cannot be empty."
  done
}

choose_model_profile() {
  # Interactive model profile selection.
  # Sets SELECTED_PROFILE, SELECTED_PLANNING, SELECTED_IMPLEMENTATION, SELECTED_SYSTEM.
  SELECTED_PROFILE="Balanced"
  SELECTED_PLANNING="$BALANCED_PLANNING_MODEL"
  SELECTED_IMPLEMENTATION="$BALANCED_IMPLEMENTATION_MODEL"
  SELECTED_SYSTEM="$BALANCED_SYSTEM_MODEL"

  if [[ $DRY_RUN -eq 1 ]]; then
    info "Would prompt for model profile selection (default: Balanced)"
    return 0
  fi

  echo ""
  log "📋 Model Profiles"
  log ""
  log "  1) Balanced (default) — Current tested defaults"
  log "     Planning:     $BALANCED_PLANNING_MODEL"
  log "     Implementation: $BALANCED_IMPLEMENTATION_MODEL"
  log "     System tasks:   $BALANCED_SYSTEM_MODEL"
  log "  2) Custom — Enter your own models"
  log ""

  local choice=""
  read -r -p "  Select profile [1]: " choice || true
  choice="${choice:-1}"

  if [[ "$choice" == "2" ]]; then
    SELECTED_PROFILE="Custom"
    log ""
    log "  Enter exact OpenCode-compatible model strings (provider/model-id format)."
    warn "Custom model IDs are passed through to OpenCode and are not provider-verified by GeneralPippy."
    log ""

    read_required_model "Planning model" SELECTED_PLANNING
    read_required_model "Implementation model" SELECTED_IMPLEMENTATION
    read_required_model "System-tasks model" SELECTED_SYSTEM
  fi

  log ""
  success "Selected profile: $SELECTED_PROFILE"
  log "  Planning:       $SELECTED_PLANNING"
  log "  Implementation: $SELECTED_IMPLEMENTATION"
  log "  System tasks:   $SELECTED_SYSTEM"
}

patch_installed_models() {
  # Patch installed config files to use the selected model profile.
  local planning="$1"
  local implementation="$2"
  local system="$3"

  if [[ "$SELECTED_PROFILE" == "Balanced" ]]; then
    return 0  # No patching needed; source files already have Balanced defaults.
  fi

  if [[ $DRY_RUN -eq 1 ]]; then
    info "Would patch installed files with custom models:"
    info "  opencode.jsonc: model=$planning, small_model=$system"
    info "  agents/pippy.md: model=$planning"
    info "  agents/pippy-plan.md: model=$planning"
    info "  agents/pippy-build.md: model=$implementation"
    return 0
  fi

  if command -v python3 &> /dev/null; then
    python3 - "$OPENCODE_CONFIG" "$planning" "$implementation" "$system" <<'PY'
import re, sys

config_dir = sys.argv[1]
planning = sys.argv[2]
implementation = sys.argv[3]
system = sys.argv[4]

# Patch opencode.jsonc: replace model and small_model values.
jsonc_path = f"{config_dir}/opencode.jsonc"
with open(jsonc_path) as f:
    text = f.read()
text = re.sub(r'"model"\s*:\s*"[^"]*"', f'"model": "{planning}"', text)
text = re.sub(r'"small_model"\s*:\s*"[^"]*"', f'"small_model": "{system}"', text)
with open(jsonc_path, 'w') as f:
    f.write(text)

# Patch agent markdown files: replace model: frontmatter value.
agent_models = {
    f"{config_dir}/agents/pippy.md": planning,
    f"{config_dir}/agents/pippy-plan.md": planning,
    f"{config_dir}/agents/pippy-build.md": implementation,
}
for path, model in agent_models.items():
    with open(path) as f:
        text = f.read()
    text = re.sub(r'^model:\s*\S+', f'model: {model}', text, count=1, flags=re.MULTILINE)
    with open(path, 'w') as f:
        f.write(text)
PY
  elif command -v perl &> /dev/null; then
    # Fallback: perl-based replacement.
    perl -i -pe "s/^model:\s*\S+/model: $planning/ if \$. == 4" \
      "$OPENCODE_CONFIG/agents/pippy.md" \
      "$OPENCODE_CONFIG/agents/pippy-plan.md"
    perl -i -pe "s/^model:\s*\S+/model: $implementation/ if \$. == 4" \
      "$OPENCODE_CONFIG/agents/pippy-build.md"
    perl -i -pe "s/\"model\"\s*:\s*\"[^\"]*\"/\"model\": \"$planning\"/" \
      "$OPENCODE_CONFIG/opencode.jsonc"
    perl -i -pe "s/\"small_model\"\s*:\s*\"[^\"]*\"/\"small_model\": \"$system\"/" \
      "$OPENCODE_CONFIG/opencode.jsonc"
  else
    # Last resort: sed (less reliable for multiline).
    sed -i "s|^model: .*|model: $planning|" \
      "$OPENCODE_CONFIG/agents/pippy.md" \
      "$OPENCODE_CONFIG/agents/pippy-plan.md"
    sed -i "s|^model: .*|model: $implementation|" \
      "$OPENCODE_CONFIG/agents/pippy-build.md"
    sed -i "s|\"model\": \"[^\"]*\"|\"model\": \"$planning\"|" \
      "$OPENCODE_CONFIG/opencode.jsonc"
    sed -i "s|\"small_model\": \"[^\"]*\"|\"small_model\": \"$system\"|" \
      "$OPENCODE_CONFIG/opencode.jsonc"
  fi

  success "Patched installed files with custom models"
}

write_profile_metadata() {
  # Write profile metadata to generalpippy/profile.json.
  local profile="$1"
  local planning="$2"
  local implementation="$3"
  local system="$4"

  if [[ $DRY_RUN -eq 1 ]]; then
    info "Would write profile metadata to $GENERALPIPPY_DIR/profile.json"
    return 0
  fi

  mkdir -p "$GENERALPIPPY_DIR"
  write_profile_json "$profile" "$planning" "$implementation" "$system"
  success "Profile metadata written to $GENERALPIPPY_DIR/profile.json"
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
    info "Would create: $OPENCODE_CONFIG/{agents,commands,skills/pippy,skills/grill-to-goal,generalpippy}"
  else
    local _dirs=(
      "$OPENCODE_CONFIG"
      "$OPENCODE_CONFIG/agents"
      "$OPENCODE_CONFIG/commands"
      "$OPENCODE_CONFIG/skills/pippy"
      "$OPENCODE_CONFIG/skills/grill-to-goal"
      "$OPENCODE_CONFIG/references/opencode"
      "$GENERALPIPPY_DIR"
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

  log "📋 Selecting model profile..."
  choose_model_profile
  log ""

  log "🔍 Validating source files..."
  require_source_files
  log ""

  log "📝 Copying config files..."
  copy_files
  success "Files copied"
  log ""

  log "🔧 Patching installed files with selected models..."
  patch_installed_models "$SELECTED_PLANNING" "$SELECTED_IMPLEMENTATION" "$SELECTED_SYSTEM"
  log ""

  log "💾 Writing profile metadata..."
  write_profile_metadata "$SELECTED_PROFILE" "$SELECTED_PLANNING" "$SELECTED_IMPLEMENTATION" "$SELECTED_SYSTEM"
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
  log "Model profile: $SELECTED_PROFILE"
  log "  • Planning:       $SELECTED_PLANNING"
  log "  • Implementation: $SELECTED_IMPLEMENTATION"
  log "  • System tasks:   $SELECTED_SYSTEM"
  log ""
  log "Plugins configured:"
  log "  • jcodemunch-mcp — AST code indexing"
  log "  • opencode-dcp — Dynamic context pruning"
  log "  • cc-safety-net — Destructive-command guardrail plugin (default mode)"
  log "  • opencode-docs reference — Config, provider, reference, and troubleshooting guidance"
  log "OpenCode defaults:"
  log "  • formatter — Built-in formatters enabled"
  log "  • lsp — Built-in language servers enabled"
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

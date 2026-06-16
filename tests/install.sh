#!/bin/bash
# Test suite for GeneralPippy install.sh
# Plain bash — no external test framework required.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
INSTALLER="$REPO_ROOT/install.sh"

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
  local name="$1"
  echo ""
  echo "▶ $name"
}

test_help_flag() {
  run_test "--help shows usage and exits 0"
  local output
  if output="$($INSTALLER --help 2>&1)"; then
    pass "exits 0"
  else
    fail "did not exit 0"
  fi
  if [[ "$output" == *"Usage:"* ]]; then pass "contains Usage"; else fail "missing Usage"; fi
  if [[ "$output" == *"--help"* ]]; then pass "mentions --help"; else fail "missing --help"; fi
}

test_version_flag() {
  run_test "--version shows version and exits 0"
  local output
  if output="$($INSTALLER --version 2>&1)"; then
    pass "exits 0"
  else
    fail "did not exit 0"
  fi
  if [[ "$output" == *"GeneralPippy installer v"* ]]; then pass "shows version"; else fail "missing version"; fi
}

test_unknown_flag() {
  run_test "unknown flag exits non-zero"
  local output
  if output="$($INSTALLER --not-a-flag 2>&1)"; then
    fail "exited 0 unexpectedly"
  else
    pass "exits non-zero"
  fi
  if [[ "$output" == *"Unknown option"* ]]; then pass "reports unknown option"; else fail "missing error message"; fi
}

test_dry_run_does_not_modify() {
  run_test "--dry-run does not modify config directory"
  local tmp_home
  tmp_home="$(mktemp -d)"
  local tmp_bin
  tmp_bin="$(mktemp -d)"
  local config_dir="$tmp_home/.config/opencode"

  # Mock core dependencies so this test only checks dry-run file behavior.
  # CI runners do not necessarily have opencode installed.
  for cmd in opencode uv npm; do
    cat > "$tmp_bin/$cmd" <<EOF
#!/bin/bash
echo "fake $cmd"
EOF
    chmod +x "$tmp_bin/$cmd"
  done

  local min_path
  min_path="$(make_minimal_path "$tmp_bin")"

  HOME="$tmp_home" XDG_CONFIG_HOME="$tmp_home/.config" PATH="$min_path" "$INSTALLER" --dry-run >/dev/null 2>&1

  if [[ ! -e "$config_dir" ]]; then pass "config directory not created"; else fail "config directory was created"; fi
  rm -rf "$tmp_home" "$tmp_bin" "${min_path##*:}"
}

make_minimal_path() {
  local bin_dir="$1"
  local coreutils_dir
  coreutils_dir="$(mktemp -d)"
  local cmd
  for cmd in cp mv mkdir rm dirname cat date mktemp sort md5sum find echo chmod sleep tr; do
    if command -v "$cmd" &> /dev/null; then
      ln -s "$(command -v "$cmd")" "$coreutils_dir/$cmd"
    fi
  done
  echo "$bin_dir:$coreutils_dir"
}

test_missing_core_dependency() {
  run_test "missing core dependency exits non-zero"
  local tmp_bin
  tmp_bin="$(mktemp -d)"

  # Create fake opencode/uv but omit npm to trigger failure.
  cat > "$tmp_bin/opencode" <<'EOF'
#!/bin/bash
echo "fake opencode"
EOF
  chmod +x "$tmp_bin/opencode"

  cat > "$tmp_bin/uv" <<'EOF'
#!/bin/bash
echo "fake uv"
EOF
  chmod +x "$tmp_bin/uv"

  # Build a PATH that excludes the real npm but keeps coreutils accessible.
  local min_path
  min_path="$(make_minimal_path "$tmp_bin")"

  local output
  if output="$(PATH="$min_path" "$INSTALLER" --dry-run 2>&1)"; then
    fail "exited 0 unexpectedly"
  else
    pass "exits non-zero"
  fi
  if [[ "$output" == *"npm is not installed"* ]]; then pass "reports missing npm"; else fail "missing npm error"; fi

  rm -rf "$tmp_bin" "${min_path##*:}"
}

test_install_creates_files() {
  run_test "install creates expected files in config directory"
  local tmp_home
  tmp_home="$(mktemp -d)"
  local tmp_bin
  tmp_bin="$(mktemp -d)"
  local config_dir="$tmp_home/.config/opencode"

  # Mock all core deps so install can proceed without real opencode/uv/npm.
  for cmd in opencode uv npm; do
    cat > "$tmp_bin/$cmd" <<EOF
#!/bin/bash
echo "fake $cmd"
EOF
    chmod +x "$tmp_bin/$cmd"
  done

  # Run non-interactively; optional deps will be skipped because stdin is empty.
  local min_path
  min_path="$(make_minimal_path "$tmp_bin")"
  HOME="$tmp_home" XDG_CONFIG_HOME="$tmp_home/.config" PATH="$min_path" "$INSTALLER" </dev/null >/dev/null 2>&1

  for file in opencode.jsonc agents/pippy.md agents/pippy-plan.md agents/pippy-build.md \
              commands/goal.md commands/ship.md commands/budget.md \
              skills/pippy/SKILL.md skills/verify/SKILL.md; do
    if [[ -f "$config_dir/$file" ]]; then
      pass "created $file"
    else
      fail "missing $file"
    fi
  done

  rm -rf "$tmp_home" "$tmp_bin" "${min_path##*:}"
}

test_install_backs_up_existing_config() {
  run_test "install backs up existing config files"
  local tmp_home
  tmp_home="$(mktemp -d)"
  local tmp_bin
  tmp_bin="$(mktemp -d)"
  local config_dir="$tmp_home/.config/opencode"

  for cmd in opencode uv npm; do
    cat > "$tmp_bin/$cmd" <<EOF
#!/bin/bash
echo "fake $cmd"
EOF
    chmod +x "$tmp_bin/$cmd"
  done

  mkdir -p "$config_dir"
  echo "existing config" > "$config_dir/opencode.jsonc"

  local min_path
  min_path="$(make_minimal_path "$tmp_bin")"
  HOME="$tmp_home" XDG_CONFIG_HOME="$tmp_home/.config" PATH="$min_path" "$INSTALLER" </dev/null >/dev/null 2>&1

  local backups
  backups=("$config_dir"/opencode.jsonc.backup.*)
  if [[ -f "${backups[0]:-}" ]]; then
    pass "backup created: ${backups[0]}"
    if [[ "$(cat "${backups[0]}")" == "existing config" ]]; then
      pass "backup preserves content"
    else
      fail "backup content wrong"
    fi
  else
    fail "no backup created"
  fi

  rm -rf "$tmp_home" "$tmp_bin" "${min_path##*:}"
}

test_install_idempotent() {
  run_test "install is idempotent and preserves backups"
  local tmp_home
  tmp_home="$(mktemp -d)"
  local tmp_bin
  tmp_bin="$(mktemp -d)"
  local config_dir="$tmp_home/.config/opencode"

  for cmd in opencode uv npm; do
    cat > "$tmp_bin/$cmd" <<EOF
#!/bin/bash
echo "fake $cmd"
EOF
    chmod +x "$tmp_bin/$cmd"
  done

  mkdir -p "$config_dir"
  echo "original" > "$config_dir/opencode.jsonc"

  local min_path
  min_path="$(make_minimal_path "$tmp_bin")"
  HOME="$tmp_home" XDG_CONFIG_HOME="$tmp_home/.config" PATH="$min_path" "$INSTALLER" </dev/null >/dev/null 2>&1
  HOME="$tmp_home" XDG_CONFIG_HOME="$tmp_home/.config" PATH="$min_path" "$INSTALLER" </dev/null >/dev/null 2>&1

  local backups
  backups=("$config_dir"/opencode.jsonc.backup.*)
  if [[ ${#backups[@]} -ge 2 ]]; then
    pass "multiple backups created (${#backups[@]})"
  else
    fail "expected at least 2 backups, found ${#backups[@]}"
  fi

  rm -rf "$tmp_home" "$tmp_bin" "${min_path##*:}"
}

test_caveman_is_manual_only() {
  run_test "caveman is reported as manual-only"
  local tmp_home
  tmp_home="$(mktemp -d)"
  local tmp_bin
  tmp_bin="$(mktemp -d)"

  for cmd in opencode uv npm rtk; do
    cat > "$tmp_bin/$cmd" <<EOF
#!/bin/bash
echo "fake $cmd"
EOF
    chmod +x "$tmp_bin/$cmd"
  done

  local min_path
  min_path="$(make_minimal_path "$tmp_bin")"

  local output
  output="$(HOME="$tmp_home" XDG_CONFIG_HOME="$tmp_home/.config" PATH="$min_path" "$INSTALLER" </dev/null 2>&1)"

  if [[ "$output" == *"caveman is optional. Install it separately"* ]]; then
    pass "reports caveman as manual-only"
  else
    fail "missing manual-only caveman guidance"
  fi

  if [[ "$output" == *"Install caveman? (y/N)"* ]]; then
    fail "prompted to auto-install caveman"
  else
    pass "does not prompt to auto-install caveman"
  fi

  rm -rf "$tmp_home" "$tmp_bin" "${min_path##*:}"
}

main() {
  echo "Running GeneralPippy installer tests..."
  echo "Installer: $INSTALLER"

  test_help_flag
  test_version_flag
  test_unknown_flag
  test_dry_run_does_not_modify
  test_missing_core_dependency
  test_install_creates_files
  test_install_backs_up_existing_config
  test_install_idempotent
  test_caveman_is_manual_only

  echo ""
  echo "========================="
  echo "Passed: $PASSED"
  echo "Failed: $FAILED"
  echo "========================="

  [[ $FAILED -eq 0 ]]
}

main "$@"

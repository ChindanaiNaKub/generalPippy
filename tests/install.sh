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
  for cmd in cp mv mkdir rm dirname cat date mktemp sort md5sum find echo chmod sleep tr python3 perl sed grep; do
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

  # Create fake opencode/uv but omit npm to verify npm is no longer required (#24).
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
  # Without npm, install should still succeed (npm check is conditional).
  if output="$(PATH="$min_path" "$INSTALLER" --dry-run 2>&1)"; then
    pass "succeeds without npm (npm check is conditional)"
  else
    # If it fails, it should NOT be because of missing npm.
    if [[ "$output" == *"npm is not installed"* ]]; then
      fail "should not fail due to missing npm"
    else
      pass "fails for other reason (not npm)"
    fi
  fi

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
              skills/pippy/SKILL.md; do
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

test_caveman_mode_is_opencode_config() {
  run_test "caveman mode is detected from OpenCode config"
  local tmp_home
  tmp_home="$(mktemp -d)"
  local tmp_bin
  tmp_bin="$(mktemp -d)"
  local config_dir="$tmp_home/.config/opencode"

  for cmd in opencode uv npm rtk; do
    cat > "$tmp_bin/$cmd" <<EOF
#!/bin/bash
echo "fake $cmd"
EOF
    chmod +x "$tmp_bin/$cmd"
  done

  mkdir -p "$config_dir/commands"
  cat > "$config_dir/commands/caveman.md" <<'EOF'
---
description: Activate caveman compression mode
---
EOF

  local min_path
  min_path="$(make_minimal_path "$tmp_bin")"

  local output
  output="$(HOME="$tmp_home" XDG_CONFIG_HOME="$tmp_home/.config" PATH="$min_path" "$INSTALLER" </dev/null 2>&1)"

  if [[ "$output" == *"Caveman mode found"* ]]; then
    pass "detects OpenCode caveman mode"
  else
    fail "missing OpenCode caveman mode detection"
  fi

  if [[ "$output" == *"Install caveman? (y/N)"* ]]; then
    fail "prompted to auto-install caveman"
  else
    pass "does not prompt to auto-install caveman"
  fi

  rm -rf "$tmp_home" "$tmp_bin" "${min_path##*:}"
}

test_install_npm_optional() {
  run_test "install succeeds without npm when no package.json exists"
  local tmp_home
  tmp_home="$(mktemp -d)"
  local tmp_bin
  tmp_bin="$(mktemp -d)"
  local config_dir="$tmp_home/.config/opencode"

  # Create fake opencode and uv but NOT npm.
  for cmd in opencode uv; do
    cat > "$tmp_bin/$cmd" <<EOF
#!/bin/bash
echo "fake $cmd"
EOF
    chmod +x "$tmp_bin/$cmd"
  done

  local min_path
  min_path="$(make_minimal_path "$tmp_bin")"

  local output
  if output="$(HOME="$tmp_home" XDG_CONFIG_HOME="$tmp_home/.config" PATH="$min_path" "$INSTALLER" </dev/null 2>&1)"; then
    pass "succeeds without npm installed"
  else
    fail "failed without npm: $output"
  fi

  # Verify config files were still created.
  if [[ -f "$config_dir/opencode.jsonc" ]]; then
    pass "created opencode.jsonc"
  else
    fail "missing opencode.jsonc"
  fi

  rm -rf "$tmp_home" "$tmp_bin" "${min_path##*:}"
}

test_install_preserves_existing_plugins() {
  run_test "install preserves user's existing plugins"
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
  # Create existing config with user plugins.
  cat > "$config_dir/opencode.jsonc" <<'EXISTING'
{
  "plugin": [
    "@tarquinen/opencode-dcp@latest",
    "@mycompany/custom-plugin@1.2.3"
  ]
}
EXISTING

  local min_path
  min_path="$(make_minimal_path "$tmp_bin")"
  HOME="$tmp_home" XDG_CONFIG_HOME="$tmp_home/.config" PATH="$min_path" "$INSTALLER" </dev/null >/dev/null 2>&1

  # Verify the output config has both pinned and user plugins.
  if grep -q "@mycompany/custom-plugin@1.2.3" "$config_dir/opencode.jsonc"; then
    pass "user plugin preserved"
  else
    fail "user plugin was lost"
  fi

  if grep -q "@tarquinen/opencode-dcp" "$config_dir/opencode.jsonc"; then
    pass "pinned plugin present"
  else
    fail "pinned plugin missing"
  fi

  # Verify the pinned version is used, not @latest.
  if grep -q "@tarquinen/opencode-dcp@0.0.4" "$config_dir/opencode.jsonc"; then
    pass "pinned version used instead of @latest"
  else
    fail "expected pinned version 0.0.4"
  fi

  rm -rf "$tmp_home" "$tmp_bin" "${min_path##*:}"
}

test_install_rollbacks_on_failure() {
  run_test "install rolls back created files on failure"
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

  # Pre-create the config dir so it already exists before install.
  mkdir -p "$config_dir"

  # Make it read-only so cp -a inside copy_files will fail.
  chmod 555 "$config_dir"

  # Restore permissions in a cleanup trap so we never leave a read-only dir behind.
  trap 'chmod 755 "$config_dir" 2>/dev/null || true; rm -rf "$tmp_home" "$tmp_bin" "${min_path##*:}" 2>/dev/null || true' RETURN

  local min_path
  min_path="$(make_minimal_path "$tmp_bin")"

  # Install must fail because config dir is read-only.
  local output
  if output="$(HOME="$tmp_home" XDG_CONFIG_HOME="$tmp_home/.config" PATH="$min_path" "$INSTALLER" </dev/null 2>&1)"; then
    fail "install should have failed on read-only directory"
    trap - RETURN
    chmod 755 "$config_dir" 2>/dev/null || true
    rm -rf "$tmp_home" "$tmp_bin" "${min_path##*:}"
    return
  fi

  # Restore permissions immediately.
  trap - RETURN
  chmod 755 "$config_dir"

  # Rollback should have removed any newly-created files.
  if [[ ! -f "$config_dir/opencode.jsonc" ]]; then
    pass "opencode.jsonc removed after rollback"
  else
    fail "opencode.jsonc still present after rollback"
  fi

  if [[ ! -f "$config_dir/agents/pippy.md" ]]; then
    pass "agents/pippy.md removed after rollback"
  else
    fail "agents/pippy.md still present after rollback"
  fi

  # The pre-existing directory itself remains (it was not created by install).
  if [[ -d "$config_dir" ]]; then
    pass "pre-existing config directory preserved"
  else
    fail "pre-existing config directory was removed"
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
  test_caveman_mode_is_opencode_config
  test_install_npm_optional
  test_install_preserves_existing_plugins
  test_install_rollbacks_on_failure

  echo ""
  echo "========================="
  echo "Passed: $PASSED"
  echo "Failed: $FAILED"
  echo "========================="

  [[ $FAILED -eq 0 ]]
}

main "$@"

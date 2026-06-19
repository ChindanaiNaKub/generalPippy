#!/bin/bash
# lib/utils.sh — Generic JSON/JSONC helpers and profile metadata serialization.
# Sourced by install.sh and scripts/doctor.sh.
# Owns: json_get, model_frontmatter, jsonc_model_value, write_profile_json.
# Callers own: orchestration, validation, dry-run, logging.

# --- JSON / JSONC reading ---

json_get() {
  # Read a dot-separated path from a JSON file via python3.
  # Returns 1 if python3 is missing, the file is unreadable, or the key is absent.
  local file="$1"
  local path="$2"

  if ! command -v python3 &> /dev/null; then
    return 1
  fi

  python3 - "$file" "$path" <<'PY'
import json
import sys

path = sys.argv[1]
parts = sys.argv[2].split(".")

with open(path) as f:
    data = json.load(f)

for part in parts:
    data = data[part]

print(data)
PY
}

model_frontmatter() {
  # Extract the model value from a markdown file's YAML frontmatter.
  local file="$1"
  sed -n 's/^model:[[:space:]]*//p' "$file" | head -1
}

jsonc_model_value() {
  # Extract a string value from a JSONC file by key (first match).
  local file="$1"
  local key="$2"
  sed -n "s/.*\"$key\"[[:space:]]*:[[:space:]]*\"\\([^\"]*\\)\".*/\\1/p" "$file" | head -1
}

# --- Profile metadata serialization ---

write_profile_json() {
  # Write profile metadata to $GENERALPIPPY_DIR/profile.json.
  # Caller must set GENERALPIPPY_DIR and create it before calling.
  # Uses python3 if available; falls back to a heredoc.
  local profile="$1"
  local coordination="$2"
  local planning="$3"
  local implementation="$4"
  local system="$5"

  if command -v python3 &> /dev/null; then
    python3 - "$GENERALPIPPY_DIR/profile.json" "$profile" "$coordination" "$planning" "$implementation" "$system" <<'PY'
import json, sys

path = sys.argv[1]
profile = sys.argv[2]
coordination = sys.argv[3]
planning = sys.argv[4]
implementation = sys.argv[5]
system = sys.argv[6]

data = {
    "profile": profile,
    "models": {
        "coordination": coordination,
        "planning": planning,
        "implementation": implementation,
        "system": system
    }
}

with open(path, 'w') as f:
    json.dump(data, f, indent=2)
    f.write('\n')
PY
  else
    cat > "$GENERALPIPPY_DIR/profile.json" <<EOF
{
  "profile": "$profile",
  "models": {
    "coordination": "$coordination",
    "planning": "$planning",
    "implementation": "$implementation",
    "system": "$system"
  }
}
EOF
  fi
}

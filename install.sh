#!/bin/bash
# GeneralPippy v2.0 — Self-Driving Goal Agent for OpenCode
# Install script: copies config files to ~/.config/opencode/

set -e

echo "🐱 GeneralPippy v2.0 — Installing Self-Driving Goal Agent..."
echo ""

# Check core dependencies
echo "🔍 Checking core dependencies..."

if ! command -v opencode &> /dev/null; then
    echo "❌ opencode is not installed."
    echo "   Install it from: https://opencode.ai"
    exit 1
fi
echo "✅ opencode found"

if ! command -v uv &> /dev/null; then
    echo "❌ uv is not installed."
    echo "   Install it from: https://docs.astral.sh/uv/"
    exit 1
fi
echo "✅ uv found"

if ! command -v npm &> /dev/null; then
    echo "❌ npm is not installed."
    echo "   Install it from: https://nodejs.org/"
    exit 1
fi
echo "✅ npm found"

echo ""

# Create directories
echo "📁 Creating directories..."
mkdir -p ~/.config/opencode/agents
mkdir -p ~/.config/opencode/commands
mkdir -p ~/.config/opencode/skills/pippy
mkdir -p ~/.config/opencode/skills/verify

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Backup existing config
if [ -f ~/.config/opencode/opencode.jsonc ]; then
    echo "💾 Backing up existing config..."
    cp ~/.config/opencode/opencode.jsonc ~/.config/opencode/opencode.jsonc.backup
fi

# Copy files
echo "📝 Copying config files..."

# Main config
cp "$SCRIPT_DIR/config/opencode.jsonc" ~/.config/opencode/opencode.jsonc

# Agents
cp "$SCRIPT_DIR/config/agents/pippy.md" ~/.config/opencode/agents/
cp "$SCRIPT_DIR/config/agents/pippy-plan.md" ~/.config/opencode/agents/
cp "$SCRIPT_DIR/config/agents/pippy-build.md" ~/.config/opencode/agents/

# Commands
cp "$SCRIPT_DIR/config/commands/goal.md" ~/.config/opencode/commands/
cp "$SCRIPT_DIR/config/commands/ship.md" ~/.config/opencode/commands/
cp "$SCRIPT_DIR/config/commands/budget.md" ~/.config/opencode/commands/

# Skills
cp "$SCRIPT_DIR/config/skills/pippy/SKILL.md" ~/.config/opencode/skills/pippy/
cp "$SCRIPT_DIR/config/skills/verify/SKILL.md" ~/.config/opencode/skills/verify/

echo "✅ Files copied"

# Check optional dependencies
# These are installed AFTER config copy so they can patch opencode.jsonc if needed.
echo ""
echo "🔍 Checking optional dependencies..."

install_optional() {
    local name="$1"
    local install_cmd="$2"
    local check_cmd="$3"

    if command -v $check_cmd &> /dev/null; then
        echo "✅ $name found"
        return 0
    fi

    echo "⚠️  $name not found."
    read -p "   Install $name? (y/N) " -n 1 -r
    echo ""
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        echo "   Installing $name..."
        eval "$install_cmd" && echo "✅ $name installed" || echo "⚠️  Failed to install $name — Pippy will degrade gracefully"
    else
        echo "   Skipping $name — Pippy will degrade gracefully"
    fi
}

install_optional "rtk" "curl -fsSL https://raw.githubusercontent.com/rtk-ai/rtk/refs/heads/master/install.sh | sh && rtk init -g --opencode" "rtk"
install_optional "caveman" "curl -fsSL https://raw.githubusercontent.com/JuliusBrussee/caveman/main/install.sh | bash" "caveman"

echo ""
echo "📌 ponytail is optional but cannot be auto-installed."
echo "   To use it, clone https://github.com/DietrichGebert/ponytail and add"
echo "   its .opencode/plugins/ponytail.mjs path to your opencode.jsonc plugins."

# Install npm plugins
echo "📦 Installing plugins..."
cd ~/.config/opencode
if [ -f package.json ]; then
    npm install 2>/dev/null || echo "⚠️  npm install failed (plugins may need manual install)"
fi

echo ""
echo "🎉 GeneralPippy v2.0 installed successfully!"
echo ""
echo "Next steps:"
echo "  1. Run 'opencode' to start"
echo "  2. Pippy is now your default agent"
echo "  3. Use /goal \"<objective>\" to start a self-driving task"
echo "  4. Use /ship to prepare for PR"
echo "  5. Use /budget to check token usage"
echo ""
echo "Models configured:"
echo "  • Planning: opencode-go/kimi-k2.7-code (strong)"
echo "  • Implementation: opencode-go/mimo-v2.5 (cheap)"
echo "  • System tasks: opencode-go/deepseek-v4-flash (cheapest)"
echo ""
echo "Plugins configured:"
echo "  • jcodemunch-mcp — AST code indexing"
echo "  • opencode-dcp — Dynamic context pruning"
echo ""
echo "Optional tools (install for best experience):"
echo "  • rtk — Token-efficient bash wrapper"
echo "  • caveman — Compressed build output"
echo "  • ponytail — Lazy senior-dev planning constraint (manual install)"
echo ""
echo "For more info: https://github.com/ChindanaiNaKub/generalPippy"

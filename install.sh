#!/bin/bash
# GeneralPippy — Orchestrator Agent for OpenCode
# Install script: copies config files to ~/.config/opencode/

set -e

echo "🐱 GeneralPippy — Installing Orchestrator Agent..."
echo ""

# Check if opencode is installed
if ! command -v opencode &> /dev/null; then
    echo "❌ opencode is not installed."
    echo "   Install it from: https://opencode.ai"
    exit 1
fi

echo "✅ opencode found"

# Create directories
echo "📁 Creating directories..."
mkdir -p ~/.config/opencode/agents
mkdir -p ~/.config/opencode/commands
mkdir -p ~/.config/opencode/skills/orchestrate
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
cp "$SCRIPT_DIR/config/agents/orchestrator.md" ~/.config/opencode/agents/
cp "$SCRIPT_DIR/config/agents/orchestrator-plan.md" ~/.config/opencode/agents/
cp "$SCRIPT_DIR/config/agents/orchestrator-build.md" ~/.config/opencode/agents/

# Commands
cp "$SCRIPT_DIR/config/commands/think.md" ~/.config/opencode/commands/
cp "$SCRIPT_DIR/config/commands/verify.md" ~/.config/opencode/commands/
cp "$SCRIPT_DIR/config/commands/ship.md" ~/.config/opencode/commands/
cp "$SCRIPT_DIR/config/commands/budget.md" ~/.config/opencode/commands/
cp "$SCRIPT_DIR/config/commands/cheap.md" ~/.config/opencode/commands/
cp "$SCRIPT_DIR/config/commands/smart.md" ~/.config/opencode/commands/

# Skills
cp "$SCRIPT_DIR/config/skills/orchestrate/SKILL.md" ~/.config/opencode/skills/orchestrate/
cp "$SCRIPT_DIR/config/skills/verify/SKILL.md" ~/.config/opencode/skills/verify/

echo "✅ Files copied"

# Install npm plugins
echo "📦 Installing plugins..."
cd ~/.config/opencode
if [ -f package.json ]; then
    npm install 2>/dev/null || echo "⚠️  npm install failed (plugins may need manual install)"
fi

echo ""
echo "🎉 GeneralPippy installed successfully!"
echo ""
echo "Next steps:"
echo "  1. Run 'opencode' to start"
echo "  2. The Orchestrator is now your default agent"
echo "  3. Use Tab to switch between agents"
echo "  4. Use /think, /verify, /ship, /budget, /cheap, /smart commands"
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
echo "For more info: https://github.com/ChindanaiNaKub/generalPippy"

---
description: Show token usage, cost, and model stats
---

## Budget Report

Show current session token usage and cost estimates.

Analyze the current session and report:
1. Total tokens used (input + output)
2. Which models were used (planning vs implementation)
3. Estimated cost based on opencode-go pricing
4. Suggestions for optimization

**Model Pricing (opencode-go):**
- Kimi K2.7 Code: $0.95/$4.00 per 1M tokens (planning)
- MiMo V2.5: $0.14/$0.28 per 1M tokens (implementation)
- DeepSeek V4 Flash: $0.14/$0.28 per 1M tokens (system tasks)

**Usage:** /budget

---
description: Request read-only advice from an advisor adapter
agent: pippy
---

## /advice

Request read-only advice from an external AI coding tool through an advisor adapter.

**Usage:** `/advice <adapter-name>` | `/advice all`

Advisor adapters are detected during installation but disabled by default. To enable one, edit `~/.config/opencode/generalpippy/advisors.json` and set `"enabled": true` for the desired adapter.

### /advice <adapter-name>

Prepare a read-only advisor context bundle for the named enabled adapter and show the exact command/template to invoke it.

**What the bundle includes:**
- Objective and context from the current goal or conversation
- Constraints and acceptance criteria
- What to ask the advisor (specific question or analysis request)
- How to return advice to Pippy (output format guidance)

**What happens:**
1. Pippy reads `~/.config/opencode/generalpippy/advisors.json` to verify the adapter exists and is enabled
2. Pippy assembles an advisor context bundle with the current objective, constraints, and relevant repo context
3. Pippy shows the exact command or template to invoke the advisor with the bundle
4. The user runs the command externally and pastes the result back

**If the adapter is not found or not enabled:**
- Pippy reports the adapter is unavailable
- Pippy lists available adapters (from `advisors.json`)
- Pippy suggests enabling it by editing `advisors.json`

### /advice all

Prepare bundles for all enabled adapters and provide a conflict-aware summary section that helps the user compare advice and identify conflicts.

**What happens:**
1. Pippy reads `advisors.json` and identifies all enabled adapters
2. For each enabled adapter, Pippy prepares a context bundle and shows the invocation command
3. After all advisors respond, Pippy provides a conflict-aware summary:
   - Where advisors agree
   - Where advisors conflict
   - Which advice aligns with repo ADRs and verified code facts
   - Which advice Pippy recommends based on the current objective

### Read-only constraint

Advisors must remain read-only. They must not edit files or execute workspace changes, override Pippy's objective, repo docs/ADRs, or verified code facts, or replace Pippy's planning or execution loop.

Advisors provide plans, critiques, diagnoses, or context summaries. Pippy remains responsible for all execution decisions.

---
description: Ship mode — review, verify, push, and create a green-gate PR
agent: pippy
---

## Ship Mode

An alias for `/goal "review, verify, and create a pull request for this branch after all green gates pass"`.

Pippy will:
1. Review all changes (`rtk git diff` when `rtk` is installed)
2. Run the full verification gate (tests, lint, typecheck)
3. Check for security issues
4. Check docs for public API changes
5. Check branch safety: current branch is not the default branch, the working tree is clean, and the branch is safe to push
6. Check GitHub readiness: `gh auth status` works, an `origin` remote exists, and no open PR already exists for the current branch
7. Generate a non-interactive PR title and body from the verified diff and evidence
8. Push the branch with `rtk git push -u origin HEAD` when needed
9. Create the PR non-interactively with `rtk gh pr create --title ... --body ...`
10. Report `Shipped` only when a PR URL exists

### Green-Gate PR Creation

Create a PR only after all gates pass:
- Review gate: diff reviewed, review checklist applied, Program design checked when relevant, and Assumption audit completed
- Verification gate: full verification passes and docs/security checks are complete
- clean-tree gate: `rtk git status --short` shows no uncommitted changes
- Branch-safety gate: current branch is not the default branch, and branch name/remote are known
- GitHub-readiness gate: `rtk gh auth status` succeeds and repo remote resolves
- Existing-PR gate: `rtk gh pr view --head <branch>` confirms no open PR already exists, or returns the existing PR URL to report instead of creating a duplicate

Use generated title/body only; do not open an editor or ask interactively during the PR command.

Outcome states:
- `Shipped` — review and verification passed, push/PR creation succeeded or an existing open PR for this branch was found, and the report includes the PR URL.
- `Ready, PR blocked` — review and verification passed, but push or PR creation failed. Preserve the generated PR title/body in the report and include the failed command, error output, and exact retry guidance.

Never create a PR from the default branch or with a dirty working tree. If either gate fails, report `Ready, PR blocked` only when review and verification already passed; otherwise report the earlier failed gate.

### RTK Force

When `rtk` is installed, `/ship` MUST route every shell command through `rtk`. Use `rtk git status`, `rtk git log`, `rtk git diff`, `rtk proxy git diff -- <paths>` for path-scoped diffs, `rtk gh ...`, and `rtk make all` instead of raw `git`, `gh`, or `make`. For commands without a specialized wrapper, use `rtk run` or `rtk proxy`. Fall back to raw shell only if `rtk` is missing or the wrapper fails for that exact command, and mention the fallback in the report.

### Early Context Compression

Before the final verification gate, call `compress` to summarize large exploration/planning sections that consumed context window. This keeps verification output readable and prevents context pressure from degrading the final report.

### Caveman Mode Reports

When Caveman mode (OpenCode compression style) is active, report in caveman-full style: terse, no fluff, preserve full technical substance and verification results. Drop filler words, hedging, and pleasantries. Keep error messages, test output, and file paths exact.

### Release Confirmation

After `gh release create`, trust the CLI exit status. Do NOT re-fetch the release to confirm. Only investigate if the command reports an error (non-zero exit or stderr output).

**Usage:** /ship

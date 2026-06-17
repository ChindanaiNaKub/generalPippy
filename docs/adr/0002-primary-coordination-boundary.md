# Primary Coordination Boundary

Status: accepted

Pippy's primary agent is a coordinator, not an implementation worker. We deny primary-agent edits but allow unrestricted bash so YOLO mode can run git, gh, make, verification, and repo-local commands without approval friction. File creation, file copies, config edits, refactors, bug fixes, and tests still route through `pippy-build` on the cheap implementation model. The rejected alternative was a prompt-only rule with a tiny-edit exception; that was cheaper to write but allowed the strong primary model to silently perform implementation work, which defeats GeneralPippy's budget goal.

## Consequences

- Small edits still create a `pippy-build` child session.
- If `pippy-build` is unavailable, `/goal` reports blocked instead of falling back to strong-model implementation.
- Primary and build-agent bash commands do not ask for approval; safety is enforced by routing, scope, verification, and reporting.

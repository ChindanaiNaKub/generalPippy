# Primary Coordination Boundary

Status: accepted

Pippy's primary agent is a coordinator, not an implementation worker. We deny primary-agent edits and auto-allow only exploration and verification bash so that file creation, file copies, config edits, refactors, bug fixes, and tests route through `pippy-build` on the cheap implementation model. The rejected alternative was a prompt-only rule with a tiny-edit exception; that was cheaper to write but allowed the strong primary model to silently perform implementation work, which defeats GeneralPippy's budget goal.

## Consequences

- Small edits still create a `pippy-build` child session.
- If `pippy-build` is unavailable, `/goal` reports blocked instead of falling back to strong-model implementation.
- Unusual primary-agent bash commands ask for approval; routine exploration and verification stay automatic.

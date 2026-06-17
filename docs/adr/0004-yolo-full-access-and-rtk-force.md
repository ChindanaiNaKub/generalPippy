# YOLO full-access bash and RTK force

Status: accepted

GeneralPippy's default YOLO mode allows unrestricted bash for `pippy` and `pippy-build` so self-driving work can run git, gh, make, dependency, and repo-local commands without approval prompts. This trades permission-gate safety for lower user friction, so safety must come from scoped objectives, `pippy-build` implementation routing, verification, explicit reporting of risky commands, and the rule that installed `rtk` wraps every shell command unless it is unavailable or fails for that exact command.

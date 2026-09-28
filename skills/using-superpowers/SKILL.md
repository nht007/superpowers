---
name: using-superpowers
description: Use when starting a conversation that needs feature, behavior, or architecture design before implementation
---

<SUBAGENT-STOP>
If you were dispatched as a subagent to execute a specific task, ignore this skill.
</SUBAGENT-STOP>

# Design With Superpowers

Use `superpowers:brainstorming` to shape and approve a new feature, behavior
change, or architectural design before implementation. Read it before exploring
the codebase or proposing a design. Keep its approval gate, mechanism-level
design check, and spec self-review intact.

After the approved design is recorded, continue in the same conversation.
Choose the implementation sequence, testing approach, review, and delegation
using your host's native capabilities. Follow the approved design and
applicable user and repository instructions throughout.

Use the full Superpowers execution methods — `writing-plans`,
`executing-plans`, `test-driven-development`,
`subagent-driven-development`, and `dispatching-parallel-agents` — when
your human partner explicitly requests the named method. They remain
available; an ordinary request to implement or test does not select one.
Use situational skills, including `systematic-debugging`, review,
verification, and worktree skills, when their specific triggers apply.
When you encounter a bug, failing test, or unexpected behavior in the work,
invoke `superpowers:systematic-debugging` before investigating or proposing
a fix.
`systematic-debugging` invokes the full `test-driven-development` method
when it reaches its failing-test step.

Direct user instructions take precedence over skills.

## Platform Adaptation

Read the reference for your harness, resolving its path from this skill's
directory:

- Codex: [codex-tools.md](./references/codex-tools.md)
- Pi: [pi-tools.md](./references/pi-tools.md)
- Antigravity: [antigravity-tools.md](./references/antigravity-tools.md)
- Hermes Agent: [hermes-tools.md](./references/hermes-tools.md)

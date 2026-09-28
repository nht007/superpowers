# Shared Native Implementation Workflow

## Purpose

The Nela Superpowers fork currently routes an approved architectural design into
`writing-plans`, then often into the full Superpowers execution sequence. The
NP-317 Codex pilot showed that the design gate can be retained while the host
agent handles implementation natively. That pilot removed the other skill files
from its temporary package, which would make useful methods unavailable if
merged directly. The permanent fork needs one workflow for personal Codex and
work-Mac Claude without deleting those methods.

## Decision

The shared default is Superpowers design followed by native implementation in
the same conversation. `using-superpowers` activates `brainstorming` for a new
feature, behavior change, or architectural design. `brainstorming` keeps its
classification, approval gate, mechanism-level design check, architectural
specification, and self-review. After that gate, the host agent selects its
implementation sequence, tests, review, and delegation under the approved
design and applicable user and repository instructions.

The five full execution methods remain installed and discoverable:
`writing-plans`, `executing-plans`, `test-driven-development`,
`subagent-driven-development`, and `dispatching-parallel-agents`. Their trigger
descriptions require an explicit user request for that method. An agent can
still choose ordinary planning, tests, and delegation natively; the request
condition selects the named Superpowers method, not the underlying activity.
When a method is requested, its own workflow applies, subject to higher-priority
instructions. Situational skills such as debugging, review, worktrees, and
verification remain available when their actual trigger applies.
Bug fixes require a failing reproduction to run before production edits,
whether or not `systematic-debugging` activates. Full TDD remains available
on explicit request.

## Behavior and Boundary

For a request to build a new feature, the bootstrap loads `brainstorming`
before implementation. The agent explores material mechanism choices, presents
the design in chat, receives approval, records and self-reviews a specification
for architectural work, then implements in the same conversation. If the user
also asks for `writing-plans` or another named execution method, the agent uses
that method at the appropriate point after the design gate.

For a bug, failing test, or unexpected behavior, the bootstrap invokes
`systematic-debugging` before investigation or a proposed fix. For a bug fix,
the agent writes and runs a failing reproduction before changing production
code even if the debugging skill does not activate. For an explicit request
to use TDD or subagent-driven development, the corresponding method remains
available. The bootstrap does not force every possibly relevant skill into
the workflow. User and repository requirements for tests, reviews, and Git
integration remain binding.

## Maintained Surfaces

- Change `skills/using-superpowers/SKILL.md` to define design activation,
  explicit execution-method selection, and harness-neutral native handoff.
- Reconcile the NP-317 pilot's `skills/brainstorming/SKILL.md` handoff with
  current `main`, preserving the published mechanism-level design check.
- Narrow only the trigger descriptions of the five execution-method skills.
  Their bodies remain intact for users who invoke them.
- Keep `systematic-debugging`'s failing-test step aligned with the bootstrap
  rule while leaving the full TDD skill request-only.
- Update `NELA.md` and the existing version manifests for one shared release.
  No new package filter, fork, hook, or parallel implementation is needed.

The pilot's deletion of the other skills is obsolete and will not be merged.
The current forced plan handoff and blanket skill-invocation rule become
unnecessary and are removed from the active guides. Existing packaging and
installation paths remain.

## Verification and Rollout

Establish baseline behavior from the current fork, then evaluate fresh agent
sessions against the candidate. Cover an ordinary new-feature request, an
architectural spec handoff, a request for a full execution method, and a
bug fix with a failing reproduction before production edits. Run the fork's
contract, packaging, manifest, hook, version, and lint checks. Confirm the
Codex package contains all retained
skills and the shared candidate behaves as designed in a fresh Codex session.

Push only the candidate branch for isolated work-Mac Claude validation with
`--plugin-dir`. The work installation stays at its current version until the
owner chooses to update it. After both harnesses accept the same candidate,
advance fork `main`, tag the next Nela release, verify the remote ref, and
update personal Codex. Do not release a candidate that removes skill files or
passes only one harness.

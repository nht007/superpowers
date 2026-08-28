# Nela Superpowers

This repository is the Nela-maintained Superpowers source for personal Codex work and work-Mac
Claude work. It keeps the `superpowers` plugin name and `superpowers:*` skill namespace while using
the distinct `nela-superpowers` marketplace identity on both harnesses.

The fork is tested on Codex and Claude. Other upstream harness adapters remain in the shared source
for merge compatibility but are not part of the Nela acceptance boundary.

## Workflow Contract

Architectural brainstorming presents the design section by section in chat. Approval of the final
section approves the design. The agent then writes and self-reviews the specification as a durable
record and proceeds directly to implementation planning.

Implementation plans retain exact files, steps, tests, commands, expected results, and commit
boundaries. After self-review, the agent presents a concise decision-complete chat handoff covering
scope, trade-offs, maintained surfaces, execution lane, verification, risks, dependencies, and the
actions authorized by approval. Implementation waits for approval of that handoff.

Brainstorming uses the ordinary chat surface for questions, design sections, and approvals.

Completed personal work automatically proceeds through outcome-owned integration, publication,
remote-ref verification, and safe cleanup. Collaborative work follows the repository's required
review policy, and unclear repository classification produces one focused personal/solo-or-
collaborative question. The generic merge, pull-request, or keep-branch options menu is deliberately
not part of the Nela workflow.

The remaining Superpowers skills retain their upstream behavior unless this file and the repository
history name a current Nela delta.

## Upstream Provenance and Versions

[`UPSTREAM.json`](UPSTREAM.json) is the machine-readable authority for the exact upstream release
incorporated by the fork. The initial accepted base is upstream tag `v6.3.0` at commit
`b36e0829c6d0140e93cfef2ca599b1b07d4a7797` from
`https://github.com/obra/superpowers.git`.

Fork releases use `X.Y.Z-nela.N` versions and `vX.Y.Z-nela.N` tags. A Nela-only correction increments
`N`; adopting a new upstream `X.Y.Z` base starts again at `nela.1`. Every version-bearing manifest is
updated through `scripts/bump-version.sh`.

## Candidate Testing

Candidate work uses a `tn/` branch and an isolated worktree. Before publication:

1. Run the repository contract, manifest, packaging, hook, version, lint, and unaffected-skill tests.
2. Install the local marketplace into a permission-restricted temporary `CODEX_HOME` and confirm it
   is the only Superpowers plugin in that home.
3. Exercise every maintained workflow delta in fresh ephemeral Codex sessions, including the
   design-to-plan path and personal and collaborative finishing, then run an unchanged-skill smoke.
4. Push only the candidate branch and run the same maintained-delta and unchanged-skill checks
   through work-Mac Claude with `--plugin-dir` and no second Superpowers plugin active.

Fork `main` and the release tag advance only after both harnesses accept the same candidate commit.

## Codex Installation and Cutover

Add and install the tested fork through the Codex CLI:

```bash
codex plugin marketplace add nht007/superpowers --ref main
codex plugin marketplace upgrade nela-superpowers
codex plugin add superpowers@nela-superpowers
codex plugin list --json
```

Verify the enabled plugin identity, source, and released version before removing another Superpowers
installation. During a controlled cutover with no ordinary session started in between, remove the
direct-upstream or curated installation and its obsolete marketplace. A fresh session must expose
exactly one `superpowers:*` namespace.

Nela Config owns the durable Codex installation and its SessionStart upstream reminder. The reminder
is passive, cached, throttled, and never performs an update.

## Claude Installation and Updates

Work-Mac Claude validates a pushed candidate in an isolated checkout before installing the released
fork through the work machine's current plugin-management path. The fork is enabled and proved before
the previous Superpowers installation is removed or disabled; no ordinary session starts while both
namespaces are active.

The existing Claude SessionStart hook compares the installed fork version with tested fork `main`.
It reports a newer tested fork release at most weekly while unresolved. It never inspects or integrates
upstream and never changes work-Mac state.

## Adopting Upstream

The personal M2 is the sole upstream integrator. Review upstream releases roughly monthly or when the
passive reminder identifies a newer release:

1. Fetch `upstream`, inspect the exact release tag, release notes, and diff from
   `UPSTREAM.json.commit`, and decide what to adopt.
2. Create `tn/adopt-upstream-vX.Y.Z` from fork `main`.
3. Merge the exact upstream tag with one intentional two-parent merge commit.
4. Resolve mechanical conflicts normally. Return workflow-semantic conflicts to design approval.
5. Update `UPSTREAM.json` and all version-bearing manifests.
6. Repeat repository, isolated Codex, real work-Mac Claude, and single-namespace live acceptance.
7. Fast-forward fork `main` to the accepted commit and create the Nela release tag.

Fork `main` is never force-pushed.

## Verification

An accepted release proves:

- both marketplace manifests use `nela-superpowers` and expose one `superpowers` plugin;
- all registered manifests carry the same fork version;
- `UPSTREAM.json` resolves to the recorded upstream tag and commit;
- the Codex package contains all retained skills and excludes the Claude hook;
- the Claude root contains its SessionStart hook and all retained skills;
- both harnesses follow every maintained workflow contract and pass an unchanged-skill smoke; and
- each live installation exposes exactly one Superpowers namespace.

## Rollback

Every tested Nela release tag is an immutable rollback target. Select the exact prior tag through the
harness's installation path, verify its manifests and package, and run a fresh single-namespace smoke
test. Rollback does not reset or force-push fork `main`.

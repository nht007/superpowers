---
name: finishing-a-development-branch
description: Use when implementation is complete, all tests pass, and the repository workflow must integrate or publish the completed work
---

# Finishing a Development Branch

## Overview

**Core principle:** Establish applicable verification → prove ownership → apply repository policy →
publish → verify the remote → clean up owned state.

**Announce at start:** "I'm using the finishing-a-development-branch skill to complete this work."

## Step 1: Inventory Candidate Verification Evidence

Use `superpowers:verification-before-completion` to identify evidence for the candidate without
assuming either that an earlier run applies or that it must be repeated. Record:

- the commands or behavioral checks that ran and their observed results;
- the commit/tree or other state they covered;
- the relevant toolchain/environment when it matters; and
- any later content or input change.

Do not claim the candidate is verified yet. Step 2 captures its current identity and decides whether
this evidence applies.

## Step 2: Capture Repository State

Capture the workspace identity before any directory or branch changes:

```bash
GIT_DIR=$(cd "$(git rev-parse --git-dir)" 2>/dev/null && pwd -P)
GIT_COMMON=$(cd "$(git rev-parse --git-common-dir)" 2>/dev/null && pwd -P)
WORKTREE_PATH=$(git rev-parse --show-toplevel)
BRANCH=$(git branch --show-current)
HEAD_SHA=$(git rev-parse HEAD)
HEAD_TREE=$(git rev-parse HEAD^{tree})
git status --porcelain=v1 -uall
git remote -v
```

Fetch the intended remote before comparing or integrating work. Fetch updates remote-tracking refs;
it does not authorize a merge, rebase, force-push, or worktree cleanup.

Stop if the candidate tree contains uncommitted work whose ownership is unclear. Record whether this
is a normal repository (`GIT_DIR == GIT_COMMON`), a named-branch linked worktree, or an externally
managed detached workspace.

Apply the evidence gate to `HEAD_SHA` / `HEAD_TREE` and the captured worktree state:

- If authoritative evidence covers the exact candidate tree and every input material to the claim
  is unchanged, carry it forward. A turn or session boundary alone does not require another suite.
- If a bounded content or relevant-input change occurred, run the checks that prove that affected
  surface.
- If evidence is missing, ambiguous, or broadly stale, run the full relevant suite (`npm test` /
  `cargo test` / `pytest` / `go test ./...`).
- Follow any explicit owner or repository requirement for a new candidate-stage run.

Inspect complete output and stop on every failed required check. Do not integrate a candidate whose
applicable verification is incomplete.

## Step 3: Determine Base Branch

Use the approved plan, conversation, branch upstream, or a provable fork point to identify the base
branch. Confirm the candidate relationship with `git merge-base` and inspect the exact commit range.

If the base cannot be established, ask only:

```
This work appears to have split from <best-guess>. Is that the intended base branch?
```

Do not integrate until the base is known. Merging into the wrong base is expensive to undo.

## Step 4: Resolve Repository Policy

Resolve the completion policy in this order:

1. explicit instructions for the current task;
2. closer repository guidance;
3. durable user-level guidance.

Classify by the policy those sources establish:

- **Personal/solo** requires an explicit personal or solo designation, or standing guidance that
  identifies this repository or repository class as personal/solo.
- **Collaborative** requires guidance or task context that establishes external review, a pull or
  merge request, branch protection, or another shared integration path.
- **Unclassified** includes guidance that names only Git mechanics such as fast-forwarding, rebasing,
  squashing, merging onto `main`, branch naming, or a preferred base. Those mechanics choose how an
  already-classified repository integrates work; they do not authorize publication or cleanup.

If classification remains unclear, ask only:

```
Is this repository personal/solo or collaborative?
```

Do not offer a generic merge, pull-request, or keep-branch menu. Once policy is known, follow its
completion path without a redundant choice prompt.

## Step 5: Complete Personal Work

Personal completion means integrating only the approved current outcome into the base branch,
establishing applicable verification for the integrated result, publishing the base branch,
verifying the exact remote ref, and cleaning up outcome-owned branch/worktree state.

Before integration:

- inspect every commit and changed path in `<base>..<candidate>`;
- prove that the range belongs to the approved current outcome;
- apply the repository's curated-history policy before shared integration; and
- stop if visible commits or files are unrelated, concurrently owned, or otherwise ambiguous.

### Named outcome branch

Move to the canonical repository root. Recheck immediately that its checkout is safe for integration:
the base checkout and worktree must not contain unrelated or concurrently owned state.

```bash
MAIN_ROOT=$(git -C "$(git rev-parse --git-common-dir)/.." rev-parse --show-toplevel)
cd "$MAIN_ROOT"
git fetch origin
git checkout <base-branch>
git merge --ff-only origin/<base-branch>
```

Integrate the curated outcome commits according to applicable repository guidance. Prefer a
fast-forward result; do not create a merge commit unless the repository or human partner requires
one. If integration exposes a behavioral conflict or requires choosing between implementations,
stop and present that design decision.

Capture the integrated content identity:

```bash
INTEGRATED_TREE=$(git rev-parse HEAD^{tree})
```

- If `INTEGRATED_TREE == HEAD_TREE`, content-scoped candidate evidence still applies. Run only
  checks required for a named integration-specific risk, such as branch-sensitive packaging,
  generated artifacts, migrations, or an explicit post-integration policy.
- If the trees differ, inspect the exact difference and run verification proportionate to its
  affected surface. Use the full relevant suite when the difference or risk is broad.

Stop and investigate every failed required check. Leave the outcome branch and owned worktree in
place; do not push or clean up. Do not rerun the content suite merely because the same tree now has
the base-branch ref.

### Direct work on the base branch

Skip branch integration. Still prove which local-ahead commits belong to the current outcome and
that the Step 2 evidence applies to the current tree, then push normally, compare the remote ref, and
report the clean state. Stop if other local commits are mixed into the range.

### Externally managed detached workspace

From the canonical root, integrate only the exact proven outcome commits into the known base, using
the repository's curated-history policy. Leave the detached workspace in place. Stop if the commit
range, base, or canonical-checkout ownership cannot be proved.

After the integrated result's required verification is satisfied, publish with a normal push:

```bash
git push origin <base-branch>
```

A rejected or uncertain push is a stop condition. Investigate the remote movement; never infer
permission to retry destructively or force-push.

## Step 6: Complete Collaborative Work

Follow closer repository review guidance. Push the outcome-owned branch normally, create the
required draft pull or merge request against the known base, report its full URL, and retain the
worktree for review feedback.

```bash
git push -u origin <feature-branch>
```

For a detached workspace, publish the exact proven commit as an appropriately named remote branch.
Stop if the branch name, outcome range, base, or review policy cannot be established. A rejected or
uncertain push never authorizes a force-push.

## Step 7: Verify Remote Publication

After every successful push, compare the intended local commit with the exact remote ref. For
personal completion, verify the base branch; for collaborative completion, verify the published
feature branch.

```bash
local_sha=$(git rev-parse <published-local-ref>)
remote_sha=$(git ls-remote origin "refs/heads/<published-remote-branch>" | awk '{print $1}')
test -n "$remote_sha" && test "$local_sha" = "$remote_sha"
```

A missing or mismatched remote SHA is a failed closeout. Report both refs and stop before cleanup.

## Step 8: Cleanup Workspace

Cleanup runs only after verified personal publication or an explicitly confirmed discard.
Collaborative worktrees remain available for review feedback.

Use the `GIT_DIR`, `GIT_COMMON`, and `WORKTREE_PATH` captured in Step 2.

**If `GIT_DIR == GIT_COMMON`:** there is no linked worktree to remove. After verified personal
publication, delete only the fully merged outcome-owned branch when one exists.

**If `WORKTREE_PATH` is under `.worktrees/` or `worktrees/`:** Superpowers owns cleanup:

```bash
git worktree remove "$WORKTREE_PATH"
git worktree prune
```

Then delete the fully merged outcome branch from the canonical root:

```bash
git branch -d <feature-branch>
```

**If removal is refused** (`contains modified or untracked files`), unique files remain. Never use
`--force` on your own initiative. Show the exact files:

```bash
git -C "$WORKTREE_PATH" status --porcelain -uall
```

Ask whether to commit them to the outcome, move them to a named safe location, or delete them. State
that deletion is unrecoverable. Carry out only the chosen action, then retry ordinary removal once.

**Otherwise:** the host environment owns the workspace. Leave it in place and use a platform-provided
workspace-exit action if one exists.

### Explicit discard requests

Discard exists only in response to an explicit request to throw the work away. Confirm first:

```
This will permanently delete:
- Branch <name>
- All commits: <commit-list>
- Worktree at <path>

Type 'discard' to confirm.
```

Wait for the exact word `discard`. Then move to the canonical root, apply the same unique-file
protection above, remove only an owned worktree, and force-delete only the named outcome branch.

## Common Rationalizations

| Excuse | Reality |
|--------|---------|
| "Tests passed earlier, so they still count" | Prove the current exact tree and every relevant input before carrying evidence forward. |
| "It is a new session, so both suites must rerun" | Session boundaries do not change content. Reuse applicable evidence after proving identity. |
| "The same tree moved to main, so rerun everything" | Verify integration-specific risks and refs; do not retest identical content without a named requirement. |
| "The tree matches, so packaging cannot change" | Branch-sensitive packaging or explicit integration gates still require their targeted checks. |
| "I can see the commits, so they are mine to publish" | Visibility does not prove current-outcome ownership. Inspect the range and stop on ambiguity. |
| "Personal work still needs a merge-or-PR question" | Known personal policy selects verified integration and publication without a redundant menu. |
| "Guidance says fast-forward onto main, so this is personal" | Integration mechanics do not classify a repository or authorize publication. Ask the focused classification question. |
| "The push was rejected, so I should force it" | Remote movement is a stop condition. Investigate; never force-push without explicit authorization. |
| "The push command succeeded, so publication is proven" | Compare the exact local and remote refs before cleanup. |
| "The PR is up, so the worktree is clutter" | Collaborative worktrees remain for review feedback. |
| "Removal refused, but cleanup is authorized" | Cleanup never authorizes destroying unique files. Show them and ask. |
| "This other worktree looks stale" | Clean only the current outcome's project-local owned worktree. |
| "The base is obviously main" | Prove the base from durable context or ask one focused confirmation question. |

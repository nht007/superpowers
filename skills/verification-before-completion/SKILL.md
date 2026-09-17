---
name: verification-before-completion
description: Use when about to claim work is complete, fixed, or passing, before committing or creating PRs
---

# Verification Before Completion

## Overview

**Core principle:** Evidence must apply to the state being claimed.

Fresh evidence means evidence produced after the last relevant change. A turn, session, branch, or
ref change does not make evidence stale when the verified subject and every input material to the
claim are unchanged.

**Violating the letter of this rule is violating the spirit of this rule.**

## The Iron Law

```
NO COMPLETION CLAIMS WITHOUT APPLICABLE VERIFICATION EVIDENCE
```

If you cannot identify what state the evidence covered and why it still applies, run the proving
command now.

## The Evidence Gate

Before claiming any status or expressing satisfaction:

1. **IDENTIFY:** State the exact claim and the subject it concerns.
2. **LOCATE:** Find the command/check, observed result, subject identity, and producer/environment
   for existing evidence.
3. **COMPARE:** Determine whether the subject or an input material to the claim changed afterward.
4. **RUN:** Execute the smallest missing verification when evidence is absent, ambiguous, or stale.
5. **READ:** Inspect full output, exit code, and failure count for every command you run.
6. **REPORT:** State the claim with the evidence's provenance and any relevant limitation.

Skip any step = claiming without proof.

## Evidence Applicability

For repository content, an exact Git tree object is the ordinary content identity. A current
identity and cleanliness check may prove that earlier test evidence still applies across turns,
sessions, or refs:

```bash
git status --porcelain=v1 -uall
git rev-parse HEAD
git rev-parse HEAD^{tree}
```

Applicable evidence identifies:

- the command or behavioral check that ran;
- the observed result;
- the commit/tree or other state it covered;
- the producer/environment when that matters; and
- known limitations.

The transcript, a durable worklog, committed verification record, or another authoritative source
may provide it. Memory that “tests passed” without trustworthy state identity is not evidence.

Tree equality is sufficient only for tree-scoped claims. Run affected verification after a relevant
change to dependencies, lock state, toolchain, runtime, platform, configuration, credentials,
generated state, or another input the claim depends on. Claims about current services, deployments,
remote refs, APIs, databases, or other live state require current checks because that state can
change independently of the repository tree.

Explicit owner, repository, or safety requirements for a particular stage or environment still
apply even when content is unchanged.

## Common Claims

| Claim | Applicable evidence | Not sufficient |
|-------|---------------------|----------------|
| Tests pass on this content | Successful test output tied to the current exact tree and relevant inputs | Run with unknown tree; run before a relevant input changed |
| Linter is clean | Successful linter output tied to the current relevant files/config | Passing tests; output with unknown provenance |
| Build succeeds | Successful build output under the claimed toolchain/environment | Linter passing; build before toolchain change |
| Bug is fixed | Original symptom passes on the current exact state | Code changed; a different test passes |
| Deployment is healthy now | Current health check against that deployment | Tree-scoped test; earlier live check |
| Remote publication succeeded | Current exact remote-ref or service check | Local commit; previous push output alone |
| Agent completed | Inspected diff plus applicable verification of the resulting state | Agent success report alone |
| Requirements are met | Requirement-by-requirement evidence for the current state | Tests passing without coverage mapping |

## Key Patterns

**Exact-tree reuse:**

```
✅ Earlier: full suite passed on commit C / tree T under the current toolchain.
   Now: identity check proves the clean candidate is still tree T and no relevant input changed.
   Claim: "The exact tree T passed the full suite; current identity is unchanged."
❌ "Tests passed before" with no state identity or input check.
```

**Changed input:**

```
✅ Tree T is unchanged, but the runtime changed → rerun the checks that prove runtime compatibility.
❌ Reuse tree-scoped evidence to claim compatibility with an environment it never tested.
```

**Live state:**

```
✅ Query the current remote ref before claiming publication.
❌ Infer current publication from an earlier successful local test or push.
```

## Red Flags - STOP

- “It should still pass” without proving current state identity
- “Tests passed earlier” without commit/tree and relevant-input provenance
- “It is the same code” without a cleanliness or identity check
- Reusing content evidence for a live service, deployment, or remote-state claim
- Ignoring a changed dependency, toolchain, runtime, platform, config, or generated input
- Rerunning the whole suite only because a message, session, branch, or ref changed
- Treating an explicit stage/environment gate as redundant
- Trusting an agent success report without inspecting its result
- Expressing satisfaction before evaluating evidence applicability

## Rationalization Prevention

| Excuse | Reality |
|--------|---------|
| “The previous run is always stale” | Evidence becomes stale after a relevant state/input change, not after a chat boundary. |
| “The tree hash matches, so everything is proved” | Tree identity carries only tree-scoped evidence; environment and live-state claims have other inputs. |
| “It looks unchanged” | Prove identity and cleanliness. |
| “The command is expensive” | Cost does not rescue missing or stale evidence. Run the smallest command that proves the claim. |
| “A new ref needs a new full suite” | A ref name alone does not change content. Verify the ref/integration risk, not identical content again. |
| “The agent said success” | Inspect the result and its subject identity. |
| “Confidence is enough” | Confidence is not evidence. |

## When To Apply

Apply this gate before:

- any variation of a success, correctness, or completion claim;
- committing, publishing, creating a PR, or moving to the next task;
- describing tests, lint, build, deployment, or remote state as passing; and
- accepting delegated work as correct.

The gate requires applicable evidence, not ritual repetition. When applicable evidence already
covers the current state, prove that applicability and carry it forward. When it does not, run the
missing verification before claiming success.

---
name: requesting-code-review
description: Use when completed work has substantial behavioral or integration risk, an explicit review gate applies, or independent judgment would materially improve confidence
---

# Requesting Code Review

Dispatch a code reviewer subagent when independent judgment materially reduces the risk of proceeding. The reviewer gets precisely crafted context for evaluation — never your session's history.

**Core principle:** Scale independent review to risk; keep verification mandatory.

## When to Request Review

| Change state | Action |
|--------------|--------|
| The active workflow, repository policy, or your human partner requires independent review | Request review |
| The change affects security, privacy, credentials, data integrity, migrations, concurrency, externally consumed contracts, or multiple integrated systems | Request review |
| A substantial feature, refactor, or complex bug fix needs judgment beyond deterministic verification | Request review |
| A small mechanical, documentation, or configuration change preserves behavior and contracts, the exact diff has been inspected, and focused verification passes | Proceed without independent review |
| You are stuck or the risk classification remains genuinely uncertain | Request review for a fresh perspective |

Re-review only when findings remain unresolved or later edits create a distinct risk. Merge timing alone does not create a review requirement.

## How to Request

**1. Get git SHAs:**
```bash
BASE_SHA=$(git rev-parse HEAD~1)  # or origin/main
HEAD_SHA=$(git rev-parse HEAD)
```

**2. Dispatch code reviewer subagent:**

Dispatch a `general-purpose` subagent, filling the template at [code-reviewer.md](code-reviewer.md)

**Placeholders:**
- `{DESCRIPTION}` - Brief summary of what you built
- `{PLAN_OR_REQUIREMENTS}` - What it should do
- `{BASE_SHA}` - Starting commit
- `{HEAD_SHA}` - Ending commit

**3. Act on feedback:**
- Fix Critical issues immediately
- Fix Important issues before proceeding
- Note Minor issues for later
- Push back if reviewer is wrong (with reasoning)

## Example

```
[Just completed Task 2: Add verification function]

You: Let me request code review before proceeding.

BASE_SHA=$(git log --oneline | grep "Task 1" | head -1 | awk '{print $1}')
HEAD_SHA=$(git rev-parse HEAD)

[Dispatch code reviewer subagent]
  DESCRIPTION: Added verifyIndex() and repairIndex() with 4 issue types
  PLAN_OR_REQUIREMENTS: Task 2 from docs/superpowers/plans/deployment-plan.md
  BASE_SHA: a7981ec
  HEAD_SHA: 3df7661

[Subagent returns]:
  Strengths: Clean architecture, real tests
  Issues:
    Important: Missing progress indicators
    Minor: Magic number (100) for reporting interval
  Assessment: Ready to proceed

You: [Fix progress indicators]
[Continue to Task 3]
```

## Common Rationalizations

| Excuse | Reality |
|--------|---------|
| "It's about to merge, so it always needs a reviewer" | Merge timing is not a risk signal. Apply the change-state table. |
| "The tests passed, so this security-sensitive change doesn't need review" | Deterministic checks and independent judgment cover different risks. Request review when a risk trigger applies. |
| "This tiny change doesn't need verification either" | Independent review and verification are separate gates. Omitting a reviewer never permits omitting fresh, focused verification. |
| "The reviewer needs my whole session history to understand the change" | Hand it precisely crafted context, never your session's history. That keeps the reviewer on the work product, not your thought process. |

## Red Flags

**Never:**
- Skip review when the workflow or a listed risk trigger requires it
- Dispatch a reviewer solely because the change is about to merge
- Treat proportionate self-inspection as permission to skip verification
- Ignore Critical issues
- Proceed with unfixed Important issues
- Argue with valid technical feedback

**If reviewer wrong:**
- Push back with technical reasoning
- Show code/tests that prove it works
- Request clarification

See template at: [code-reviewer.md](code-reviewer.md)

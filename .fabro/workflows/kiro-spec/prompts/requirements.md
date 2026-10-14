# Kiro Spec Requirements Stage

You are the **requirements** stage of the `kiro-spec` Fabro workflow, running as an agent inside the target repository. The workflow converts GitHub issue #{{ inputs.issue }} into a ready-to-implement Kiro spec delivered as a four-PR stack. The brief is already locked; this stage produces the requirements document only.

## Context

- Workflow state: read `.git/kiro-spec-state.json` (JSON). The `spec` field names the directory `.kiro/specs/<spec>/` — use that exact value. The state file is workflow-owned: read it, never modify it.
- Issue content: `.git/kiro-spec-issue.md`.
- `.kiro/specs/<spec>/brief.md` — the authoritative problem statement, approach, and scope for this spec. Read it first; everything you write must stay inside its scope.

## Repository conventions (read these first)

- `.kiro/settings/templates/specs/requirements.md` — when present, follow its section structure and placeholder conventions exactly; the template wins over the sketch below. Replace every template marker with real content; never leave unfilled double-brace placeholder tokens behind.
- Read the `.kiro/steering/*.md` documents relevant to this feature.
- Read one or two existing `requirements.md` files under `.kiro/specs/` for tone and terminology.

## Your document: `.kiro/specs/<spec>/requirements.md`

Requirements describe WHAT users observe, never HOW it is built. Technology choices, architecture, APIs, data models, and internal ownership belong to the design stage: a criterion that cannot be written without naming a technology belongs in design, not here.

Structure (mirror the template when one exists):

```markdown
# Requirements Document

## Introduction
<1-3 sentences naming the feature and pointing at brief.md — do not restate the brief>

## Boundary Context (only when scope could be misread)
- **In scope**: <delta from the brief's Out of Boundary>
- **Out of scope**: <delta from the brief's Out of Boundary>
- **Adjacent expectations**: <what this feature relies on that it does not own>

## Requirements

### Requirement 1: <area>
**Objective:** As a <role>, I want <capability>, so that <benefit>

#### Acceptance Criteria
1. When <event>, the <system> shall <response>
2. If <trigger>, then the <system> shall <response>
3. While <precondition>, the <system> shall <response>
4. Where <feature is included>, the <system> shall <response>
5. The <system> shall <response>
```

Rules:

- Requirement headings MUST start with a numeric ID ("Requirement 1: ..."). Alphabetic IDs such as "Requirement A" are not allowed.
- Use EARS patterns for every acceptance criterion: one observable behavior per criterion.
- Cover every in-scope behavior from the brief, including user-visible error and edge cases; leave nothing as TBD.
- Keep terminology identical to the brief — the same name for the same thing across all documents.
- No implementation details, no rationalizing tails ("so that boot is not blocked"), no hedged language.
- Boundary Context is a delta from the brief's Out of Boundary, not a repetition of it.

Keep the document under 500 lines. If it does not fit, the feature is too large — narrow it with the human instead of padding.

## Asking a human

When something you need cannot be determined from the issue, the repository, the brief, or `.kiro/steering/`, ask the human with your session's question tool (`AskUserQuestion`, or `request_user_input` on some model profiles). The run pauses until a person answers, and the answers come back as the tool result. Ask at most once per stage: 1-4 questions, 2-4 options each, with enough context in each question to answer without re-reading the brief. Only ask about decisions that change required behavior or scope, and never guess on those. If no human-question tool is available in your session, report BLOCKED instead of guessing.

## Hard constraints

- Write only `.kiro/specs/<spec>/requirements.md`. Never touch `brief.md`, `spec.json`, `design.md`, `tasks.md`, or the workflow state file.
- Do not create git commits, branches, or pushes; the workflow's lock stage owns git.
- Never claim something is verified unless you read the source.

## Final response

Write a short narrative of what you produced, then end with exactly one JSON object as the final content; nothing after it. Keep every value a single-line string.

Success:

{"outcome": "succeeded", "context_updates": {"requirements_status": "READY", "requirements_summary": "<one line describing the requirements>"}}

Blocked:

{"outcome": "failed", "failure_reason": "<one line>", "context_updates": {"requirements_status": "BLOCKED", "stage_failure": "requirements: <what is blocked and what would unblock it>"}}

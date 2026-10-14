# Record a Blocked Kiro Task

The implementation or review stage for spec `{{ inputs.spec }}`, task
`{{ inputs.task }}` did not complete successfully, so this run is recording the
blocker in the task plan and failing the run.

## Steps

1. Determine the blocking reason from the run context. Prefer, in order: `impl_blocker`, then `impl_summary` when `impl_status` is `BLOCKED` or `NEEDS_CONTEXT`, then `review_findings` together with `review_remediation`. If none of those are usable, report that the stage failed without a status report.
2. Open `.kiro/specs/{{ inputs.spec }}/tasks.md` and find the `- [ ] {{ inputs.task }}` entry. Append one indented line directly after that entry's bullet block, before the next task entry:

   `  - _Blocked: <one-line root cause and what would unblock it>_`

   Collapse the reason to a single line, remove newlines, and keep it under 200 characters.
3. Change nothing else in the file. Do not commit.

Respond with a one-sentence summary of the blocker, then end your response with exactly
one JSON object as the final content. Fabro validates it against its routing schema and
this failed outcome is what fails the run.

{"outcome": "failed", "failure_reason": "<one-line root cause>", "context_updates": {"blocked_reason": "<one-line root cause and what would unblock it>"}}

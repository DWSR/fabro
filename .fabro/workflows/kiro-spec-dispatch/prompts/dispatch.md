# Kiro Spec Dispatcher

You are the dispatch stage of the kiro-spec-dispatch workflow. You read the queue
of GitHub issues that are ready for Kiro spec generation, register the child
workflow once, and create one child run per issue. You never generate or edit the
spec yourself, and you never modify the repository.

## Inputs

- Queue file: `.git/kiro-spec-dispatch-queue.json` — `{"repo": "owner/name", "labels": "...", "issues": [{"number", "title", "url"}]}`. It was written by the scan stage.
- Child workflow: `{{ inputs.dispatch_workflow }}` packaged under `.fabro/workflows/{{ inputs.dispatch_workflow }}/` in the central workflows repository `{{ inputs.workflows_repo }}` (ref `{{ inputs.workflows_ref }}` when set).
- Label swap after each successful dispatch: add `{{ inputs.running_label }}`, remove `{{ inputs.ready_label }}`.
- Result file to maintain: `.git/kiro-spec-dispatch-result.json`.

## Procedure

1. Read the queue file with python3. If it is missing or has no issues, fail with a clear message and create nothing.
2. Resolve the child workflow package directory:
   - Prefer `.fabro/workflows/{{ inputs.dispatch_workflow }}/` when it exists in this workspace (project-local override).
   - Otherwise reuse the existing clone at `/tmp/kiro-spec-dispatch-workflows` when present, else run `git clone --depth 1 https://github.com/{{ inputs.workflows_repo }} /tmp/kiro-spec-dispatch-workflows` (append `--branch {{ inputs.workflows_ref }}` when `workflows_ref` is non-empty), and use `/tmp/kiro-spec-dispatch-workflows/.fabro/workflows/{{ inputs.dispatch_workflow }}/`. Keep the clone outside the repository working tree so it is never committed.
   - If neither location yields a `workflow.fabro`, fail naming `workflows_repo` so the operator can fix the input.
3. Register the child workflow version with `fabro_workflow_version_create`:
   - `entrypoint`: `workflow.fabro`
   - `files`: every file in the resolved package directory keyed by package-relative path. The `kiro-spec` package has exactly `workflow.fabro`, `workflow.toml`, `prompts/brief.md`, `prompts/requirements.md`, `prompts/design.md`, and `prompts/tasks.md`. Read each file and supply its text contents.
   - Register at most once per invocation and reuse the returned id for every child.
4. For each issue in queue order, dispatch exactly one child run:
   - Call `fabro_run_create` with a single-item `runs` batch:
     - `workflow_version_id`: the registered id
     - `title`: `{{ inputs.dispatch_workflow }} for <repo>#<number>` using the queue's `repo`
     - `start`: true
     - `args`: `{"inputs": {"issue": "<number>"}, "auto_approve": true, "labels": {"source": "kiro-spec-dispatch", "repo": "<repo>", "issue": "<number>"}}`
     - Always pass `issue` as a JSON string with quotes. A bare JSON number loses trailing zeros and would target the wrong issue.
     - Do NOT set `target` (the child must inherit this run's repository and branch), do NOT set `parent_id` (native children are parented to this run automatically), and do NOT set `environment_id`.
   - Capture the child run id from the structured content of the response (`runs[].run_id`). If it is still ambiguous, resolve it with `fabro_run_search`, filtered by the labels you attached (`repo`, `issue`).
   - Mark the issue with the GitHub API using `GITHUB_TOKEN` from python3: first add `{{ inputs.running_label }}`, then remove `{{ inputs.ready_label }}`. Write this helper once and call it per issue:

```python
# /tmp/kiro-spec-dispatch-label.py — call as: python3 /tmp/kiro-spec-dispatch-label.py <issue_number>
import json, os, sys, urllib.parse, urllib.request

REPO = "<repo>"
RUNNING = "{{ inputs.running_label }}"
READY = "{{ inputs.ready_label }}"
TOKEN = os.environ.get("GITHUB_TOKEN", "")
if not TOKEN:
    sys.exit("GITHUB_TOKEN is not set")

def gh(method, path, body=None):
    req = urllib.request.Request("https://api.github.com" + path, method=method, headers={
        "Authorization": "Bearer %s" % TOKEN,
        "Accept": "application/vnd.github+json",
        "X-GitHub-Api-Version": "2026-03-10",
        "Content-Type": "application/json",
        "User-Agent": "fabro-kiro-spec-dispatch-workflow",
    })
    data = json.dumps(body).encode() if body is not None else None
    with urllib.request.urlopen(req, data=data, timeout=60) as r:
        return r.status

n = sys.argv[1]
gh("POST", "/repos/%s/issues/%s/labels" % (REPO, n), {"labels": [RUNNING]})
gh("DELETE", "/repos/%s/issues/%s/labels/%s" % (REPO, n, urllib.parse.quote(READY, safe="")))
print("kiro-spec-dispatch: labels swapped for %s#%s" % (REPO, n))
```

   - Append the outcome to `.git/kiro-spec-dispatch-result.json` after each issue, preserving earlier entries. Keep it a dict: `{"repo", "version_id", "dispatched": [{"issue", "run_id"}], "failed": [{"issue", "error"}]}`.
   - If creating the run fails for an issue: do not swap its labels, record the failure, and continue with the remaining issues.
   - If the run was created but the label swap fails: record the issue under `dispatched` with a `label_error` field; it may be re-dispatched on the next scan.
5. Do not wait for children: never call `fabro_run_gather`. A host hook on this run approves each pending child automatically; never call `fabro_run_interact` with `approve` yourself (workflow agents are policy-denied).

## Reporting (mandatory)

End your response with exactly one JSON object as the final content; nothing after it.
Keep every value a single-line string; escape double quotes as \" and newlines as \n.

Success (every issue in the queue either dispatched or recorded with an explicit failure):

{"outcome": "succeeded", "context_updates": {"dispatch_result": "success", "dispatched_count": "<n>", "failed_count": "<m>"}}

If any issue failed to dispatch:

{"outcome": "failed", "failure_reason": "<one line>", "context_updates": {"dispatch_result": "failed", "dispatch_failure": "<issues and one-line reasons>"}}

## Rules

- One child run per issue: three issues mean three single-item `fabro_run_create` calls, not one batch.
- Never set `target`, `parent_id`, or `environment_id` on a child run.
- Never modify repository files; the only files you may write are under `.git/` and `/tmp`.
- Never touch `.kiro/specs/`.
- Never call `fabro_run_gather`; the run finishes as soon as dispatch is done. The child runs outlive it.

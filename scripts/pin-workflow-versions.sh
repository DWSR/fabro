#!/usr/bin/env bash
# Pin child workflow versions for the dispatch workflows.
#
# The dispatch and kiro-impl dispatchers create children (kiro-spec,
# kiro-task, oneshot, dependabot) whose packages used to be re-emitted inline
# by an agent through fabro_workflow_version_create (a ~40 KiB JSON-escaping
# task that has caused multi-minute agent stalls). The dispatchers now read a
# pre-registered, immutable version id from a server-owned variable instead.
#
# Run this script on the Fabro server host (fabro CLI on PATH):
#   scripts/pin-workflow-versions.sh
#
# Re-run it after changing anything under .fabro/workflows/kiro-spec/,
# .fabro/workflows/kiro-task/, .fabro/workflows/oneshot/, or
# .fabro/workflows/dependabot/, then re-register the dispatcher packages
# themselves (fabro run/whatever trigger) so the new scripts take effect.
# Registration is content-addressed: unchanged packages pin the same id.
set -euo pipefail

cd "$(dirname "$0")/.."

command -v fabro >/dev/null || { echo "error: fabro not on PATH" >&2; exit 1; }
command -v jq >/dev/null || { echo "error: jq not on PATH" >&2; exit 1; }

pin() {
  local pkg="$1" var="$2" run version
  run=$(fabro create "$pkg" --json 2>/dev/null | jq -r '.run_id')
  [ -n "$run" ] || { echo "error: failed to create registration run for $pkg" >&2; exit 1; }
  version=$(fabro inspect "$run" --json | jq -r '.[0].run_spec.workflow_version_id')
  case "$version" in
    ''|null) echo "error: failed to read workflow_version_id for $pkg" >&2; exit 1 ;;
  esac
  fabro variable set "$var" "$version" \
    --description "Pinned workflow-version id for $pkg (refresh: scripts/pin-workflow-versions.sh)"
  fabro rm --force "$run" >/dev/null 2>&1
  echo "pinned $var = $version"
}

pin .fabro/workflows/kiro-spec kiro_spec_workflow_version
pin .fabro/workflows/kiro-task kiro_task_workflow_version
pin .fabro/workflows/oneshot oneshot_workflow_version
pin .fabro/workflows/dependabot dependabot_workflow_version

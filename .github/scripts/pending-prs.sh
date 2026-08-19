#!/usr/bin/env bash
#
# Names the pull requests whose entries are still pending, so the resolver can
# be handed the list rather than called around a loop.
#
# The unit of work is a *range*: every merge since the previous assembly, not
# just the merge that triggered this run. That is what makes assembly
# self-healing — a failed or skipped run leaves its entries pending, and the
# next run collects them.
#
# Writes `prs` and `count` to GITHUB_OUTPUT.

[ "${RUNNER_DEBUG}" == 1 ] && set -xv
set -euo pipefail

readonly assembly_prefix="chore: assemble CHANGELOG "

# The previous assembly commit bounds the range: everything it covered is
# behind it, everything pending is ahead.
#
# This used to be the last release tag, which worked only while assembly was
# also what created the tag. Assembly no longer does — the build owns the tag,
# the Release and the artifact ([DQ-001]) — and a tag written by a later,
# separate job is the wrong thing to bound this range with. A build that fails
# after assembly succeeds would leave no tag, and the next run would reach back
# over merges already assembled: entries collected twice where the pull request
# used the body route, and a hard failure where it used the file route and the
# file is already consumed.
#
# The tag remains the fallback, and that is what makes the first run correct. A
# repository adopting this model has no assembly commit yet, and without the
# fallback the first range would be the entire history.
#
# --first-parent is not a detail. Without it the search walks commits from
# merged pull-request branches too, so any commit anywhere in history whose
# subject happens to start with the prefix could be chosen as the boundary —
# shrinking the range and silently skipping merges that still need assembling.
previous="$(git log --first-parent --format='%H' --grep="^${assembly_prefix}" --max-count=1 HEAD 2>/dev/null || true)"
if [ -z "${previous}" ]; then
  previous="$(git describe --tags --abbrev=0 2>/dev/null || true)"
fi

if [ -n "${previous}" ]; then
  readonly range="${previous}..HEAD"
else
  readonly range="HEAD"
fi
echo "::notice::assembling range ${range}"

# --first-parent here for the same reason as above, and it is not theoretical:
# `git log --merges` walks every reachable commit, so a merge made *inside* a
# pull-request branch is listed too. Measured against this repository's history
# on 2026-08-19: 175 reachable merges, 140 of them on the mainline, and two of
# the remaining 35 carry a `Merge pull request #N` subject. Those two would be
# collected as pending entries for pull requests that never merged here.
mapfile -t merges < <(git log --first-parent --merges --format='%H' "${range}")

prs=()
for merge in "${merges[@]}"; do
  pr="$(git log -1 --format='%s' "${merge}" | sed -nE 's|^Merge pull request #([0-9]+) from .*|\1|p')"
  if [ -z "${pr}" ]; then
    echo "::warning::${merge} is a merge commit with no pull-request number in its subject; skipped"
    continue
  fi
  prs+=("${pr}")
done

if [ "${#prs[@]}" -eq 0 ]; then
  echo "::notice::no merges pending; nothing to assemble"
fi

{
  echo "prs=${prs[*]:-}"
  echo "count=${#prs[@]}"
} >>"${GITHUB_OUTPUT}"

#!/usr/bin/env bash
#
# Fails when a pull request must not merge yet, for a reason GitHub will not
# enforce on its own.
#
#   - It is a draft. GitHub does not eject a queued pull request converted back
#     to draft: measured 2026-08-06, it stayed at position 1, ran every check,
#     and merged, after which assembly cut a release from it. Failing here is
#     also the eviction mechanism — the queue ejects an entry whose required
#     checks fail, which is the lever that drafting does not pull.
#
#   - It is marked as a feature build. The marker makes every push publish a
#     prerelease, so it is a branch still being worked on; and merged, it would
#     survive onto main and keep publishing.
#
# The marker is not parsed here. It arrives in MARKER, resolved once by
# synthesize-changelog-entry, so this gate and the build cannot disagree about
# whether a branch is marked. Parsing it separately is what made this check
# blind to a marker written in a pull-request body.
#
# Usage: check-mergeable.sh <pr-number>   (MARKER in the environment)

[ "${RUNNER_DEBUG}" == 1 ] && set -xv
set -euo pipefail

readonly pr="${1:?usage: check-mergeable.sh <pr-number>}"
readonly marker="${MARKER:-}"

if [ "$(gh pr view "${pr}" --repo "${GITHUB_REPOSITORY}" --json isDraft --jq '.isDraft')" == "true" ]; then
  echo "::error::#${pr} is a draft; it must not merge"
  exit 1
fi

if [ -n "${marker}" ]; then
  echo "::error::#${pr} is marked as a feature build (${marker}); remove the marker before merging"
  exit 1
fi

echo "::notice::#${pr} is neither a draft nor a marked feature build"

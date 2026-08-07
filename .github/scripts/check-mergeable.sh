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
#     prerelease to dev, so it is a branch still being worked on; and merged, it
#     would survive onto main and keep publishing.
#
# Usage: check-mergeable.sh <pr-number>

[ "${RUNNER_DEBUG}" == 1 ] && set -xv
set -euo pipefail

readonly pr="${1:?usage: check-mergeable.sh <pr-number>}"
readonly changelog_dir=".changelog"

if [ "$(gh pr view "${pr}" --repo "${GITHUB_REPOSITORY}" --json isDraft --jq '.isDraft')" == "true" ]; then
  echo "::error::#${pr} is a draft; it must not merge"
  exit 1
fi

marked="$(
  gh pr diff "${pr}" --repo "${GITHUB_REPOSITORY}" --name-only |
    { grep -E "^${changelog_dir}/.+\.md$" || true; } |
    { grep -v "^${changelog_dir}/README\.md$" || true; } |
    while IFS= read -r file; do
      [ -r "${file}" ] || continue
      [ "$(head -n1 "${file}")" == "---" ] || continue
      sed -n '2,/^---$/p' "${file}" | { grep -E '^feature-build:' || true; }
    done
)"
readonly marked

if [ -n "${marked}" ]; then
  echo "::error::#${pr} is marked as a feature build (${marked}); remove the marker before merging"
  exit 1
fi

echo "::notice::#${pr} is neither a draft nor a marked feature build"

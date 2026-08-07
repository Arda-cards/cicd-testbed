#!/usr/bin/env bash
#
# Fails unless the pull request carries exactly one valid changelog entry and
# leaves CHANGELOG.md alone.
#
# The entry is composed into a candidate release block and handed to the same
# validator that guards CHANGELOG.md, so a malformed category or heading is
# refused here rather than after merge — when the only remedy is a follow-up
# commit on main.
#
# Usage: check-changelog.sh <pr-number>

[ "${RUNNER_DEBUG}" == 1 ] && set -xv
set -euo pipefail

readonly pr="${1:?usage: check-changelog.sh <pr-number>}"
readonly changelog="CHANGELOG.md"
readonly changemap=".github/clq/changemap.json"

# --- CHANGELOG.md is written by assembly, not by hand -----------------------

if gh pr diff "${pr}" --repo "${GITHUB_REPOSITORY}" --name-only | grep -qx "${changelog}"; then
  # The escape hatch is for correcting history, not for routine use.
  if gh pr view "${pr}" --repo "${GITHUB_REPOSITORY}" --json labels --jq '.labels[].name' |
      grep -qx "manual-changelog"; then
    echo "::warning::${changelog} edited under the manual-changelog label"
  else
    echo "::error::this pull request edits ${changelog}; the entry belongs in the pull-request body or in .changelog/"
    exit 1
  fi
fi

# --- exactly one entry, by exactly one route --------------------------------

entry="$(.github/scripts/changelog-entry.sh "${pr}")"
readonly entry

work="$(mktemp -d)"
readonly work
{
  echo "# changelog"
  echo
  echo "## [9999.0.0] - 2999-01-01"
  echo
  printf '%s\n' "${entry}"
} >"${work}/CHANGELOG.md"

if ! docker run --rm \
    --volume "${work}/CHANGELOG.md:/home/CHANGELOG.md:ro" \
    --volume "${PWD}/${changemap}:/home/changemap.json:ro" \
    denisa/clq:1.8.28 -changeMap /home/changemap.json -release /home/CHANGELOG.md; then
  echo "::error::the changelog entry is not valid; it must use the categories in ${changemap}"
  {
    echo "## Rejected entry"
    echo '```markdown'
    printf '%s\n' "${entry}"
    echo '```'
  } >>"${GITHUB_STEP_SUMMARY}"
  exit 1
fi

{
  echo "## Changelog entry"
  printf '%s\n' "${entry}"
} >>"${GITHUB_STEP_SUMMARY}"

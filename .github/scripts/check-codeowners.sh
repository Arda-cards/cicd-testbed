#!/usr/bin/env bash
#
# Fails when CODEOWNERS does not resolve.
#
# With `required_approving_review_count: 0` and `require_code_owner_review:
# true`, CODEOWNERS *is* the review policy — and an unresolvable owner does not
# make the rule stricter or even noisier. It makes it vacuous: the rule still
# claims to require code-owner review, and the pull request merges with no
# review at all.
#
# Measured 2026-08-06. The same pull request, the same rulesets, differing only
# in whether the owning team had repository access:
#
#   team lacked access   ->  CLEAN, zero reviews, mergeable
#   team granted access  ->  BLOCKED, review requested
#
# Nothing on the pull request distinguishes those. A renamed team, a permission
# change, or a typo turns review off and says nothing. This is what says it.

[ "${RUNNER_DEBUG}" == 1 ] && set -xv
set -euo pipefail

errors="$(gh api "repos/${GITHUB_REPOSITORY}/codeowners/errors" --jq '.errors // []')"
readonly errors
count="$(jq 'length' <<<"${errors}")"
readonly count

if [ "${count}" -eq 0 ]; then
  echo "::notice::CODEOWNERS resolves"
  exit 0
fi

echo "::error::CODEOWNERS has ${count} unresolved owner(s); code-owner review is not being enforced"
jq -r '.[] | "::error file=.github/CODEOWNERS,line=\(.line)::\(.message)"' <<<"${errors}"
{
  echo "# CODEOWNERS does not resolve"
  echo
  echo "Code-owner review is silently not enforced while this is true."
  echo
  jq -r '.[] | "- line \(.line): \(.message)"' <<<"${errors}"
} >>"${GITHUB_STEP_SUMMARY}"
exit 1

#!/usr/bin/env bash
#
# Resolves the changelog entry for a pull request and prints it on stdout.
#
# Two authoring routes are allowed and exactly one must be used:
#
#   - a `## CHANGELOG` section in the pull-request body, or in a later comment
#     by the author or an assignee, the most recent winning; or
#   - a single file under `.changelog/`, named by its author.
#
# Both present is an error, and so is neither: silence is not a valid entry,
# because a release note nobody wrote is a release note nobody reviewed.
#
# Usage: changelog-entry.sh <pr-number>

[ "${RUNNER_DEBUG}" == 1 ] && set -xv
set -euo pipefail

readonly pr="${1:?usage: changelog-entry.sh <pr-number>}"
readonly changelog_dir=".changelog"

# stderr, not stdout: every caller reads the entry through command substitution,
# which would capture the diagnosis and leave the author a bare exit code.
fail() {
  echo "::error::${1}" >&2
  exit 1
}

# Everything under a `## CHANGELOG` heading, up to the next heading of the same
# level or the end of the text.
extract_section() {
  awk '
    /^##[[:space:]]+CHANGELOG[[:space:]]*$/ { capturing = 1; next }
    capturing && /^##[[:space:]]/           { capturing = 0 }
    capturing                               { print }
  '
}

blank() { [ -z "$(tr -d '[:space:]' <<<"${1}")" ]; }

# --- route 1: a file under .changelog/ --------------------------------------

mapfile -t files < <(
  gh pr diff "${pr}" --name-only |
    { grep -E "^${changelog_dir}/.+\.md$" || true; } |
    { grep -v "^${changelog_dir}/README\.md$" || true; }
)

if [ "${#files[@]}" -gt 1 ]; then
  fail "a pull request carries at most one ${changelog_dir}/ file, found ${#files[@]}: ${files[*]}"
fi

file_entry=''
if [ "${#files[@]}" -eq 1 ] && [ -r "${files[0]}" ]; then
  # Frontmatter is configuration for the pipeline rather than release notes.
  # Strip it here so it can never reach CHANGELOG.md.
  if [ "$(head -n1 "${files[0]}")" == "---" ]; then
    file_entry="$(sed '1,/^---$/d' "${files[0]}" | sed '1{/^$/d}')"
  else
    file_entry="$(cat "${files[0]}")"
  fi
fi

# --- route 2: the pull-request body, superseded by a later owner comment ----

meta="$(gh pr view "${pr}" --json body,author,assignees)"
readonly meta
body_entry="$(jq -r '.body // ""' <<<"${meta}" | extract_section)"

# Anyone may comment on a pull request; only those accountable for the change
# may rewrite its release note.
owners="$(jq -c '[.author.login] + [.assignees[].login]' <<<"${meta}")"
readonly owners

comment_entry=''
while IFS= read -r encoded; do
  candidate="$(base64 --decode <<<"${encoded}" | extract_section)"
  if ! blank "${candidate}"; then
    comment_entry="${candidate}"
    break
  fi
done < <(
  gh pr view "${pr}" --json comments |
    jq -r --argjson owners "${owners}" '
      [.comments[] | select(.author.login as $a | $owners | index($a))]
      | reverse | .[].body | @base64
    '
)

readonly pr_entry="${comment_entry:-${body_entry}}"

# --- exactly one -------------------------------------------------------------

if ! blank "${file_entry}" && ! blank "${pr_entry}"; then
  fail "both a ${changelog_dir}/ file and a ## CHANGELOG section are present; use one route, not both"
fi

if blank "${file_entry}" && blank "${pr_entry}"; then
  fail "no changelog entry found: add a ## CHANGELOG section to the pull-request body, or a file under ${changelog_dir}/"
fi

if blank "${file_entry}"; then
  echo "::notice::changelog entry read from the pull request" >&2
  printf '%s\n' "${pr_entry}"
else
  echo "::notice::changelog entry read from ${files[0]}" >&2
  printf '%s\n' "${file_entry}"
fi

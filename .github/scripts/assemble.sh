#!/usr/bin/env bash
#
# Composes one release block from every merge since the previous assembly and
# commits it. It does not tag and does not create a Release.
#
# In this model CHANGELOG.md *is* the build-time version source, so the build
# derives the version, cuts the tag and publishes. Assembly writing the file and
# also tagging is two components claiming the same job: when both ran for real
# on 2026-08-18, assembly tagged v8.0.0 and the build then failed on the tag it
# could not create, leaving a published Release with no artifact behind it.
#
# The range is the point. Taking "every merge since the last assembly commit"
# rather than "the merge that triggered this run" means a failed run loses
# nothing: its entries are still pending, and the next run collects them. It
# also means a batch of pull requests merged together produces one release
# rather than racing to produce several.

[ "${RUNNER_DEBUG}" == 1 ] && set -xv
set -euo pipefail

readonly changelog="CHANGELOG.md"
readonly changemap=".github/clq/changemap.json"
readonly changelog_dir=".changelog"
readonly assembly_prefix="chore: assemble CHANGELOG "

# Reads one value out of a GITHUB_OUTPUT-format file, plain or heredoc-quoted.
# Written generically so it does not depend on which delimiter the producer
# chose.
read_output() {
  awk -v key="$2" '
    $0 ~ "^" key "<<"            { delim = substr($0, length(key) + 3); inside = 1; next }
    inside && $0 == delim        { inside = 0; next }
    inside                       { print; next }
    index($0, key "=") == 1      { print substr($0, length(key) + 2) }
  ' "$1"
}

# synthesize-changelog-entry is a composite action, but assembly needs it once
# per merged pull request rather than once per job, so it calls the script the
# action wraps. The workflow checks the component out at .synthesize/.
resolve_entry() {
  local out
  out="$(mktemp)"
  # A range can cover many merges, so the file goes when the function does
  # rather than accumulating one per pull request.
  trap 'rm -f "${out}"' RETURN
  if ! GITHUB_OUTPUT="${out}" PR="${1}" CHANGELOG_DIR="${changelog_dir}" REQUIRE_ENTRY=true \
      .synthesize/synthesize.sh >&2; then
    return 1
  fi
  read_output "${out}" entry
}

clq() {
  docker run --rm \
    --volume "${PWD}/${1}:/home/CHANGELOG.md:ro" \
    --volume "${PWD}/${changemap}:/home/changemap.json:ro" \
    denisa/clq:1.8.28 -changeMap /home/changemap.json "${@:2}" /home/CHANGELOG.md
}

# --- the range ---------------------------------------------------------------

# Assembly's own previous commit bounds the range. The tag was the right
# boundary only while assembly was what created it; now that the build owns
# tagging, a build failing after a successful assembly leaves no tag, and the
# next run would reach back over merges it had already covered — collecting an
# entry twice where the pull request used the body route, and failing outright
# where it used the file route and the file was already consumed.
#
# --first-parent keeps this on the mainline: a plain --grep walks every
# reachable commit, including assembly commits on branches that were merged in.
previous="$(git log --first-parent --format='%H' --grep="^${assembly_prefix}" --max-count=1 HEAD 2>/dev/null || true)"

# The tag remains the fallback, and that is what keeps the first run correct: a
# repository adopting this model has no assembly commit yet, so without it the
# first range would be the entire history — including merges that predate the
# model and have no entry to collect.
if [ -z "${previous}" ]; then
  previous="$(git describe --tags --abbrev=0 2>/dev/null || true)"
fi

if [ -n "${previous}" ]; then
  readonly range="${previous}..HEAD"
else
  readonly range="HEAD"
fi
echo "::notice::assembling range ${range}"

mapfile -t merges < <(git log --merges --format='%H' "${range}")

if [ "${#merges[@]}" -eq 0 ]; then
  echo "::notice::no merges pending; nothing to assemble"
  exit 0
fi

# --- collect one entry per merged pull request -------------------------------

entries=''
prs=()
for merge in "${merges[@]}"; do
  pr="$(git log -1 --format='%s' "${merge}" | sed -nE 's|^Merge pull request #([0-9]+) from .*|\1|p')"
  if [ -z "${pr}" ]; then
    echo "::warning::${merge} is a merge commit with no pull-request number in its subject; skipped"
    continue
  fi

  echo "::notice::collecting #${pr}"
  if ! entry="$(resolve_entry "${pr}")"; then
    echo "::error::#${pr} has no resolvable changelog entry; it should not have merged"
    exit 1
  fi
  entries+="${entry}"$'\n'
  prs+=("#${pr}")
done

if [ -z "$(tr -d '[:space:]' <<<"${entries}")" ]; then
  echo "::notice::no entries to assemble"
  exit 0
fi

# --- merge the entries by category -------------------------------------------

# Bullets from several pull requests land under one heading each, so a release
# reads as a description of the release rather than as a list of pull requests.
merged="$(
  printf '%s' "${entries}" | awk '
    /^###[[:space:]]/ { heading = $0; sub(/[[:space:]]+$/, "", heading); next }
    /^[[:space:]]*$/  { next }
    heading != ""     { bullets[heading] = bullets[heading] $0 "\n" }
    END {
      order["### Changed"] = 1; order["### Removed"] = 2
      order["### Added"] = 3;   order["### Deprecated"] = 4
      order["### Fixed"] = 5;   order["### Security"] = 6
      for (rank = 1; rank <= 6; rank++)
        for (h in bullets)
          if (order[h] == rank) printf "%s\n\n%s\n", h, bullets[h]
    }
  '
)"
readonly merged

# --- compose, validate, commit ----------------------------------------------

work="$(mktemp -d)"
{
  head -n "$(($(grep -n '^## \[' "${changelog}" | head -1 | cut -d: -f1) - 1))" "${changelog}"
  echo "## [0.0.0] - $(git log -1 --format=%cs HEAD)"
  echo
  printf '%s\n' "${merged}"
  # Command substitution strips trailing newlines, so the blank line that
  # separates this block from the release below it has to be put back. Without
  # it the composed entry runs straight into the next `## [` heading — valid
  # enough for clq to accept, and wrong in a file people read.
  echo
  tail -n +"$(grep -n '^## \[' "${changelog}" | head -1 | cut -d: -f1)" "${changelog}"
} >"${work}/candidate.md"

# clq computes the version from the categories present, so the placeholder above
# exists only to give it a well-formed document to read. The author never picks
# a version; the change kinds decide it.
version="$(clq "${changelog}" -query 'releases[0].version')"
readonly version
next="$(
  printf '%s\n' "${merged}" | awk -v current="${version}" '
    /^### (Changed|Removed)/    { bump = 3 }
    /^### (Added|Deprecated)/   { if (bump < 2) bump = 2 }
    /^### (Fixed|Security)/     { if (bump < 1) bump = 1 }
    END {
      split(current, v, ".")
      if (bump == 3) printf "%d.0.0\n", v[1] + 1
      else if (bump == 2) printf "%d.%d.0\n", v[1], v[2] + 1
      else printf "%d.%d.%d\n", v[1], v[2], v[3] + 1
    }
  '
)"
readonly next

sed -i "s|^## \[0\.0\.0\] - |## [${next}] - |" "${work}/candidate.md"
cp "${work}/candidate.md" "${changelog}"

if ! clq "${changelog}" -release >/dev/null; then
  echo "::error::the assembled CHANGELOG.md is not valid"
  exit 1
fi
echo "::notice::assembled ${next} from ${prs[*]}"

# The pending entries are consumed, not archived: main does not keep a
# .changelog file, so a stale one can never be assembled twice. The merge
# commit carries it until this commit removes it.
if compgen -G "${changelog_dir}/*.md" >/dev/null; then
  find "${changelog_dir}" -name '*.md' ! -name 'README.md' -delete
fi

git config user.name "arda-changelog-bot[bot]"
git config user.email "arda-changelog-bot[bot]@users.noreply.github.com"
git add "${changelog}" "${changelog_dir}"
git commit -m "${assembly_prefix}${next}

Covers ${prs[*]}."
# main can advance while this runs — a merge landing between the checkout and
# the push makes it a non-fast-forward. Rebase onto whatever arrived and try
# again rather than leaving the release unwritten. Concurrency serialises
# assembly runs, so the only thing that can have moved is a merge, and rebasing
# a changelog prepend over one is what git is good at.
for attempt in 1 2 3; do
  if git push origin HEAD:main; then
    break
  fi
  if [ "${attempt}" -eq 3 ]; then
    echo "::error::main moved under this assembly three times; the entries stay pending for the next run"
    exit 1
  fi
  echo "::warning::main advanced; rebasing and retrying (attempt ${attempt})"
  git fetch origin main
  if ! git rebase origin/main; then
    git rebase --abort || true
    echo "::error::could not rebase the assembly onto main; the entries stay pending for the next run"
    exit 1
  fi
done

# No tag, and no Release. The build derives the version from the file this
# commit just wrote, and publishing is its job alone.
echo "::notice::${next} written; the build publishes it"

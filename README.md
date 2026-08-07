# cicd-testbed

Two things at once, and they support each other:

1. **A reference implementation** of Arda's [Queued CI/CD](https://arda-cards.github.io/documentation/current-system/oam/configuration/deployment/queued-cicd/)
   model — merge queue, changelog entries outside `CHANGELOG.md`, post-merge
   assembly, ownership-based review. Complete, and small enough to read in one
   sitting. Copy from here when adopting the model in a new repository.
2. **A place to answer questions about the platform** — ruleset composition,
   merge-queue semantics, bypass actors, event payloads — without experimenting
   on a repository that ships anything.

Nothing here is deployed and nothing depends on it. Break it freely.

## Why it exists

Questions like *"does a bypass on one ruleset let an entry into the queue?"*
have documented answers that do not always match observed behaviour, and the
honest way to settle them is to try. Trying them on `operations` means enabling
a merge queue on a production-bearing repository before knowing the semantics,
and paying minutes per iteration for a real Gradle build.

Here the checks are synthetic, so an experiment costs seconds and its outcome is
chosen rather than coaxed.

Being a working implementation is what keeps it honest: an experiment runs
against the same gate, the same scripts, and the same ruleset shape a real
adopter uses, so an answer found here transfers.

## What is in it

### The model

| Path | What it is |
|---|---|
| `.github/workflows/merge-eligibility.yaml` | The single required gate. Resolves the pull request once — including out of the `gh-readonly-queue/main/pr-N-<sha>` ref — then runs the three assertions below. Not draft-gated, and it re-evaluates on `merge_group` rather than passing through. |
| `.github/scripts/check-codeowners.sh` | Fails when CODEOWNERS does not resolve, because an unresolvable owner turns code-owner review off *silently* rather than making it stricter. |
| `.github/scripts/check-mergeable.sh` | Fails on a draft, or on a branch marked as a feature build. GitHub does not eject a queued pull request converted to draft; failing a required check is the only lever that does. |
| `.github/scripts/check-changelog.sh` | Rejects an edit to `CHANGELOG.md`, then validates the resolved entry with the same `clq` that guards the real file. |
| `.github/scripts/changelog-entry.sh` | Resolves the entry from exactly one of the two routes — the pull-request body (or a later author/assignee comment) or a file under `.changelog/`. Shared with assembly. |
| `.github/workflows/changelog-assembly.yaml` | Post-merge. Runs `assemble.sh` as `arda-changelog-bot`, and re-checks CODEOWNERS at the only other moment that assertion can be made. |
| `.github/scripts/assemble.sh` | Composes one release block from **every merge since the last release tag** — a range, not the triggering commit — then commits, tags, and creates the Release. The range is what makes a failed run harmless. |
| `.github/workflows/build.yaml` | A synthetic build that refuses to publish unless it is standing on an assembly commit, and asserts that the version it derives equals the one assembly wrote. That single assertion is the backend variant's whole point. |
| `.github/CODEOWNERS` | Every path owned, including `.github/` itself — otherwise a pull request can rewrite the gate that is gating it. |

Note the version-source inversion this repository models: `CHANGELOG.md` is the
build's *input*, so assembly writes the release block and stops, and the build
that follows reads the version back out and owns the tag. In `documentation` and
`arda-frontend-app` it is the other way around.

### The instruments

`.github/workflows/gate.yaml` publishes two checks, `gate (a)` and `gate (b)`.
Each reads its outcome from a file:

```
.testbed/a     →  "pass 0"
.testbed/b     →  "fail 90"
```

Format is `<pass|fail> <seconds>`. Edit the file in a pull request to make that
check pass slowly, fail fast, or whatever the experiment needs. A missing file
means `pass 0`.

`.github/workflows/context.yaml` dumps the event payload — refs, base refs, and
what `gh ruleset check` returns for each — into the job summary. It runs on
`pull_request`, `merge_group`, and `push`, so the same question can be asked of
all three.

`.github/workflows/qualify.yaml` runs `qualify-build-action` and reports what it
classified. Between experiments it tracks the released `@v2`; during one it can
point at a work branch, which is the capability `operations` does not have —
a change to the shared action can be watched under a real merge queue before it
is published to the repositories that consume it.

## Findings

Record what each experiment established, so the repository accumulates answers
rather than just configuration. Cite the run.

| Date | Question | Answer | Evidence |
|---|---|---|---|
| 2026-08-06 | What names the destination branch on a `merge_group` event? | `github.event.merge_group.base_ref`, as a **full ref** (`refs/heads/main`). `github.base_ref` is empty and `github.ref_name` is the queue branch, so neither is usable. Strip `refs/heads/` before passing it to `gh ruleset check`. | run [31132061181](https://github.com/Arda-cards/cicd-testbed/actions/runs/31132061181) |
| 2026-08-06 | Does a ruleset apply to the merge-queue ref? | No. `gh ruleset check` reports `0 rules apply` for `gh-readonly-queue/main/pr-…` and `5 rules apply` for `main` in the same run. A probe that uses `ref_name` on a queued build therefore concludes the branch is unprotected. | run [31132061181](https://github.com/Arda-cards/cicd-testbed/actions/runs/31132061181) |
| 2026-08-06 | Do two rulesets' `pull_request` rules compose? | Yes, to the stricter of the two, and bypass is evaluated per ruleset. Both rules appeared on `main` simultaneously — one requiring zero approvals, the other adding `require_code_owner_review` — and the pull request was blocked by the second while the first required nothing. | PR #6 |
| 2026-08-06 | Does an unresolvable CODEOWNERS make review stricter, or vacuous? | **Vacuous.** The same pull request under the same rulesets: with the owning team lacking repository access it was `CLEAN`, zero reviews, mergeable; with access granted it was `BLOCKED` with review requested. The ruleset advertises `require_code_owner_review: true` in both states and nothing on the pull request distinguishes them. `repos/{owner}/{repo}/codeowners/errors` is the only surface that reports it. Note CODEOWNERS needs **direct** repository access — inherited through a parent team does not count. | PR #6 |
| 2026-08-06 | Does converting a queued pull request back to draft eject it? | **No.** It stayed at position 1, ran every check, and merged with `isDraft: true`, after which assembly cut a release from it. Failing a required check *is* the eviction mechanism; drafting is not. | PR #11 |
| 2026-08-06 | Can a bypass actor waive code-owner review? | No, by either path. `enqueuePullRequest` refuses a pull request awaiting code-owner review regardless of the caller's bypass mode — tried with both `pull_request` and `always`. A direct merge is refused by the merge-queue rule of a ruleset the actor does not also bypass. The second refusal is reassuring in isolation: bypass is properly scoped, so a waiver could never have skipped the queue. | PR #12, #15 |
| 2026-08-06 | Does `gh pr merge` enqueue on a queue-enabled repo? | Yes, but it prints only `The merge strategy for main is set by the merge queue` and exits without confirming. The entry is created; `enqueuePullRequest` afterwards returns `Pull request is already in the queue`. The repository also needs `allow_auto_merge` set. | PR #1 |
| 2026-08-07 | What does `qualify-build-action` require of a pull request? | Exactly one new `CHANGELOG.md` version on top of the base — otherwise `clq-action` fails with `This pull-request introduces more than one new version…`. Under the queued model a pull request introduces none, so `validate_against_base: "false"` is required. The guarantee is not lost: the gate refuses any edit to `CHANGELOG.md` at all, which is stricter. | run [31134700926](https://github.com/Arda-cards/cicd-testbed/actions/runs/31134700926) |
| 2026-08-07 | What happens when a required check pins a deleted ref? | The check cannot resolve the action, fails at `Set up job`, and the queue silently drops the entry — the pull request goes back to `OPEN` with no obvious cause on its page. A work-branch pin in a required workflow outlives the branch. | run [31219114571](https://github.com/Arda-cards/cicd-testbed/actions/runs/31219114571) |

## Related

- [Queued CI/CD](https://arda-cards.github.io/documentation/current-system/oam/configuration/deployment/queued-cicd/)
  — the model this implements.
- [Backend PR Process](https://arda-cards.github.io/documentation/process/craft/deployment-and-release/backend-pr-process/)
  — the contributor how-to for repositories running this variant.
- [Queued CI/CD Adoption](https://arda-cards.github.io/documentation/roadmap/engineering/ci-cd/queued-cicd-adoption/)
  — the project this was built for (PDEV-1408), with the design and decision log.

---

__________
Copyright: (c) Arda Systems 2025-2026, All rights reserved

# cicd-testbed

A repository for answering questions about GitHub's CI/CD platform behaviour —
ruleset composition, merge-queue semantics, bypass actors, event payloads —
without experimenting on a repository that ships anything.

Nothing here is deployed and nothing depends on it. Break it freely.

## Why it exists

Questions like *"does a bypass on one ruleset let an entry into the queue?"*
have documented answers that do not always match observed behaviour, and the
honest way to settle them is to try. Trying them on `operations` means enabling
a merge queue on a production-bearing repository before knowing the semantics,
and paying 18–27 minutes per iteration.

Here the checks are synthetic, so an experiment costs seconds and its outcome
is chosen rather than coaxed.

## How it works

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

## Findings

Record what each experiment established, so the repository accumulates answers
rather than just configuration. Cite the run.

| Date | Question | Answer | Evidence |
|---|---|---|---|
| 2026-08-06 | What names the destination branch on a `merge_group` event? | `github.event.merge_group.base_ref`, as a **full ref** (`refs/heads/main`). `github.base_ref` is empty and `github.ref_name` is the queue branch, so neither is usable. Strip `refs/heads/` before passing it to `gh ruleset check`. | run [31132061181](https://github.com/Arda-cards/cicd-testbed/actions/runs/31132061181) |
| 2026-08-06 | Does a ruleset apply to the merge-queue ref? | No. `gh ruleset check` reports `0 rules apply` for `gh-readonly-queue/main/pr-…` and `5 rules apply` for `main` in the same run. A probe that uses `ref_name` on a queued build therefore concludes the branch is unprotected. | run [31132061181](https://github.com/Arda-cards/cicd-testbed/actions/runs/31132061181) |
| 2026-08-06 | Does `gh pr merge` enqueue on a queue-enabled repo? | Yes, but it prints only `The merge strategy for main is set by the merge queue` and exits without confirming. The entry is created; `enqueuePullRequest` afterwards returns `Pull request is already in the queue`. The repository also needs `allow_auto_merge` set. | PR #1 |

## Related

- [Queued CI/CD Adoption](https://arda-cards.github.io/documentation/roadmap/engineering/ci-cd/queued-cicd-adoption/)
  — the project this was built for (PDEV-1408).

---

__________
Copyright: (c) Arda Systems 2025-2026, All rights reserved

<!-- experiment: merge_group payload shape -->

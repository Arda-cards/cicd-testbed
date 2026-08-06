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
| | | | |

## Related

- [Queued CI/CD Adoption](https://arda-cards.github.io/documentation/roadmap/engineering/ci-cd/queued-cicd-adoption/)
  — the project this was built for (PDEV-1408).

---

__________
Copyright: (c) Arda Systems 2025-2026, All rights reserved

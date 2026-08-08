# Decision: Drop caveman and quality-gate

Status: accepted
Date: 2026-08-08

## Context

The caveman family (`caveman`, `caveman-commit`, `caveman-review`,
`caveman-compress`, `caveman-stats`, `cavecrew`, `caveman-help`) was
installed third-party via `npx skills add JuliusBrussee/caveman`.
`quality-gate` was a vendored custom skill in `skills/quality-gate/`
enforcing test/lint/type-check gates before work could be considered
complete. Neither is part of the v2 skill set: this strip-back pass is
narrowing the installed surface to what is actually used, and both were
identified as candidates for removal rather than re-justification.

`0002-drop-superpowers-and-retire-via-cleanup-flag.md` already established
the mechanism for removing a component from machines that already have it —
the `DEPRECATED_*` arrays consumed by `./install.sh --cleanup` — so dropping
these two components is a matter of applying that existing mechanism, not
building a new one.

## Decision

Drop the caveman family and `quality-gate` from the v2 install set entirely.

- Remove `JuliusBrussee/caveman` from `THIRDPARTY_SKILLS` in `install.sh`.
- Delete the vendored `skills/quality-gate/` directory (including its
  `evals/`, fixtures, and any format docs it owns).
- Add `quality-gate` and the caveman family's installed directory names to
  `DEPRECATED_SKILLS`, so `./install.sh --cleanup` retires them from any
  machine that already has them. Exact installed directory names for the
  caveman family are verified at implementation time via
  `npx skills add JuliusBrussee/caveman --list`, since a third-party source's
  on-disk names are not guaranteed to match its repo name.

A plain `./install.sh` run never removes anything, consistent with
0002 — retirement stays opt-in via `--cleanup`.

## Consequences

Fewer skills installed by default, less vendored code to maintain, and a
smaller surface for the installer to reason about. Existing machines keep
caveman and quality-gate until someone runs `./install.sh --cleanup` there,
which is the accepted trade already made in 0002. The `DEPRECATED_SKILLS`
array now doubles as the record of exactly which caveman directory names and
`quality-gate` were retired and when.

## Supersedes

None

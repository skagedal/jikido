# Instructions for AI Agents

## Checks

`fvm flutter analyze` and `fvm flutter test` must both pass; CI runs the
same two. Fix a lint rather than silencing it.

## Specs

Changes too big for a GitHub issue — ones whose interesting part is a
decision — get a written spec under `specs/`, drafted in `specs/drafts/`
and numbered into `specs/implemented/` when they ship. See
`specs/README.md` for when to write one, how, and why a numbered spec is
never rewritten afterwards.

## Shell Scripts

The scripts in `ci/`, `local/` and `./update` follow these rules:

- Use `#!/usr/bin/env bash` as the shebang line, not `#!/bin/bash`.
- Use dashes, not underscores, in function names (`update-dart`, not
  `update_dart`).
- Stay compatible with **bash 3.2**, which is what macOS ships. Avoid:
  - `printf '%(...)T'` (bash 4.2+) — shell out to `date` instead
  - associative arrays / `declare -A` (bash 4.0+)
  - `${var,,}` / `${var^^}` (bash 4.0+)
  - `mapfile` / `readarray` (bash 4.0+)
  - `&>>` (bash 4.0+; use `>>file 2>&1`)
- Keep `shellcheck -x` clean.

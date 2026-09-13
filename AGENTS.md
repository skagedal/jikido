# Instructions for AI Agents

## Flutter

- The Flutter SDK is pinned with [fvm](https://fvm.app) in `.fvmrc`, which
  is committed; `.fvm/` is not. Run Flutter through `fvm flutter ...`, not a
  `flutter` off `$PATH`. Change the version with `fvm use <version>` and
  commit `.fvmrc`; CI reads it via `flutter-version-file`.
- `fvm flutter analyze` and `fvm flutter test` must both pass; CI runs the
  same two. Fix a lint rather than adding `// ignore:`.
- Keep platform-independent logic — timing, state machines, formatting — in
  plain Dart classes that do not import plugins, and have widgets and
  controllers take their platform dependencies by constructor injection.
  Plugin calls can't run under `flutter test`, so anything reached through a
  static plugin call is untestable.
- Generated binary assets (sounds, images) ship with the script that
  generated them, under `tool/`.

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

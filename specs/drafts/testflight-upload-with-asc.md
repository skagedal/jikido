# TestFlight uploads through asc

Adapted from the draft of the same name in iggybilly, written for
[iggybilly#21](https://github.com/skagedal/iggybilly/issues/21), and tried
here first: Jikido has one tester, so a release path that misbehaves
costs an afternoon rather than a band's patience. Nothing here supersedes
an earlier spec.

The iggybilly issue asks whether to replace `xcrun altool` in
`ci/upload-to-testflight` with [`asc`](https://asccli.sh). The verdict
carried over from there is: **swap it**, for `asc publish testflight`,
installed with the author's `setup-asc` action at an exact version. The
argument is in "Why asc" below; everything before that is what a release
then does, and everything after it is how.

Read against `asc` 5.3.0, the current release. Where the iggybilly draft
could not confirm a flag or a behaviour, it was settled here by running
5.3.0's `--help` and reading its source at that tag. The findings that
differ from the iggybilly draft are collected in "Corrections to the
iggybilly draft" near the end.

## The gap

`altool --upload-app` hands Apple an ipa and stops. It cannot set the
"What to Test" notes on a build, because that is not part of the delivery
it performs. So a tag ships, and some time later the app on the phone is
a version further along with nothing said about why.

## What a release does

A `v` tag still starts the release, and the two jobs are still
independent. The iOS job changes only at its last steps.

After the ipa is built it is uploaded, and the job then waits for App
Store Connect to finish processing it — five to thirty minutes, usually.
Waiting is not optional: notes attach to a *build*, and there is no build
record to attach them to until Apple has made one. Once there is, the
notes are written.

The job already waited, in `ci/await-testflight-build`, for the build to
*appear*, because a refused binary is otherwise reported only by email.
`asc` does that wait and more — it watches the upload record for Apple's
refusal rather than inferring one from a timeout — so that script goes.

### What the tester sees

A TestFlight notification, the new build in the list, and under it a
paragraph saying what changed since the last one.

### Where the notes come from

They come from the tag message.

The tag is already the only place the version is written. Making it the
place the notes are written too keeps that property: there is still
nothing to commit before releasing, and still one thing to get right.

A release becomes one command, `local/release`, which works out the next
version itself and writes the message into an annotated tag:

    ./local/release patch "The volume shows before you sit."
    ./local/release minor "Pausing."

Tagging by hand keeps working; the script exists so that the version
arithmetic and the `-a` are not things to get right.

A `CHANGELOG.md` would have to be edited and committed before the tag,
which trades the one-command release for a two-step one. Commit subjects
are written for `git log`, not for whoever installs the build.

So: the tag message, and only the tag message. A lightweight tag, or one
whose message is blank, fails the iOS job before the upload rather than
shipping a build that appears silently. Not falling back to commits also
means the checkout can stay shallow.

### Which group

The existing internal group, `Jikido Internals`, which has access to all
builds.

This is where Jikido parts from iggybilly. iggybilly's testers are
bandmates without App Store Connect accounts, so it needs an external
group, a build added to it explicitly, and beta review for each new
version. Jikido's one tester is the account holder. An internal group
with access to all builds receives every processed build without anything
adding it and needs no review, so there is nothing to add and nothing to
submit.

`asc publish testflight` requires a group all the same, and when it is
handed an internal all-builds group for a build it uploaded, it skips the
add and says so rather than failing. Naming the group still earns its
place: `asc` resolves it before uploading, so a group that has been
deleted or renamed fails the job before the binary goes anywhere.

### The states nobody wants

- **Processing fails.** `asc` reports the stage it reached and exits
  nonzero. The ipa is already at Apple, so re-running the job uploads a
  second copy under a new build number, which is harmless here.
- **Processing takes too long.** `asc` is given fifty minutes for the
  upload and the wait together, and the step a sixty-minute limit behind
  that. The job fails; the build may still turn up in TestFlight later,
  without notes.
- **The upload succeeds and the notes do not.** The build is live and the
  step fails. `asc` prints the command that retries the notes against the
  build it reached.
- **No tag message.** The step fails before uploading, pointing at
  `local/release`. The Android job is independent and still publishes.
- **The group does not exist.** The step fails before uploading, naming
  the group.

## Why asc

### Notes are part of the one call

`asc builds upload` does not take notes; on its own it is altool with a
different spelling. `asc publish testflight` does: `--test-notes` with a
required `--locale`, alongside `--group`, `--notify`, `--wait` and
`--submit --confirm`. Its order of work is upload, wait for the build to
appear, wait for processing, write the beta build localization, add the
groups, notify, then submit for beta review if asked and needed. Setting
`--test-notes` implies the processing wait whether or not `--wait` is
passed.

### Authentication

The three secrets already in the repository are enough, and no login step
is needed. `asc` reads `ASC_KEY_ID`, `ASC_ISSUER_ID` and `ASC_PRIVATE_KEY`
(PEM contents, which is what `APP_STORE_CONNECT_PRIVATE_KEY` holds)
straight from the environment. Nothing is written to disk, where altool
needed the key written under `~/.appstoreconnect/private_keys` because it
takes a key *name* and not a path.

`ASC_BYPASS_KEYCHAIN` is not the CI path. With no profile selected and
the keychain enabled, a complete environment credential set is consulted
first. With `ASC_BYPASS_KEYCHAIN` set, the config file comes first and the
environment becomes a fallback. So `ASC_PROFILE`, `ASC_BYPASS_KEYCHAIN`
and `ASC_CONFIG_PATH` are left unset.

This was checked from a laptop against the real account, with the key's
contents in `ASC_PRIVATE_KEY` and nothing else configured: `asc apps
list` and `asc testflight groups list` both answered.

### The app id

`publish testflight --app` takes an App Store Connect app id, an exact
bundle id or an exact app name, resolving a non-numeric value through
`filter[bundleId]` on `/v1/apps`, and an ambiguous match is an error. So
it is `--app tech.skagedal.jikido`, the same constant
`ci/setup-ios-signing` hardcodes.

That resolution belongs to `publish`, not to every command: `asc
testflight groups list --app tech.skagedal.jikido` fails with "no resource
of type 'apps'", and wants the numeric id.

### Upload reliability

`asc` does not reimplement Apple's delivery protocol and does not shell
out to Transporter. It uploads through Apple's REST endpoints —
`/v1/buildUploads`, then `/v1/buildUploadFiles`, then the chunked upload
operations Apple hands back, committed with checksums. That is a narrower
claim than "as reliable as altool", and it is the one worth making: this
is a client of a documented Apple API.

Failure reporting is the clearer win. When a multi-stage publish fails
partway, `asc` prints structured output naming `failureStage`,
`completedStages` and the build id it reached.

### Install cost

One download of a single binary, about 50 MB, checked against the
release's SHA-256 sums by
[`rudrankriyam/setup-asc`](https://github.com/rudrankriyam/setup-asc).
That action is by the tool's author, is a composite action whose whole
source is one readable `action.yml`, and is pinned to a commit SHA like
every other action here. Against a job that already spends minutes in
`flutter build ipa`, the download does not register.

### What it costs

A third-party binary in the release path, which altool is not.

The release cadence is fast — 5.0.0 through 5.3.0 inside a week — so the
version is pinned in the `setup-asc` step and upgraded deliberately.

Telemetry is on by default. The payload excludes flag values and ids, but
a release script should not phone anywhere, so `ASC_TELEMETRY_DISABLED=1`
is set.

## Implementation

### `ci/upload-to-testflight`

Rewritten around `asc`, keeping its guards and its "no ipa" check.
Constants at the top:

    bundle_id="tech.skagedal.jikido"
    group="Jikido Internals"

The script checks that `asc` is on the `PATH` and says which step should
have put it there.

The notes come from the tag message only if the tag is annotated. Asked
for `%(contents)` of a lightweight tag, git answers with the *commit's*
message, so the type is checked first with `git cat-file -t`. The tag is
also fetched explicitly with `--force` before it is read, since a checkout
of a tag ref can leave a lightweight copy locally where the remote has an
annotated one. That fetch names the tag, so it works in a shallow clone.
A tag with no message fails here, before the upload.

The notes are cut to 4000 bytes, Apple's limit in characters, because
`publish testflight` validates only the locale and an over-long note
would be refused after the upload and the wait. `iconv -c` then drops a
character the cut left in two.

Then one call:

    asc publish testflight \
        --app "$bundle_id" --ipa "$ipa" --group "$group" \
        --wait --timeout 50m --output json --pretty \
        --test-notes "$notes" --locale en-US

with the three `ASC_` variables and `ASC_TELEMETRY_DISABLED=1` in the
environment of that command alone. `--notify` and `--submit --confirm` are left off:
with only an internal all-builds group there is nothing for either to do.

`--timeout` is there because `publish` runs the upload, the wait for the
build to appear and the processing wait under one deadline, thirty
minutes by default.

### The workflow

`.github/workflows/release.yml`, the iOS job:

- An `Install asc` step, before signing:

      - name: Install asc
        uses: rudrankriyam/setup-asc@5358c70a27a3f0d1517604b0f1fdc43e70c1cc4d # v1.0.1
        with:
          version: 5.3.0

- The upload step gains `timeout-minutes: 60`.
- The `Wait for App Store Connect to accept it` step and
  `ci/await-testflight-build` are removed. `ci/appstore-api.sh` stays, for
  `local/make-ios-signing`.

The comment at the top of the workflow shows `./local/release`.

### `local/release`

    ./local/release major|minor|patch <message> [--yes]

The bump and the message are both required. It refuses
unless the current branch is `main`, the working tree is clean, and `main`
is the same commit as `origin/main` after a fetch.

It lists the `v*` tags, keeps those that are one to three integers — the
rule the workflow enforces — treats missing parts as zero, and takes the
highest. No tags at all is `0.0.0`. Minor resets patch, major resets both,
and the new tag always has three parts: `v0.1.0` makes the next patch
`v0.1.1`.

It prints the tag, the commit and the message, asks before creating the
annotated tag and pushing it unless given `--yes`, and pushes only that
tag.

### Documentation

`README.md`'s "Releasing" shows `local/release`, says the message is what
testers read, and describes the wait. "Setting up the Apple side" gains a
third manual step: the `Jikido Internals` group with access to all builds.

### What does not change

`local/make-ios-signing` and `ci/setup-ios-signing` stay. As of 5.3.0
`asc` could do most of the former — `asc certificates create
--generate-csr`, `asc signing fetch --create-missing`, `asc bundle-ids
create` — but it works and runs once a year, and replacing it is a
separate change.

## Corrections to the iggybilly draft

Found while implementing here, and worth carrying back:

- `git tag -l --format='%(contents)'` is **not** empty for a lightweight
  tag; it is the commit message. Check `git cat-file -t` first.
- A group named in `--group` that is internal with access to all builds is
  skipped by `asc` for builds it uploaded, not an error.
- `publish testflight` does have a limit on the wait: the whole command
  runs under a thirty-minute deadline unless `--timeout` says otherwise.
- `setup-asc` v1.0.1 still downloads from the old repository name, and the
  redirect works for 5.3.0.

## Open questions

- **Whether Apple's `buildUploads` API is as forgiving as altool's path
  in practice.** No amount of reading settles it; this repository is where
  it gets found out. If uploads prove flaky, the fallback is altool for
  the upload followed by `asc publish testflight --build-number "$BUILD"`
  for the wait and the notes.
- **Whether a build must be fully processed before notes can be
  attached.** `asc` waits, so this waits.
- **Truncating at 4000 bytes rather than characters.** Nobody will write
  4000 characters of notes for this.
- **Pinning 5.3.0**, a day old when pinned. `.pinact.yaml` holds actions
  back three days; the action here is older than that, but the version
  input is a string nothing watches, and it will stay where it is until
  something breaks.
- **The APK's release notes.** `ci/publish-apk` still uses
  `--generate-notes`. The tag message would serve there too.

## Alternatives considered

- **Keep altool and call the App Store Connect API by hand.**
  `ci/appstore-api.sh` already mints tokens, but the rest is a polling
  loop and several resources in bash.
- **Keep `ci/await-testflight-build` alongside `asc`.** A second wait for
  what `asc` has already waited for.
- **`asc builds upload`.** A drop-in for altool, but it sets no notes.
- **`brew install asc`.** Homebrew updates itself first, and the version
  is not pinned.
- **An external group, as iggybilly uses.** Beta review on every new
  version, for a tester who is the account holder.
- **Notes from a `CHANGELOG.md`, or from commit subjects alone.** See
  "Where the notes come from".

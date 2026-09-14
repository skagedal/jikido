# jikido

A zazen timer for iOS and Android, written in Flutter.

Follows the practices of Soto Zen.

*Jikidō* (直堂) is the person in a zendo who keeps time and rings the bell.

## Using it

Pick a length and press **Sit**. A settling minute passes — long enough to
arrange yourself, and adjustable or turned off in settings — and then the
opening bell rings. The ensō fills as the period passes. The bell rings out
over the beginning of the sitting rather than before it, which is how it goes
in a zendo: the countdown starts with the first strike, so twenty minutes
means twenty minutes from the bell. The settling time is not taken out of it.

A sitting can be paused, during the settling time as well as during the
period itself. The pause costs nothing: whatever the countdown said when you
pressed **Pause** is what it says when you press **Resume**. Nothing is
credited back, because nothing was being decremented in the first place — the
sitting is a set of wall-clock instants, and pausing moves them later. The
opening bell, the closing bell, the countdown in the notification shade and
the scheduled backstop all move together.

Two bells are offered, and are chosen in settings:

| Bell | |
|------|--|
| **Inkin** | The small hand bell on a stick. Bright, fades in a few seconds. |
| **Keisu** | The large standing bowl gong. Low, rings for half a minute. |

Either can be made larger or smaller. It is one control rather than two
because a real bell's pitch and how long it rings are not independent — a
heavier casting sounds lower *and* rings longer — and the synthesizer moves
them together.

The closing is three strikes as well, but only the first two ring out. The
third is stopped: the striker is laid on the bowl instead of being lifted
away, so that strike is heard and then cut off rather than allowed to fade.
Strike, strike, close.

You can also interact with a bell on its own, under the bell icon: tap the 
upper half of the screen to strike it, the lower half to rest the striker and 
stop the ring. 

## Making sure the bell is heard

The point of a meditation timer is that you stop paying attention to it.
Everything below exists so that the closing bell rings anyway. The layers are
independent on purpose — each one covers a different way for the others to
fail.

**A held-open audio session.** From the opening bell to the closing one, a
near-silent loop plays continuously. On iOS this is what keeps the app from
being suspended: an app with the `audio` background mode that is actually
producing audio keeps running with the screen off and the phone in a pocket.
Two players are used, one for the loop and one for the bells, so that
striking a bell never leaves a gap in the output.

**The alarm channel.** The audio session uses `AVAudioSessionCategoryPlayback`
on iOS, which ignores the ring/silent switch, and `USAGE_ALARM` on Android,
which plays at alarm volume and is let through Do Not Disturb. A useful side
effect: because the opening bell goes through the same path, you hear at the
start of the sitting exactly how loud the closing one will be.

**An Android foreground service.** Playing audio does not, by itself, stop
Android reclaiming the process. A foreground service does, and it puts the
remaining time in the notification shade. iOS needs no equivalent.

**A wall clock, not a stopwatch.** The end of the sitting is an instant, not
a countdown that gets decremented. Every tick asks what should have happened
by now, so a phone that suspended the app for a while and then let it run
again rings the bell immediately rather than finishing late by however long
it was asleep.

**A scheduled notification.** The moment a sitting starts, the operating
system is handed an alarm-clock notification carrying the bell as its sound,
set for the end of the period. If everything above fails and the app is
killed outright, that still rings. It is cancelled as soon as the app rings
the bell itself, so in the normal case you never see it. If the app comes
back long after the sitting ended, it says so rather than ringing a bell at
you minutes late. Pausing cancels it too, and arms it again on the way out
for the ending the pause moved it to.

The other layers are left running across a pause. Holding the audio session
and the foreground service is what keeps the process alive, and a sitting
lost to Android reclaiming the app while its owner answered the door would
be a poor sort of pause.

**Keeping the screen on**, optionally. Costs battery, and is the surest of
all of them, so it is offered as an explicit choice in settings.

On Android 12 and later the scheduled notification is only exact if the
"Alarms & reminders" permission is granted. Jikido works without it — settings
offers a way to grant it, and falls back to an approximate alarm otherwise.

**The volume, before you sit.** The phone's volume drifts between sittings,
and Jikido cannot set it. So the home screen, the settling time and the bell
page show the level the bell will ring at, next to a mark for where it was at
the last sitting's opening bell, and say whether it is louder, quieter or the
same — or, at zero, that the bell will not be heard. On Android that is the
alarm volume, and while Jikido is in front the side buttons adjust the alarm
volume rather than the media volume. On iOS it is the output volume, of
whatever the sound is going to.

## The bells

The bells are synthesized on the device. A struck bowl bell is a sum of 
exponentially decaying inharmonic partials, and the numbers describing them 
are measured from some recordings of real bells. Three things to note:

**The pitch is not the fundamental.** An inkin's hum mode is barely audible;
the partial at 2.70 times it is more than ten times louder and is what you
hear as the note. Modelling the hum as the loudest partial — the obvious
thing to do — gives something far darker and duller than any real inkin.

**The upper partials die fast.** The third partial is gone in a third of a
second while the second is still ringing after two. That collapse from a
bright clang to a nearly pure tone is most of what makes the attack sound
like struck metal rather than a synthesizer.

**Every partial is a pair.** No bowl is perfectly circular, so each mode comes
in two a few Hz apart, and the interference between them is the slow warble a
bell has. Which of the pair is louder depends on where the striker lands, and
the measured depth matters in both directions: modes of equal level beat all
the way down to silence, which sounds like a tremolo pedal, and a single mode
sounds dead.

Synthesizing on the device is what buys the variation between strikes. Where
the striker lands is a parameter, chosen afresh for each strike, and the mode
balance, the phases and the contact noise all follow from it — so three
strikes in a row are three strikes rather than one sample played three times.

One number sets a bell's size. Frequency goes inversely with it, and because
the quality factor is held constant the ring time follows: `tau = Q / (pi f)`,
with Q measured at 20300 on the single struck inkin below — 3245 Hz ringing
with a decay time of 1.99 s. The same constant independently puts a keisu at a
twelve-second decay, which is the half-minute of ring a real one has. It is a
modelling choice rather than a law bells obey; see the caveat under
**References**.

`lib/src/audio/bell_synth.dart` is the synthesizer the app uses.
`tool/synthesize_bells.py` is the reference implementation of the same model,
and the two are held together by goldens in `test/bell_synth_test.dart` —
sample-for-sample, which is why neither uses its language's random number
generator for anything the other has to reproduce.

The script still has a job of its own: the closing-bell notification, which
the operating system plays if Jikido has been killed mid-sitting. That one has
to be a file on disk, so it cannot be synthesized on demand and is always the
default size. Re-run the script from this directory after changing the model:

```
python3 tool/synthesize_bells.py
```

## Building

The Flutter SDK version is pinned in `.fvmrc` and installed with
[fvm](https://fvm.app), so everyone — and CI — builds against the same SDK:

```
brew install fvm     # once
fvm install          # gets the version .fvmrc names
```

Then prefix Flutter commands with `fvm`:

```
fvm flutter pub get
fvm flutter test
fvm flutter run
```

`fvm flutter analyze` and `fvm flutter test` are what CI runs, and
`analyze` must be clean: fix the lint rather than silencing it. To move to a
newer SDK, `fvm use <version>` and commit the new `.fvmrc`; CI reads the
version straight out of that file.

Editors are pointed at the SDK through the `.fvm/versions/<version>` symlink
`fvm use` leaves in the project — in VS Code that is `dart.flutterSdkPath`,
and IntelliJ takes the same path as its Flutter SDK.

The layout follows the usual split between what can be tested off-device and
what cannot:

| | |
|--|--|
| `lib/src/session.dart` | The instants of a sitting. Pure Dart, no plugins. |
| `lib/src/sitting_controller.dart` | Drives a sitting. Takes its clock and its audio, notification and service layers by injection, so the timing can be tested with a clock the test moves by hand. |
| `lib/src/audio/` | just_audio and the audio session. |
| `lib/src/alarm/` | The scheduled notification, the foreground service, and the exact-alarm permission. |
| `lib/src/ui/` | Screens, and the ensō. |

### On a real phone

`local/build-to-phone` builds and installs, with no Xcode involved:

```
./local/build-to-phone            # release
./local/build-to-phone --debug
```

It needs `local/devices.env`, which says which phone and which Apple team
to sign with. That file is gitignored, because this repository is public
and those values are personal — copy `local/devices.env.example`, or
symlink your own from wherever you keep such things. The team reaches
Xcode through a generated `ios/Flutter/Signing.xcconfig`, also gitignored,
which `Debug.xcconfig` and `Release.xcconfig` include optionally so
simulator builds work without it.

### Updating dependencies

```
./update              # the Flutter SDK, pubspec.lock and the pinned actions
./update --dry-run    # print what would run, change nothing
./update dart         # only pubspec.lock
```

`pubspec.yaml` holds ranges a human wrote, so crossing a major version stays
a manual edit. The Flutter SDK in `.fvmrc` follows the newest stable release,
and [pinact](https://github.com/suzuki-shunsuke/pinact) moves the actions in
`.github/workflows`, which are pinned to commit SHAs.

## Releasing

Push a version tag and both apps ship from that commit. `local/release`
works out the next version, tags `main` with a message and pushes it:

```
./local/release patch "The volume shows before you sit."    # v0.1.0 → v0.1.1
./local/release minor "Pausing."                            # v0.1.1 → v0.2.0
```

The message is what testers read: it becomes the build's "What to Test"
notes in TestFlight. It refuses unless `main` is clean and the same commit
as `origin/main`, and asks before pushing. Tagging by hand still works as
long as the tag is annotated with a message; the iOS job fails on a tag
without one.

`.github/workflows/release.yml` builds the Android APK and attaches it to
the tag's GitHub release, where anyone can download it without an account
or an app store, and builds the iOS app and uploads it to TestFlight.

The tag is the only place the version is written. `--build-name` comes
from the tag and `--build-number` from the run, so a release needs no
commit of its own and `pubspec.yaml`'s version is only what a local build
gets. A tag must be `v` and one to three integers: the workflow refuses
anything else up front, because App Store Connect would refuse it at the
end of a long build.

The two jobs are independent, so the APK is published even when the Apple
side fails, and the other way round.

The iOS job uploads with [`asc`](https://asccli.sh), pinned in
`release.yml`, and does not finish at the upload. A successful upload
means Apple took the bytes, not that it took the build: a binary can be
refused a minute later, and the only notice is an email. So the job waits
for App Store Connect to finish processing the build, fails if Apple
refuses it, and then writes the notes, which cannot be attached to a build
that does not exist yet. See `specs/drafts/testflight-upload-with-asc.md`
for why `asc` rather than `altool`.

### Setting up the Android key

Once, on your machine:

```
./local/make-release-keystore
```

It writes a keystore outside the repository and a gitignored
`android/key.properties` pointing at it, and prints the two commands that
give CI the same key. Back the keystore up before anything else. Android
knows an app by its signature, so if that file is lost, everyone who has
the app has to delete it before they can install another build — and the
copy in `key.properties` is the only other one.

### Setting up the Apple side

It needs the Apple Developer Program. Three things have to be done by hand
first, because App Store Connect has no API for either:

1. **An App Store Connect API key**, under Users and Access →
   Integrations, with the **Admin** role. App Manager is enough to upload
   builds, but not to have a certificate issued. The `.p8` downloads once
   and never again. One key serves every app on the account.
2. **The app record** for `tech.skagedal.jikido` in App Store Connect. An
   upload has nowhere to land until it exists.
3. **The tester group** `Jikido Internals`, under TestFlight → Internal
   Testing, with access to all builds. The upload names it, and fails
   before uploading anything if it is not there.

Then point a config file at that key and run one script:

```
cp local/appstore.env.example local/appstore.env
$EDITOR local/appstore.env
./local/make-ios-signing
```

It has App Store Connect issue an Apple Distribution certificate — or
reuses the one in `~/.apple-signing` if it is still good — registers the
bundle id if it is new, makes the App Store provisioning profile, and sets
all seven iOS secrets. The certificate belongs to the team rather than the
app, so its files there carry no app name and every app's release shares
them; an account is allowed very few live distribution certificates, and
asking for another while the one you have still works is how you run out.
Back up `~/.apple-signing`: the private key is in there and nowhere else.

Then turn the job on:

```
gh variable set IOS_RELEASE --body enabled
```

Until you do, the iOS job does not run and every release page says so.

Run `make-ios-signing` again in a year. The certificate and the profile
both expire a year after they are issued: the profile is replaced every
time, the certificate only once the one you have is nearly out.

### What ends up in the repository's secrets

| Secret | What it is | Set by |
| --- | --- | --- |
| `ANDROID_KEYSTORE_BASE64` | the keystore, base64 | you, from `make-release-keystore` |
| `ANDROID_KEYSTORE_PASSWORD` | its password | you, from `make-release-keystore` |
| `IOS_DIST_CERT_P12_BASE64` | the distribution certificate and its key | `make-ios-signing` |
| `IOS_DIST_CERT_PASSWORD` | the password that bundle was made under | `make-ios-signing` |
| `IOS_PROVISIONING_PROFILE_BASE64` | the App Store profile | `make-ios-signing` |
| `IOS_TEAM_ID` | the team id, the `IOS_TEAM` in `local/devices.env` | `make-ios-signing` |
| `APP_STORE_CONNECT_KEY_ID` | the API key's id | `make-ios-signing` |
| `APP_STORE_CONNECT_ISSUER_ID` | the issuer id shown above the key list | `make-ios-signing` |
| `APP_STORE_CONNECT_PRIVATE_KEY` | the contents of the `.p8` | `make-ios-signing` |

### Two ways of signing

On your machine the app is signed *automatically*: Xcode talks to Apple as
the Apple ID you are logged in as. A runner has nobody logged in, so there
it is signed *manually*, with one certificate and one profile.
`ci/setup-ios-signing` switches the mode by writing the same gitignored
`ios/Flutter/Signing.xcconfig` that `local/build-to-phone` writes, with the
identity and the profile named alongside the team.

## Specs

Changes whose interesting part is a decision get a written spec under
`specs/`, drafted in `specs/drafts/` and numbered into `specs/implemented/`
when they ship. See `specs/README.md`.

## References

### The recordings the bell model was measured from

The numbers in `tool/synthesize_bells.py` are fitted to these, so the claims
about partial ratios and decay times in **The bells** above can be checked
against them rather than taken on trust.

| | |
|--|--|
| [Monastery Store inkin demonstration](https://vimeo.com/110573379) | Three different inkin — traditional, flattop and portable — at 2695, 3234 and 6146 Hz. Where the damped strikes are: 0.05-0.17 s to fall 20 dB, against 2.5-4.7 s for one left to ring. |
| [Inkin bell, struck once](https://www.youtube.com/watch?v=xfeBig0xfJQ) | The cleanest single strike of the set, and the source of the headline numbers: partials at 1.00, 2.70, 4.93 and 7.67, decaying in 1.99 s, 0.34 s and 0.10 s. |
| [Small rin bell](https://www.youtube.com/watch?v=sqLAyvcVQZ8) | A second bell agreeing with the first to within a couple of percent, which is why the model is not just a fit to one recording. |
| [Rin bells of three sizes](https://www.youtube.com/watch?v=YV5hzjzkvyM) | 2707, 3375 and 3492 Hz, ringing 6.5, 2.6 and 3.6 s. The lowest rings by far the longest, which is the behaviour the size control reproduces — but see the caveat below. |
| [Small inkin, struck repeatedly](https://www.youtube.com/watch?v=KGN3f-atEYU) | Strikes 1.4-1.8 s apart. The app deliberately does not copy this; see `strike_interval`. |
| [Vintage bell, struck repeatedly](https://www.youtube.com/shorts/NdeuOdg0WsQ) | A much lower bell — 208 Hz hum, partials at 654 and 1813 Hz — struck every 3.6 s. |
| [Portable inkin, waved](https://www.youtube.com/watch?v=4nhYhrU1I8s) | Waving the bell smears each partial into a cluster. Not modelled, but a good picture of what the mode pairs are doing. |

**Where the model is a choice rather than a measurement.** Holding Q constant
is what makes the size control one slider instead of two, and it gets the
direction unarguably right: across the three bowls above, the lowest rings
two and a half times longer than the highest. But their individual Q values
are 11700, 17300 and 24100, against the 20300 the model uses. Wall thickness
and alloy move Q independently of size, so real bowls do not sit on one curve.
Constant Q is the simplest rule that behaves like a bell; it is not a law
bells obey.

### Other zazen timers

| | |
|--|--|
| [Ensō — Meditation Timer & Bell](https://ensomeditationtimer.app/) ([App Store](https://apps.apple.com/us/app/ens%C5%8D-meditation-timer-bell/id840637879)) | A ring that erases itself as the session passes, and a library of recorded bells, bowls and chimes. |
| [Zenso Meditation Timer](https://appstor.io/app/zenso-meditation-timer) | Draws an animated ensō as the session elapses. |
| [Tricycle: meditation app roundup](https://tricycle.org/magazine/meditation-apps-review-enso-calm-smiling-mind/) · [timer apps for iOS](https://tricycle.org/article/meditation-timer-app/) | The wider landscape, reviewed by people who sit. |

### The ensō

An ensō (円相) is drawn in one uninterrupted brushstroke and never corrected,
so what stays on the paper is a record of the moment rather than a drawing of
a circle: thick where the brush pressed, broken where it ran dry, and stopped
where it lifted. Closed, it means completeness; left open, as `lib/src/ui/enso.dart`
draws it, it means the imperfect and the still-moving. Which is the better fit
for a period of sitting — entered once, in one movement, with no going back to
tidy it up.
